#!/usr/bin/env bash
# -*- coding: utf-8 -*-
set -euo pipefail
WRKFL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments before entering timed section
# Default values
MAPPING_FILE=""
INDEX_COLS=""
PERCENTAGE_IDENTITY=0.9
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
 -c INDEX_COLS           Indices of the columns containing the categories to evaluate in the mapping file (maximum of 4). Note: column indices start from 0, where 0 refers to the sequence ID column.

Optional arguments:
 -p PERCENTAGE_IDENTITY  Threshold for the percentage identity (type:float, default: 0.9)
 -t THREADS              Number of threads to use (default: 1)
 -m AVAILABLE_MEMORY     Available memory in MB (default: 800)
 -s                      Save intermediary files (cluster BAM and minimuM files; default: false)
 -h                      Displays this help message and exits.

Example:
${0##*/} -i sequences.fasta -f mapping.tsv -c "column1,column2" -p 95 -t 8 -m 16000 -s
EOF
}

while getopts "i:f:c:p:t:m:sh" opt; do
    case $opt in
        i)
            INPUT_FASTA="$OPTARG"
            ;;
        f)
            MAPPING_FILE="$OPTARG"
            ;;
        c)
            INDEX_COLS="$OPTARG"
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
            SAVE_INTERMEDIARY=false
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

if [ -z "$INPUT_FASTA" ]; then
    echo "Error: Input FASTA file is required (-i)."
    help
    exit 1
fi

if [ ! -f "$INPUT_FASTA" ]; then
    echo "Error: Input FASTA file '$INPUT_FASTA' does not exist."
    exit 1
fi

if [ -z "$MAPPING_FILE" ]; then
    echo "Error: Mapping file is required (-f)."
    help
    exit 1
fi

if [ ! -f "$MAPPING_FILE" ]; then
    echo "Error: Mapping file '$MAPPING_FILE' does not exist."
    exit 1
fi

if [ -z "$INDEX_COLS" ]; then
    echo "Error: Index columns are required (-c)."
    help
    exit 1
fi

# Run catnip with timing
logfile="timing.log"
/usr/bin/time -f "Time elapsed: %E | User CPU: %Us | System CPU: %Ss | Max RSS: %M KB" \
    -o "$logfile" \
    "${WRKFL_DIR}/src/catnip.sh" \
    "$INPUT_FASTA" \
    "$MAPPING_FILE" \
    "$INDEX_COLS" \
    "$PERCENTAGE_IDENTITY" \
    "$THREADS" \
    "$AVAILABLE_MEMORY" \
    "$SAVE_INTERMEDIARY"  \
    "$WRKFL_DIR"

echo
echo "Log:"
cat "$logfile"