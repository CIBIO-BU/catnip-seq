#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
INPUT_FASTA="$1"
MAPPING_FILE="$2"
INDEX_COLS="$3"
PERCENTAGE_DIVERGENCE="$4"
THREADS="$5"
AVAILABLE_MEMORY="$6"
SAVE_INTERMEDIARY="$7"
PROJECT_DIR="$8"
SCRIPTS_DIR="$PROJECT_DIR/src"

IFS=',' read -r -a index_cols_array <<< "$INDEX_COLS"

# Validation checks
if [ "${#index_cols_array[@]}" -lt 2 ]; then
    echo "Error: At least 2 columns are required in INDEX_COLS (1 for sequence ID + at least 1 category column)." >&2
    exit 1
fi

if [ "${#index_cols_array[@]}" -gt 5 ]; then
    echo "Error: Cannot have more than 5 columns in INDEX_COLS (1 for sequence ID + max. 4 categories)." >&2
    exit 1
fi

if [ -z "$PERCENTAGE_DIVERGENCE" ]; then
    echo "Error: PERCENTAGE_DIVERGENCE value is required." >&2
    exit 1
fi

# Check if multiple divergence values were provided
IFS=',' read -r -a perc_div_array <<< "$PERCENTAGE_DIVERGENCE"
if [ "${#perc_div_array[@]}" -gt 1 ]; then
    echo "Error: Only one PERCENTAGE_DIVERGENCE value is allowed. Found ${#perc_div_array[@]} values." >&2
    exit 1
fi

if (( $(echo "$PERCENTAGE_DIVERGENCE > 10" | bc -l) )); then
    echo "Warning: catnip might fail to produce results if the divergence exceeds 10%. This could happen due to increased mismatches between sequences, leading to alignment failures." >&2
fi

# ---------------------------------------------------
echo "Starting workflow with the following parameters:"
echo " Input file: $INPUT_FASTA"
echo " Mapping file: $MAPPING_FILE"
echo " Index columns: ${index_cols_array[*]}"
echo " Sequence ID column: ${index_cols_array[0]} (no threshold applied)"
echo " Percentage Divergence: $PERCENTAGE_DIVERGENCE%"
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
   IDENTITY_THRESHOLD=$(printf "%.2f" "$(echo "(100 - $PERCENTAGE_DIVERGENCE) / 100" | bc -l)")

    bash "${SCRIPTS_DIR}/run_cdhit.sh" \
        "$INPUT_FASTA" \
        "$OUTPUT_FILE_NAME" \
        "$IDENTITY_THRESHOLD" \
        "$THREADS" \
        "$AVAILABLE_MEMORY" \
        >/dev/null 2>&1
fi

if [ ! -f "$CLSTR_FILE" ]; then
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

    rm -f "$CST_OUTPUT_FILE"

    # Process BAM file
    BAM_FILE="${ALIGN_NAME}.bam"
    if [ -f "$BAM_FILE" ]; then
        python "${SCRIPTS_DIR}/pre_process_bam.py" \
            --bam_file "$BAM_FILE" \
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