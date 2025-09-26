#!/bin/bash

set -euo pipefail

if [ $# -lt 4 ]; then
    echo "Usage: $0 INPUT_FASTA PERCENTAGE_IDENTITY THREADS AVAILABLE_MEMORY"
    echo "  INPUT_FASTA: Path to input FASTA file"
    echo "  PERCENTAGE_IDENTITY: Identity threshold for clustering"
    echo "  THREADS: Number of threads to use"
    echo "  AVAILABLE_MEMORY: Memory limit for processing"
    exit 1
fi

source ~/miniconda3/etc/profile.d/conda.sh
conda activate base-invaders

# Load configuration
CONFIG_FILE="${BASH_SOURCE[0]%/*}/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

INPUT_FASTA="$1"
PERCENTAGE_IDENTITY="$2"
THREADS="$3"
AVAILABLE_MEMORY="$4"

if [ ! -f "$INPUT_FASTA" ]; then
    echo "Error: Input Fasta file "$INPUT_FASTA" does not exist."
    exit 1
fi

echo "Processing FASTA file: $INPUT_FASTA"
# echo "  Identity threshold: $PERCENTAGE_IDENTITY"
# echo "  Threads: $THREADS"
# echo "  Memory: $AVAILABLE_MEMORY"

echo "  Mapping sequence IDs to categories..."
MAPPING_FILE="${INPUT_FASTA%.fasta}_mapping.tsv"
python "${SCRIPTS_DIR}/mapping_helper.py" "$INPUT_FASTA" >/dev/null 2>&1

# echo "Cleaning FASTA file..."
python "${SCRIPTS_DIR}/fasta_cleaner_helper.py" "$INPUT_FASTA" >/dev/null 2>&1

CLEAN_FASTA="${INPUT_FASTA%.fasta}_clean.fasta"
OUTPUT_FILE_NAME="${INPUT_FASTA%.fasta}"

if [ ! -f "$CLEAN_FASTA" ]; then
    echo "Error: Cleaned FASTA file was not created."
    exit 1
fi

echo "  Clustering sequences ("$PERCENTAGE_IDENTITY")..."
bash "${SCRIPTS_DIR}/run_cdhit.sh" \
    "$CLEAN_FASTA" "$OUTPUT_FILE_NAME" \
    "$PERCENTAGE_IDENTITY" "$THREADS" \
    "$AVAILABLE_MEMORY" "$PERCENTAGE_IDENTITY" \
    >/dev/null 2>&1

if [ ! -f "$OUTPUT_FILE_NAME" ]; then
    echo "Error: Clustering output was not created."
    exit 1
fi

echo "  Identifying heterogenous clusters..."
OUTPUT_FILE="${INPUT_FASTA%.fasta}.clstr"
HET_CLUSTERS_LIST=$(python "${SCRIPTS_DIR}/identify_heterogenous_clusters.py" \
    --cluster_file "$OUTPUT_FILE" \
    --mapping_file "$MAPPING_FILE")

if [ -z "$HET_CLUSTERS_LIST" ]; then
    echo "No heterogenous clusters found. Processing complete."
    exit 0
fi

count=0
total=$(echo "$HET_CLUSTERS_LIST" | wc -w)
echo "Heterogenous clusters found: ${HET_CLUSTERS_LIST}."
for CLUSTER_NUMBER in $HET_CLUSTERS_LIST; do
    count=$((count + 1))
    percent=$(( 100 * count / total ))
    printf "\rProcessing clusters: [%-50s] %3d%%" $(printf "%*s" $(( percent * 50 / 100 )) | tr ' ' '#') "$percent"

    CST_OUTPUT_FILE="${OUTPUT_FILE_NAME}_${CLUSTER_NUMBER}.fasta"
    INDEX_NAME="${CST_OUTPUT_FILE%.fasta}_index"
    ALIGN_NAME="${CST_OUTPUT_FILE%.fasta}_align"

    # echo "  Extracting cluster sequences..."
    python "${SCRIPTS_DIR}/cluster_extractor.py" "$OUTPUT_FILE" \
        --fasta_file "$CLEAN_FASTA" \
        --cluster_number "$CLUSTER_NUMBER" \
        --output_file "$CST_OUTPUT_FILE" \
        >/dev/null 2>&1

    if [ ! -f "$OUTPUT_FILE" ]; then
        echo " Warning: Failed to extract cluster $CLUSTER_NUMBER, skipping..."
        continue
    fi

    # echo "  Running Bowtie alignment..."
    bash "${SCRIPTS_DIR}/run_bowtie_aligner.sh" \
        "$CST_OUTPUT_FILE" "$INDEX_NAME" \
        1 $ALIGN_NAME \
        >/dev/null 2>&1

    BAM_FILE="${ALIGN_NAME}.bam"
    if [ -f "$BAM_FILE" ]; then
        # echo "  Pre-processing BAM file..."
        python "${SCRIPTS_DIR}/pre_process_bam.py" \
        --bam_file "$BAM_FILE" \
        --mapping_file "$MAPPING_FILE" \
        --save \
        # >/dev/null 2>&1
    else
        echo "  Warning: BAM file $BAM_FILE not found, skipping pre-processing..."
    fi

    # echo "  Completed processing cluster: $CLUSTER_NUMBER."

done

python "${SCRIPTS_DIR}/compile_interclust.py" \
    .

echo
echo "All processing completed!"