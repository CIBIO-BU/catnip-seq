#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Script to create a conda environment with:
# Python 3.11
# cd-hit (4.8.1)
# bowtie2 (2.4.1)

ENV="$1"

# If no environment name is given, use current directory name
if [ "$ENV-" == "-" ]; then
    CDIR=$(basename "$PWD")
    ENV="${CDIR}_env"
fi

set -o pipefail
set -e

# Check if conda is available
if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: conda is not installed. Please install conda first."
    exit 1
fi

# Create environment if it does not exist
if conda env list | grep -E "^$ENV\s" >/dev/null 2>&1; then
    echo "conda environment $ENV already exists, skipping creation..."
else
    echo "Creating conda environment $ENV with Python 3.11..."
    conda create -n "$ENV" python=3.11 -y
fi

# Enable conda in current shell
CUR_SHELL=shell.$(basename -- "${SHELL}")
eval "$(conda "$CUR_SHELL" hook)"

# Activate environment
conda activate "$ENV"
echo "INFO: conda environment $ENV activated"

# Conda channels
REPOS=(-c bioconda -c conda-forge)

# Install cd-hit 4.8.1 and bowtie2 2.4.1
conda install -n "$ENV" -y "${REPOS[@]}" cd-hit=4.8.1 bowtie2=2.4.1

echo "All done. Python 3.11, cd-hit, and bowtie2 installed in environment $ENV."
exit 0