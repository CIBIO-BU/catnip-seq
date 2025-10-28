#!/usr/bin/env bash
# -*- coding: utf-8 -*-
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPTS_DIR")"

# Default values
MAPPING_FILE=""
INDEX_COLS=""
PERCENTAGE_DIVERGENCE=10
THREADS=1
AVAILABLE_MEMORY=800
SAVE_INTERMEDIARY=false


# Help function
help() {
cat << EOF
Usage: ${0##*/} -i INPUT_FASTA -f MAPPING_FILE -c INDEX_COLS [OPTIONS]

Compute nucleotide divergence across user-defined categories.

Required arguments:
  -i INPUT_FASTA          Input FASTA file path.
  -f MAPPING_FILE         Mapping file path (TSV format).
  -c INDEX_COLS           Comma-separated indices of columns in mapping file (max 4).
                          Column indices start from 0, where 0 is the sequence ID column.

Optional arguments:
  -p PERCENTAGE_DIVERGENCE  Threshold for percentage of divergence (default: 10)
  -t THREADS               Number of threads to use (default: 1)
  -m AVAILABLE_MEMORY      Available memory in MB (default: 800)
  -s                       Save intermediary files (cluster BAM and minimum files)
  -h                       Display this help message and exit

Example:
  ${0##*/} -i sequences.fasta -f mapping.tsv -c 0,1,2,3 -p 10 -t 8 -m 16000 -s

EOF
}

# Parse arguments
while getopts "i:f:c:p:t:m:sh" opt; do
    case $opt in
        i) INPUT_FASTA="$OPTARG" ;;
        f) MAPPING_FILE="$OPTARG" ;;
        c) INDEX_COLS="$OPTARG" ;;
        p) PERCENTAGE_DIVERGENCE="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        m) AVAILABLE_MEMORY="$OPTARG" ;;
        s) SAVE_INTERMEDIARY=true ;;
        h) help; exit 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; help; exit 1 ;;
        :) echo "Missing required parameter: -$OPTARG" >&2; help; exit 1 ;;
    esac
done

# Validate required arguments
if [ -z "$INPUT_FASTA" ]; then
    echo "Error: Input FASTA file is required (-i)." >&2
    help
    exit 1
fi

if [ ! -f "$INPUT_FASTA" ]; then
    echo "Error: Input FASTA file '$INPUT_FASTA' does not exist." >&2
    exit 1
fi

if [ -z "$MAPPING_FILE" ]; then
    echo "Error: Mapping file is required (-f)." >&2
    help
    exit 1
fi

if [ ! -f "$MAPPING_FILE" ]; then
    echo "Error: Mapping file '$MAPPING_FILE' does not exist." >&2
    exit 1
fi

if [ -z "$INDEX_COLS" ]; then
    echo "Error: Index columns are required (-c)." >&2
    help
    exit 1
fi

# Validate index columns
IFS=',' read -r -a index_cols_array <<< "$INDEX_COLS"

if [ "${#index_cols_array[@]}" -lt 2 ]; then
    echo "Error: At least 2 columns are required in INDEX_COLS (1 for sequence ID + at least 1 category column)." >&2
    exit 1
fi

if [ "${#index_cols_array[@]}" -gt 5 ]; then
    echo "Error: Cannot have more than 5 columns in INDEX_COLS (1 for sequence ID + max. 4 categories)." >&2
    exit 1
fi

# Validate percentage divergence
if [ -z "$PERCENTAGE_DIVERGENCE" ]; then
    echo "Error: PERCENTAGE_DIVERGENCE value is required." >&2
    exit 1
fi

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
    find . -type f -name ${INPUT_FASTA%.fasta} -delete
fi

echo
echo "All processing completed!"