# CATnip Workflow

CATnip a tool to assess nucleotide divergence and sequence resolution between user-defined categories.

## Prerequisites

- Conda or Mamba
- Git

## Quick Start

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

## Environment Details

For filtering divergence values are rounded to the NEAREST WHOLE VALUE. However, output is presented with one decimal case.