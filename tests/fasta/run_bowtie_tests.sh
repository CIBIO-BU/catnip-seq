#!/usr/bin/env bash
# -*- coding: utf-8 -*-

FASTA_DIR=.
FASTA_FILES=$(ls $FASTA_DIR/*.fasta)
SCRIPT2RUN=../../src/run_bowtie_aligner.sh
THREADS=2

for f in $FASTA_FILES; do
    ${SCRIPT2RUN} $f index $THREADS out 2> /dev/null
    N=$(samtools view out.bam 2> /dev/null | cut -f 1,3 | awk -F'\t' '$1 != $2' | wc -l )
    echo "$f:$N"
    rm -f out.bam
done

exit 0
