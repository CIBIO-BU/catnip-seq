#!/bin/bash

# Get input args
source ~/miniconda3/etc/profile.d/conda.sh
conda activate #TODO: specify environment name


INPUT_FASTA=$1
INPUT_IND=$2
THREADS=$3
ALIGN_NAME=$4

echo "Running bowtie end-to-end alignment with the following parameters:"
echo "Input FASTA: $INPUT_FASTA"
echo "Index File: $INPUT_IND"
echo "Output File: $ALIGN_NAME"
echo "Threads: $THREADS"

bowtie2 -f -k 20 --threads "$THREADS" -x "$INPUT_IND" -U "$INPUT_FASTA" -S "$ALIGN_NAME" #TODO: check if -k 20 is appropriate!!!!