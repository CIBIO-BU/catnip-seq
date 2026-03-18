#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Get input args
INPUT_FASTA=$1 #FASTA file for a cluster
INDEX_NAME=$2
THREADS=$3
ALIGN_NAME=$4

BOWTIE_K=20
# echo "Running bowtie indexer with the following parameters:"
# echo "Input FASTA: $INPUT_FASTA"
# echo "Index File: $INDEX_NAME"
# echo "Threads: $THREADS"

set -o pipefail -e

bowtie2-build --quiet -f --threads "$THREADS" "$INPUT_FASTA" "$INDEX_NAME"

bowtie2 --quiet -f  -L 10 -N 1 -k $BOWTIE_K --very-sensitive --threads "$THREADS" -x "$INDEX_NAME" -U "$INPUT_FASTA" \
| samtools sort -o "$ALIGN_NAME".bam 

# The script should not delete the input file, this should be done by the calling script
#rm -f "${INPUT_FASTA}"

# clean up
rm -f "${INDEX_NAME}".*.bt2

exit 0
