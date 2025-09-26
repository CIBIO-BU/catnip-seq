#!/usr/bin/env bash
# -*- coding: utf-8 -*-

ENV_FILE="catnip-env.yml"
set -o pipefail
set -e

# Check if conda is available
if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: conda is not installed. Please install conda first."
    exit 1
fi

# Check if YAML file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Environment file $ENV_FILE not found."
    exit 1
fi

# Create/update environment from YAML
echo "Creating/updating conda environment from $ENV_FILE..."
conda env create -f "$ENV_FILE" || conda env update -f "$ENV_FILE"

echo "Environment setup complete!"
echo "To activate: conda activate base-invaders"
echo "To deactivate: conda deactivate"