#!/bin/bash

# Get input args
source ~/miniconda3/etc/profile.d/conda.sh
conda activate #TODO: specify environment name


INPUT_FASTA=$1
INDEX_NAME=$2
THREADS=$3

echo "Running bowtie indexer with the following parameters:"
echo "Input FASTA: $INPUT_FASTA"
echo "Index File: $INDEX_NAME"
echo "Threads: $THREADS"

bowtie2-build -f --threads "$THREADS" "$INPUT_FASTA" "$INDEX_NAME"
