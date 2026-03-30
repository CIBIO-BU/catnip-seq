# CATnip Workflow

[![Anaconda-Server Badge](https://anaconda.org/bioconda/catnip-seq/badges/version.svg)](https://anaconda.org/bioconda/catnip-seq) [![Anaconda-Server Badge](https://anaconda.org/bioconda/catnip-seq/badges/latest_release_date.svg)](https://anaconda.org/bioconda/catnip-seq) [![Anaconda-Server Badge](https://anaconda.org/bioconda/catnip-seq/badges/downloads.svg)](https://anaconda.org/bioconda/catnip-seq) [![Anaconda-Server Badge](https://anaconda.org/bioconda/catnip-seq/badges/license.svg)](https://anaconda.org/bioconda/catnip-seq)

CATnip a tool to assess nucleotide divergence and sequence resolution between user-defined categories.

## Prerequisites

- Conda or Mamba
- Git

## Installation (Recommended)

Install CATnip directly from Bioconda:

```bash
conda create -n catnip -c conda-forge -c bioconda catnip-seq
conda activate catnip
```

Or faster with mamba:

```bash
mamba create -n catnip -c conda-forge -c bioconda catnip-seq
```

## Development Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/CIBIO-BU/catnip
   cd catnip
   ```

2. **Create the conda environment:**
   ```bash
   conda env create -f catnip-env.yml
   ```

3. **Activate the environment:**
   ```bash
   conda activate catnip
   ```

4. **Install catnip command:**
   ```bash
   pip install -e .
   ```

5. **Check help message:**
   ```bash
   catnip -h
   ```

6. **Run the test workflow:**
   ```bash
   cd test-workflow
   catnip -i coi_micointf_mil.fasta -f coi_micointf_mil_mapping.tsv -c 0,1,2,3 -p 10
   ```

## Environment Details

The conda environment includes:
- Python 3.11
- CD-HIT 4.8.1 (sequence clustering)
- Bowtie2 2.5.4 (sequence alignment)
- SAMtools (BAM/SAM file processing)
- pysam (Python interface for SAM/BAM files)
- pandas & numpy (data analysis)

## Documentation

Divergence values are rounded to the NEAREST WHOLE VALUE. However, output is presented with one decimal case.