import pandas as pd
import argparse
import os

def create_mappings(fasta_file, sep='|', output_file=None):
    mapping_tab = []
    fasta_file_name = os.path.splitext(os.path.basename(fasta_file))[0]
    if not output_file:
        output_file = f"{fasta_file_name}_mapping.tsv"

    with open(fasta_file, 'r') as file:
        for line in file:
            line = line.strip()
            if line.startswith('>'):
                header_parts = line.strip(">").split(sep)
                mapping_tab.append(header_parts)

    mapping_tab_df = pd.DataFrame(mapping_tab)

    mapping_tab_df.to_csv(output_file, sep='\t', header=False, index=False)

    # return output_file
    print(output_file)

if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(description="Map sequence IDs to categories or taxonomy from a FASTA file.")
    arg_parser.add_argument("fasta_file", type=str, help="Path to the FASTA file.")
    arg_parser.add_argument("--output", type=str, default=None, help="Output CSV file name (default: <fasta_file>_seqid_category_mapping.csv).")
    arg_parser.add_argument("--separator", type=str, default="|", help="Separator used in FASTA headers (default: '|').")
    args = arg_parser.parse_args()
    create_mappings(args.fasta_file, sep=args.separator, output_file=args.output)