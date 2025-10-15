#!/usr/bin/env bash
# -*- coding: utf-8 -*-

set -euo pipefail

WRKFL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments before entering timed section
# Default values
PERCENTAGE_IDENTITY=0.9
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

# Run catnip with timing
logfile="timing.log"
/usr/bin/time -f "Time elapsed: %E | User CPU: %Us | System CPU: %Ss | Max RSS: %M KB" \
    -o "$logfile" \
    "${WRKFL_DIR}/src/catnip.sh" \
    "$INPUT_FASTA" \
    "$PERCENTAGE_IDENTITY" \
    "$THREADS" \
    "$AVAILABLE_MEMORY" \
    "$SAVE_INTERMEDIARY" \
    "$WRKFL_DIR"

echo
echo "Log:"
cat "$logfile"