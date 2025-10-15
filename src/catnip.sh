#!/usr/bin/env bash
set -euo pipefail


SCRIPTS_DIR="$PROJECT_DIR/src"

# Parse arguments
INPUT_FASTA="$1"
MAPPING_FILE="$2"
INDEX_COLS="$3"
PERCENTAGE_IDENTITY="$4"
THREADS="$5"
AVAILABLE_MEMORY="$6"
SAVE_INTERMEDIARY="$7"
PROJECT_DIR="$8"

IFS=',' read -r -a index_cols_array <<< "$INDEX_COLS"
IFS=',' read -r -a perc_id_array <<< "$PERCENTAGE_IDENTITY"

if [ "${#index_cols_array[@]}" -gt 4]; then
    echo "Error: Cannot have more than 4 columns in INDEX_COLS."
    exit 1
fi

if [ "${#index_cols_array[@]}" -eq 0 ]; then
    echo "Error: At least one INDEX_COL is required." >&2
    exit 1
fi

if [ "${#perc_id_array[@]}" -gt 4]; then
    echo "Error: Cannot have more than 4 PERCENTAGE_IDENTITY."
    exit 1
fi

if [ "${#perc_id_array[@]}" -eq 1 ]; then
    single_value="${perc_id_array[0]}" # when a single value provided, replicate it for each index column
    perc_id_array=()
    for ((i=0; i<${#index_cols_array[@]}; i++)); do
        perc_id_array+=("$single_value")
    done
elif [ "${#perc_id_array[@]}" -ne "${#index_cols_array[@]}" ]; then
    echo "Error: Number of PERCENTAGE_IDENTITY values (${#perc_id_array[@]}) must match number of INDEX_COLS (${#index_cols_array[@]})." >&2
    exit 1
fi

for i in "${!index_cols_array[@]}"; do
    echo "Column: ${index_cols_array[$i]} -> Percentage Identity: ${perc_id_array[$i]}"
done


echo "Starting workflow with the following parameters:"
echo "  Input file: $INPUT_FASTA"
echo "  Mapping file: $MAPPING_FILE"
for i in "${!index_cols_array[@]}"; do
    echo "Column: ${index_cols_array[$i]} -> Percentage Identity: ${perc_id_array[$i]}"
done
echo "  Threads: $THREADS"
echo "  Memory: $AVAILABLE_MEMORY MB"
echo "  Save intermediary files: $SAVE_INTERMEDIARY"
echo

# # Mapping step
# MAPPING_FILE="${INPUT_FASTA%.fasta}_mapping.tsv"
# if [ -f "$MAPPING_FILE" ]; then
#     echo "Mapping file already exists: $MAPPING_FILE. Skipping..."
# else
#     echo "Mapping sequence IDs to categories..."
#     python "${SCRIPTS_DIR}/mapping_helper.py" "$INPUT_FASTA"
# fi

# # Cleaning step
# echo "Cleaning FASTA file..."
# python "${SCRIPTS_DIR}/fasta_cleaner_helper.py" "$INPUT_FASTA"

# CLEAN_FASTA="${INPUT_FASTA%.fasta}_clean.fasta"

# if [ ! -f "$CLEAN_FASTA" ]; then
#     echo "Error: Cleaned FASTA file was not created." >&2
#     exit 1
# fi

OUTPUT_FILE_NAME="${INPUT_FASTA%.fasta}"

# Clustering step
CLSTR_FILE="${OUTPUT_FILE_NAME}.clstr"
if [ -f "$CLSTR_FILE" ]; then
    echo "Cluster file already exists: $CLSTR_FILE. Skipping..."
else
    # Find the lowest percentage identity value
    if [ "${#perc_id_array[@]}" -gt 1 ]; then
        LOWEST_PERCENTAGE="${perc_id_array[0]}"
        for perc in "${perc_id_array[@]}"; do
            if (( $(echo "$perc < $LOWEST_PERCENTAGE" | bc -l) )); then
                LOWEST_PERCENTAGE="$perc"
            fi
        done
    else
        LOWEST_PERCENTAGE="${perc_id_array[0]}"
    fi

    bash "${SCRIPTS_DIR}/run_cdhit.sh" \
        "$CLEAN_FASTA" \
        "$OUTPUT_FILE_NAME" \
        "$LOWEST_PERCENTAGE" \
        "$THREADS" \
        "$AVAILABLE_MEMORY" \
        >/dev/null 2>&1
fi

if [ ! -f "$OUTPUT_FILE_NAME" ]; then
    echo "Error: Clustering output was not created." >&2
    exit 1
fi

# Identify heterogeneous clusters
echo "Identifying heterogeneous clusters..."
OUTPUT_FILE="${INPUT_FASTA%.fasta}.clstr"
HET_CLUSTERS_LIST=$(python "${SCRIPTS_DIR}/identify_heterogenous_clusters.py" \
    --cluster_file "$OUTPUT_FILE" \
    --mapping_file "$MAPPING_FILE")

if [ -z "$HET_CLUSTERS_LIST" ]; then
    echo "No heterogeneous clusters found. Processing complete."
    exit 0
fi

# Process clusters
count=0
total=$(echo "$HET_CLUSTERS_LIST" | wc -w)
echo "Found $total heterogeneous clusters: $HET_CLUSTERS_LIST"

for CLUSTER_NUMBER in $HET_CLUSTERS_LIST; do
    count=$((count + 1))
    percent=$(( 100 * count / total ))
    printf "\rProcessing clusters: [%-50s] %3d%%" \
        $(printf "%*s" $(( percent * 50 / 100 )) | tr " " "#") "$percent"

    CST_OUTPUT_FILE="${OUTPUT_FILE_NAME}_${CLUSTER_NUMBER}.fasta"
    INDEX_NAME="${CST_OUTPUT_FILE%.fasta}_index"
    ALIGN_NAME="${CST_OUTPUT_FILE%.fasta}_align"

    # Extract cluster sequences
    python "${SCRIPTS_DIR}/cluster_extractor.py" "$OUTPUT_FILE" \
        --fasta_file "$CLEAN_FASTA" \
        --cluster_number "$CLUSTER_NUMBER" \
        --output_file "$CST_OUTPUT_FILE"

    if [ ! -f "$CST_OUTPUT_FILE" ]; then
        echo " Warning: Failed to extract cluster $CLUSTER_NUMBER, skipping..." >&2
        continue
    fi

    # Align sequences
    bash "${SCRIPTS_DIR}/run_bowtie_aligner.sh" \
        "$CST_OUTPUT_FILE" \
        "$INDEX_NAME" \
        1 \
        "$ALIGN_NAME"

    # Process BAM file
    BAM_FILE="${ALIGN_NAME}.bam"
    if [ -f "$BAM_FILE" ]; then
        python "${SCRIPTS_DIR}/pre_process_bam.py" \
            --bam_file "$BAM_FILE" \
            --mapping_file "$MAPPING_FILE" \
            --save
    else
        echo " Warning: BAM file $BAM_FILE not found, skipping..." >&2
    fi
done

echo
echo "Compiling inter-cluster results..."
python "${SCRIPTS_DIR}/compile_interclust.py" .

# Cleanup
if [ "$SAVE_INTERMEDIARY" = "false" ]; then
    echo "Cleaning up intermediary files..."
    find . -type f -name '*_align.bam' -delete
    find . -type f -name '*_intraclst_mins.tsv' -delete
fi

echo
echo "All processing completed!"