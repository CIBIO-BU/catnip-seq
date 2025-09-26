# CATnip Workflow

CATnip (Categories & Nucleotide Information Parser)

## Prerequisites

- Conda or Mamba
- Git

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/CIBIO-BU/category-resolution
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

4. **Run the test workflow:**
   ```bash
   cd test-workflow
   ../workflow.bash coi_micointf_mil.fasta 0.9 1 500
   ```

## Environment Details

The conda environment includes:
- Python 3.11
- CD-HIT 4.8.1 (sequence clustering)
- Bowtie2 2.5.4 (sequence alignment)
- SAMtools (BAM/SAM file processing)
- pysam (Python interface for SAM/BAM files)
- pandas & numpy (data analysis)