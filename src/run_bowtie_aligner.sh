#!/bin/bash

# Get input args
INPUT_FASTA=$1 #FASTA file for a cluster
INDEX_NAME=$2
THREADS=$3
ALIGN_NAME=$4

# echo "Running bowtie indexer with the following parameters:"
# echo "Input FASTA: $INPUT_FASTA"
# echo "Index File: $INDEX_NAME"
# echo "Threads: $THREADS"

bowtie2-build --quiet -f --threads "$THREADS" "$INPUT_FASTA" "$INDEX_NAME"

bowtie2 --quiet -f -k 20 --threads "$THREADS" -x "$INDEX_NAME" -U "$INPUT_FASTA" \
| samtools sort -o "$ALIGN_NAME".bam #TODO: check if -k 20 is appropriate!!!!

rm -f "${INPUT_FASTA}"
rm -f "${INDEX_NAME}".*.bt2
