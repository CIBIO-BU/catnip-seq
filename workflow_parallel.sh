#!/usr/bin/env bash
# -*- coding: utf-8 -*-

set -euo pipefail

WRKFL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
PERCENTAGE_IDENTITY=90
THREADS=8
AVAILABLE_MEMORY=800
SAVE_INTERMEDIARY=false
PARALLEL_JOBS=4  # Number of parallel Bowtie instances

help() {
    cat << EOF
Usage: ${0##*/} -i INPUT_FASTA [OPTIONS]

Compute nucleotide divergence across user-defined categories (parallel version).

Required arguments:
    -i INPUT_FASTA          Input FASTA file path.

Optional arguments:
    -p PERCENTAGE_IDENTITY  Threshold for the percentage identity (default: 90)
    -t THREADS              Total threads available (default: 8)
    -j PARALLEL_JOBS        Number of parallel Bowtie instances (default: 4)
    -m AVAILABLE_MEMORY     Available memory in MB (default: 800)
    -s                      Save intermediary files (default: false)
    -h                      Display this help message and exit

Example:
    ${0##*/} -i sequences.fasta -p 95 -t 8 -j 4 -m 16000 -s

Note: Total threads will be divided among parallel jobs.
      Example: -t 8 -j 4 means each Bowtie instance gets 2 threads.

EOF
}

while getopts "i:p:t:j:m:sh" opt; do
    case $opt in
        i) INPUT_FASTA="$OPTARG" ;;
        p) PERCENTAGE_IDENTITY="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        j) PARALLEL_JOBS="$OPTARG" ;;
        m) AVAILABLE_MEMORY="$OPTARG" ;;
        s) SAVE_INTERMEDIARY=true ;;
        h) help; exit 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; help; exit 1 ;;
        :) echo "Missing required parameter: -$OPTARG" >&2; help; exit 1 ;;
    esac
done

if [ -z "${INPUT_FASTA:-}" ]; then
    echo "Error: Input FASTA file is required (-i)" >&2
    help
    exit 1
fi

if [ ! -f "$INPUT_FASTA" ]; then
    echo "Error: Input FASTA file '$INPUT_FASTA' does not exist."
    exit 1
fi

# Check if GNU Parallel is available
if ! command -v parallel &> /dev/null; then
    echo "Error: GNU Parallel is not installed."
    echo "Install with: conda install -c conda-forge parallel"
    exit 1
fi

logfile="timing.log"
/usr/bin/time -f "Time elapsed: %E | User CPU: %Us | System CPU: %Ss | Max RSS: %M KB" -o "$logfile" bash -c '

CONFIG_DIR="'"$WRKFL_DIR"'"
SCRIPTS_DIR="$CONFIG_DIR/src"

INPUT_FASTA="'"$INPUT_FASTA"'"
PERCENTAGE_IDENTITY="'"$PERCENTAGE_IDENTITY"'"
THREADS="'"$THREADS"'"
AVAILABLE_MEMORY="'"$AVAILABLE_MEMORY"'"
SAVE_INTERMEDIARY="'"$SAVE_INTERMEDIARY"'"
PARALLEL_JOBS="'"$PARALLEL_JOBS"'"

# Calculate threads per job
THREADS_PER_JOB=$(( THREADS / PARALLEL_JOBS ))
if [ "$THREADS_PER_JOB" -lt 1 ]; then
    THREADS_PER_JOB=1
fi

echo "========================================"
echo "Starting parallel workflow"
echo "========================================"
echo "Input file: $INPUT_FASTA"
echo "Identity threshold: $PERCENTAGE_IDENTITY%"
echo "Total threads: $THREADS"
echo "Parallel jobs: $PARALLEL_JOBS"
echo "Threads per job: $THREADS_PER_JOB"
echo "Memory: $AVAILABLE_MEMORY MB"
echo "Save intermediary: $SAVE_INTERMEDIARY"
echo "========================================"

# Step 1: Mapping
MAPPING_FILE="${INPUT_FASTA%.fasta}_mapping.tsv"
if [ -f "$MAPPING_FILE" ]; then
    echo "Mapping file exists: $MAPPING_FILE (skipping)"
else
    echo "Creating mapping file..."
    python "${SCRIPTS_DIR}/mapping_helper.py" "$INPUT_FASTA"
fi

# Step 2: Cleaning
echo "Cleaning FASTA file..."
python "${SCRIPTS_DIR}/fasta_cleaner_helper.py" "$INPUT_FASTA"

