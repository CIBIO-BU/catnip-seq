#!/bin/bash

# Get input args
source ~/miniconda3/etc/profile.d/conda.sh
conda activate base-invaders


INPUT_FASTA=$1
OUTPUT_FILE=$2
PERCENTAGE_IDENTITY=$3
THREADS=$5
AVAILABLE_MEMORY=$6

echo "Running CD-HIT with the following parameters:"
echo "Input FASTA: $INPUT_FASTA"
echo "Output File: $OUTPUT_FILE"
echo "Percentage Identity: $PERCENTAGE_IDENTITY"
echo "Threads: $THREADS"
echo "Available Memory: $AVAILABLE_MEMORY"

cd-hit -i "$INPUT_FASTA" -o "$OUTPUT_FILE" -d 0 -c "$PERCENTAGE_IDENTITY" -G 1 -T "$THREADS" -M "$AVAILABLE_MEMORY"

