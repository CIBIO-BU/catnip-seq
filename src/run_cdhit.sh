#!/usr/bin/env bash

# Get input args
INPUT_FASTA=$1
OUTPUT_FILE=$2
PERCENTAGE_IDENTITY=$3
THREADS=$4
AVAILABLE_MEMORY=$5

# echo "Running CD-HIT with the following parameters:"
# echo "Input FASTA: $INPUT_FASTA"
# echo "Output File: $OUTPUT_FILE"
# echo "Percentage Identity: $PERCENTAGE_IDENTITY"
# echo "Threads: $THREADS"
# echo "Available Memory: $AVAILABLE_MEMORY"

cd-hit -i "$INPUT_FASTA" -o "$OUTPUT_FILE" -d 0 -c "$PERCENTAGE_IDENTITY" -G 1 -T "$THREADS" -M "$AVAILABLE_MEMORY"