CLEAN_FASTA="${INPUT_FASTA%.fasta}_clean.fasta"
OUTPUT_FILE_NAME="${INPUT_FASTA%.fasta}"

if [ ! -f "$CLEAN_FASTA" ]; then
    echo "Error: Cleaned FASTA file was not created."
    exit 1
fi

# Step 3: Clustering
CLSTR_FILE="${OUTPUT_FILE_NAME}.clstr"
if [ -f "$CLSTR_FILE" ]; then
    echo "Cluster file exists: $CLSTR_FILE (skipping)"
else
    echo "Clustering sequences at ${PERCENTAGE_IDENTITY}% identity..."
    bash "${SCRIPTS_DIR}/run_cdhit.sh" \
        "$CLEAN_FASTA" "$OUTPUT_FILE_NAME" \
        "$PERCENTAGE_IDENTITY" "$THREADS" \
        "$AVAILABLE_MEMORY" \
        >/dev/null 2>&1
fi

if [ ! -f "$OUTPUT_FILE_NAME" ]; then
    echo "Error: Clustering output was not created."
    exit 1
fi

# Step 4: Identify heterogeneous clusters
echo "Identifying heterogeneous clusters..."
OUTPUT_FILE="${INPUT_FASTA%.fasta}.clstr"
HET_CLUSTERS_LIST=$(python "${SCRIPTS_DIR}/identify_heterogenous_clusters.py" \
    --cluster_file "$OUTPUT_FILE" \
    --mapping_file "$MAPPING_FILE")

if [ -z "$HET_CLUSTERS_LIST" ]; then
    echo "No heterogeneous clusters found. Processing complete."
    exit 0
fi

TOTAL_CLUSTERS=$(echo "$HET_CLUSTERS_LIST" | wc -w)
echo "Found $TOTAL_CLUSTERS heterogeneous clusters"
echo "========================================"

# Step 5: Process clusters in parallel
echo "Processing clusters with $PARALLEL_JOBS parallel jobs..."

# Export variables for parallel subshells
export SCRIPTS_DIR
export OUTPUT_FILE
export CLEAN_FASTA
export OUTPUT_FILE_NAME
export MAPPING_FILE
export THREADS_PER_JOB

# Define the processing function
process_cluster() {
    local CLUSTER_NUMBER=$1

    CST_OUTPUT_FILE="${OUTPUT_FILE_NAME}_${CLUSTER_NUMBER}.fasta"
    INDEX_NAME="${CST_OUTPUT_FILE%.fasta}_index"
    ALIGN_NAME="${CST_OUTPUT_FILE%.fasta}_align"

    # Extract cluster
    python "${SCRIPTS_DIR}/cluster_extractor.py" "$OUTPUT_FILE" \
        --fasta_file "$CLEAN_FASTA" \
        --cluster_number "$CLUSTER_NUMBER" \
        --output_file "$CST_OUTPUT_FILE" 2>/dev/null

    if [ ! -f "$CST_OUTPUT_FILE" ]; then
        return 1
    fi

    # Run Bowtie alignment
    bash "${SCRIPTS_DIR}/run_bowtie_aligner.sh" \
        "$CST_OUTPUT_FILE" "$INDEX_NAME" \
        "$THREADS_PER_JOB" "$ALIGN_NAME" 2>/dev/null

    # Process BAM file
    BAM_FILE="${ALIGN_NAME}.bam"
    if [ -f "$BAM_FILE" ]; then
        python "${SCRIPTS_DIR}/pre_process_bam.py" \
            --bam_file "$BAM_FILE" \
            --mapping_file "$MAPPING_FILE" \
            --save 2>/dev/null
    fi
}

export -f process_cluster

# Use GNU Parallel to process all clusters (without --bar for SLURM compatibility)
echo "$HET_CLUSTERS_LIST" | tr " " "\n" | \
    parallel --line-buffer -j "$PARALLEL_JOBS" \
    "process_cluster {}"

echo
echo "========================================"

# Step 6: Compile results
echo "Compiling inter-cluster results..."
python "${SCRIPTS_DIR}/compile_interclust.py" .

# Step 7: Cleanup
if [ "$SAVE_INTERMEDIARY" = "false" ]; then
    echo "Cleaning up intermediary files..."
    find . -type f -name "*_align.bam" -delete
    find . -type f -name "*_intraclst_mins.tsv" -delete
fi

echo "========================================"
echo "Processing completed successfully!"
echo "========================================"

'
echo
echo "Timing log:"
cat "$logfile"