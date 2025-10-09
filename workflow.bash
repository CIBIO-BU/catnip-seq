#!/usr/bin/env bash
# -*- coding: utf-8 -*-

set -euo pipefail

WRKFL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments before entering timed section
# Default values
PERCENTAGE_IDENTITY=90
THREADS=1
AVAILABLE_MEMORY=800
SAVE_INTERMEDIARY=false

# Help function
help() {
    cat << EOF
Usage: ${0##*/} -i INPUT_FASTA [OPTIONS]

Compute nucleotide divergence across user-defined categories.

Required arguments:
    -i INPUT_FASTA          Input FASTA file path.

Optional arguments:
    -p PERCENTAGE_IDENTITY  Threshold for the percentage identity (default: 90)
    -t THREADS              Number of threads to use (default: 1)
    -m AVAILABLE_MEMORY     Available memory in MB   (default: 200)
    -s                      Save intermediary files (cluster BAM and minimu files; default: false)
    -h                      Displays this help meassage and exits.

Example:
    ${0##*/} -i sequences.fasta -p 95 -t 8 -m 16000 -s

EOF
}

while getopts "i:p:t:m:sh" opt; do
    case $opt in
        i)
            INPUT_FASTA="$OPTARG"
            ;;
        p)
            PERCENTAGE_IDENTITY="$OPTARG"
            ;;
        t)
            THREADS="$OPTARG"
            ;;
        m)
            AVAILABLE_MEMORY="$OPTARG"
            ;;
        s)
            SAVE_INTERMEDIARY=true
            ;;
        h)
            help
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            help
            exit 1
            ;;
        :)
            echo "Missing required parameter: -$OPTARG" >&2
            help
            exit 1
            ;;
    esac
done

if [ ! -f "$INPUT_FASTA" ]; then
    echo "Error: Input Fasta file "$INPUT_FASTA" does not exist."
    exit 1
fi

logfile="timing.log"
/usr/bin/time -f "Time elapsed: %E | User CPU: %Us | System CPU: %Ss | Max RSS: %M KB" -o "$logfile" bash -c '

# Set scripts directory
CONFIG_DIR="'"$WRKFL_DIR"'"
SCRIPTS_DIR="$CONFIG_DIR/src"

# Import variables
INPUT_FASTA="'"$INPUT_FASTA"'"
PERCENTAGE_IDENTITY="'"$PERCENTAGE_IDENTITY"'"
THREADS="'"$THREADS"'"
AVAILABLE_MEMORY="'"$AVAILABLE_MEMORY"'"
SAVE_INTERMEDIARY="'"$SAVE_INTERMEDIARY"'"

echo "Starting workflow with the following parameters:"
echo "  Input file: $INPUT_FASTA"
echo "  Identity threshold: $PERCENTAGE_IDENTITY"
echo "  Threads: $THREADS"
echo "  Memory: $AVAILABLE_MEMORY"
echo "  Save intermediary files: $SAVE_INTERMEDIARY"


MAPPING_FILE="${INPUT_FASTA%.fasta}_mapping.tsv"
if [ -f "$MAPPING_FILE" ]; then
    echo "Mapping file already exists: $MAPPING_FILE. Skipping mapping step..."
else
    echo "Mapping sequence IDs to categories..."
    python "${SCRIPTS_DIR}/mapping_helper.py" "$INPUT_FASTA" #>/dev/null 2>&1
fi

# echo "Cleaning FASTA file..."
python "${SCRIPTS_DIR}/fasta_cleaner_helper.py" "$INPUT_FASTA" #>/dev/null 2>&1

CLEAN_FASTA="${INPUT_FASTA%.fasta}_clean.fasta"
OUTPUT_FILE_NAME="${INPUT_FASTA%.fasta}"

if [ ! -f "$CLEAN_FASTA" ]; then
    echo "Error: Cleaned FASTA file was not created."
    exit 1
fi

CLSTR_FILE="${OUTPUT_FILE_NAME}.clstr"
if [ -f "$CLSTR_FILE" ]; then
    echo "Cluster file already exists: $CLSTR_FILE. Skipping clustering step..."
else
    echo "Clustering sequences at ("$PERCENTAGE_IDENTITY") identity..."
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

echo "Identifying heterogenous clusters..."
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
echo "Found $total heterogenous clusters: $HET_CLUSTERS_LIST"

for CLUSTER_NUMBER in $HET_CLUSTERS_LIST; do
    count=$((count + 1))
    percent=$(( 100 * count / total ))
    printf "\rProcessing clusters: [%-50s] %3d%%" \
        $(printf "%*s" $(( percent * 50 / 100 )) | tr " " "#") "$percent"

    CST_OUTPUT_FILE="${OUTPUT_FILE_NAME}_${CLUSTER_NUMBER}.fasta"
    INDEX_NAME="${CST_OUTPUT_FILE%.fasta}_index"
    ALIGN_NAME="${CST_OUTPUT_FILE%.fasta}_align"

    # echo "  Extracting cluster sequences..."
    python "${SCRIPTS_DIR}/cluster_extractor.py" "$OUTPUT_FILE" \
        --fasta_file "$CLEAN_FASTA" \
        --cluster_number "$CLUSTER_NUMBER" \
        --output_file "$CST_OUTPUT_FILE" # \
        # >/dev/null 2>&1

    if [ ! -f "$OUTPUT_FILE" ]; then
        echo " Warning: Failed to extract cluster $CLUSTER_NUMBER, skipping..."
        continue
    fi

    # echo "  Running Bowtie alignment..."
    bash "${SCRIPTS_DIR}/run_bowtie_aligner.sh" \
        "$CST_OUTPUT_FILE" "$INDEX_NAME" \
        1 $ALIGN_NAME # \
        # >/dev/null 2>&1

    BAM_FILE="${ALIGN_NAME}.bam"
    if [ -f "$BAM_FILE" ]; then
        # echo "  Pre-processing BAM file..."
        python "${SCRIPTS_DIR}/pre_process_bam.py" \
        --bam_file "$BAM_FILE" \
        --mapping_file "$MAPPING_FILE" \
        --save #\
        # >/dev/null 2>&1

    else
        echo "  Warning: BAM file $BAM_FILE not found, skipping pre-processing..."
    fi

    # echo "  Completed processing cluster: $CLUSTER_NUMBER."

done

echo
echo "Compiling inter-cluster results..."
python "${SCRIPTS_DIR}/compile_interclust.py" .

# Clean up intermediary files if not saving
if [ "$SAVE_INTERMEDIARY" = "false" ]; then
    find . -type f -name \*_align.bam -delete
    find . -type f -name \*_intraclst_mins.tsv -delete
fi

echo
echo "All processing completed!"

'
echo
echo "Log:"
cat "$logfile"
