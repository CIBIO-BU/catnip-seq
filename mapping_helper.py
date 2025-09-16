import pandas as pd
import numpy as np
import argparse

def map_seqid_category(fasta_file, separator='|', taxonomy=False, output_file=None):
    fasta_file_name = fasta_file.split('/')[-1].split('.')[0]
    print(f"Processing file: {fasta_file.split('/')[-1]}")
    seqid_map = {}
    has_data = False

    try:
        with open(fasta_file, "r") as file:
            for line in file:
                line = line.strip()
                if line.startswith(">"):
                    full_header = line
                    header_parts = line[1:].split(separator)
                    seq_id = header_parts[0] if header_parts else ""

                    if not seq_id:
                        continue

                    entry = {"seq_id": seq_id}

                    if taxonomy and len(header_parts) > 1:
                        taxonomy_fields = ["family", "genus", "species"]
                        for header_index, field_name in enumerate(taxonomy_fields, 1):
                            if header_index < len(header_parts):
                                taxa_nomeclature = header_parts[header_index]
                                entry[field_name] = taxa_nomeclature if taxa_nomeclature else np.nan
                                has_data = True
                            else:
                                entry[field_name] = np.nan

                    elif not taxonomy and len(header_parts) > 1:
                        category_fields = ["categoryA", "categoryB", "categoryC", "categoryC"]
                        for header_index, field_name in enumerate(category_fields, 1):
                            if header_index < len(header_parts):
                                cat_nomeclature = header_parts[header_index]
                                entry[field_name] = cat_nomeclature if cat_nomeclature else np.nan
                                has_data = True
                            else:
                                entry[field_name] = np.nan

                    seqid_map[seq_id] = entry

            if not seqid_map:
                if taxonomy:
                    return pd.DataFrame(columns=['seq_id', 'family', 'genus', 'species'])
                else:
                    return pd.DataFrame(columns=['seq_id'])

            df = pd.DataFrame.from_dict(seqid_map, orient='index')

            if output_file is None:
                output_file = f"{fasta_file_name}_seqid_category_mapping.csv"
                df.to_csv(output_file, index=False, sep='\t')
            else:
                output_file = output_file if output_file.endswith('.csv') else f"{output_file}.csv"
                df.to_csv(output_file, index=False, sep='\t')

            if not has_data:
                return df[['seq_id']]

            print(f"Mapping saved to: {output_file}")
            return df

    except FileNotFoundError:
        print(f"Error: File '{fasta_file}' not found.")
        return pd.DataFrame()
    except Exception as e:
        print(f"Error processing file: {e}")
        return pd.DataFrame()

if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(description="Map sequence IDs to categories or taxonomy from a FASTA file.")
    arg_parser.add_argument("fasta_file", type=str, help="Path to the FASTA file.")
    arg_parser.add_argument("--output", type=str, default=None, help="Output CSV file name (default: <fasta_file>_seqid_category_mapping.csv).")
    arg_parser.add_argument("--separator", type=str, default="|", help="Separator used in FASTA headers (default: '|').")
    arg_parser.add_argument("--taxonomy", action="store_true", help="Indicate if the FASTA headers contain taxonomy information.")
    args = arg_parser.parse_args()
    df = map_seqid_category(args.fasta_file, separator=args.separator, taxonomy=args.taxonomy, output_file=args.output)

    print(df.head())
