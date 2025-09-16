import argparse

def keep_seqid_only(fasta_file, separator='|', output_file=None):
    fasta_name = fasta_file.split("/")[-1].split(".")[0]
    print(f"Proccessing file: {fasta_file}")
    if output_file:
        output_file = output_file if output_file.endswith('.fasta') else f"{output_file}.fasta"
    else:
        output_file = f"{fasta_name}_clean.fasta"

    with open(fasta_file, "r") as infile, open(output_file, "w") as outfile:
        for line in infile:
            line = line.strip()
            if line.startswith('>'):
                clean_header = line.split(separator)[0]
                outfile.write(f"{clean_header}\n")
            else:
                outfile.write(f"{line}\n")

        return output_file


if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(description="Clean FASTA files.")
    arg_parser.add_argument("fasta_file", type=str, help="Path to the FASTA file.")
    arg_parser.add_argument("--output", type=str, help="Output to clean FASTA file name (default: <fasta_file>_clean.csv).")
    arg_parser.add_argument("--separator", type=str, default='|', help="Separator used in FASTA headers (default: '|').")
    args = arg_parser.parse_args()
    keep_seqid_only(args.fasta_file, output_file=args.output, separator=args.separator)

