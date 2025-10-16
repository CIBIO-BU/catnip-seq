#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
INPUT_FASTA="$1"
MAPPING_FILE="$2"
INDEX_COLS="$3"
PERCENTAGE_IDENTITY="$4"
THREADS="$5"
AVAILABLE_MEMORY="$6"
SAVE_INTERMEDIARY="$7"
PROJECT_DIR="$8"
SCRIPTS_DIR="$PROJECT_DIR/src"

IFS=',' read -r -a index_cols_array <<< "$INDEX_COLS"
IFS=',' read -r -a perc_id_array <<< "$PERCENTAGE_IDENTITY"

# Validation checks
if [ "${#index_cols_array[@]}" -lt 2 ]; then
    echo "Error: At least 2 columns are required in INDEX_COLS (1 for sequence ID + at least 1 category column)." >&2
    exit 1
fi

if [ "${#index_cols_array[@]}" -gt 5 ]; then
    echo "Error: Cannot have more than 5 columns in INDEX_COLS (1 for sequence ID + max. 4 categories)." >&2
    exit 1
fi

if [ "${#perc_id_array[@]}" -gt 4 ]; then
    echo "Error: Cannot have more than 4 PERCENTAGE_IDENTITY values (one column is reserved for sequence ID)." >&2
    exit 1
fi

expected_thresholds=$((${#index_cols_array[@]} - 1))

if [ "${#perc_id_array[@]}" -eq 0 ]; then
    echo "Error: At least one PERCENTAGE_IDENTITY value is required." >&2
    exit 1
fi

if [ "${#perc_id_array[@]}" -eq 1 ]; then
    single_value="${perc_id_array[0]}"
    perc_id_array=()
    # Replicate percentage identity value for each non-sequence ID column
    for ((i=0; i<expected_thresholds; i++)); do
        perc_id_array+=("$single_value")
    done
    echo "Warning: Single percentage identity value ($single_value) provided. Replicating for all $expected_thresholds non-sequence ID columns." >&2
elif [ "${#perc_id_array[@]}" -ne "$expected_thresholds" ]; then
    echo "Error: Number of PERCENTAGE_IDENTITY values (${#perc_id_array[@]}) must match number of non-ID columns ($expected_thresholds)." >&2
    echo "       Total columns: ${#index_cols_array[@]}, ID columns: 1, Non-ID columns: $expected_thresholds" >&2
    exit 1
fi

# Convert percentage identity array to comma-separated string for passing to Python
PERC_ID_STRING=$(IFS=,; echo "${perc_id_array[*]}")

# ---------------------------------------------------
echo "Starting workflow with the following parameters:"
echo " Input file: $INPUT_FASTA"
echo " Mapping file: $MAPPING_FILE"
echo " Sequence ID column: ${index_cols_array[0]} (no threshold applied)"
for i in "${!perc_id_array[@]}"; do
    col_idx=$((i + 1))  # Offset by 1 since first column is ID
    echo " Column: ${index_cols_array[$col_idx]} -> Percentage Identity: ${perc_id_array[$i]}"
done
echo " Threads: $THREADS"
echo " Memory: $AVAILABLE_MEMORY MB"
echo " Save intermediary files: $SAVE_INTERMEDIARY"
echo

# ------- WORKFLOW -----------------
echo "Running catnip...."

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
            if (( $(echo "$perc > $LOWEST_PERCENTAGE" | bc -l) )); then
                LOWEST_PERCENTAGE="$perc"
            fi
        done
    else
        LOWEST_PERCENTAGE="${perc_id_array[0]}"
    fi

   HIGHEST_IDENTITY=$(printf "%.2f" "$(echo "(100 - $LOWEST_PERCENTAGE) / 100" | bc -l)")

    bash "${SCRIPTS_DIR}/run_cdhit.sh" \
        "$INPUT_FASTA" \
        "$OUTPUT_FILE_NAME" \
        "$HIGHEST_IDENTITY" \
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
    --mapping_file "$MAPPING_FILE" \
    --index_cols "$INDEX_COLS")

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
        --fasta_file "$INPUT_FASTA" \
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
            --cat_thresholds "$PERC_ID_STRING" \
            --mapping_file "$MAPPING_FILE" \
            --index_cols "$INDEX_COLS" \
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