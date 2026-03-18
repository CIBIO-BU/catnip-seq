#!/usr/bin/env python3
"""
Cleans up the catnip output files based on three taxonomic levels: family, genus, species.
"""
import argparse
import pandas as pd
import os

def clean_and_split(save_clean=True):
    """
    Cleans up taxa columns and splits them into family, genus, species.
    Keeps NaN as np.nan.

    Args:
        df: DataFrame to process
    Returns:
        DataFrame with added family, genus, species columns
    """
    output_file_path = "final_output_interclst.tsv"
    df = pd.read_csv(output_file_path, sep="\t")

    if 'edit_distance' in df.columns:
        df = df.drop('edit_distance', axis=1)

    col_prefix = ["query", "target"]

    for col_prefix in col_prefix:
        col = f"{col_prefix}_cat"

        # Remove brackets and parentheses of tuple
        df[col] = df[col].str.replace(r"[\'\(\)]", "", regex=True)

    if save_clean == True:
        base = os.path.splitext(os.path.basename(output_file_path))[0]
        # processed_df.to_csv(f"{base}_processed.tsv", sep='\t', header=True, index=None)
        df.to_csv(f'{base}_cleaned.tsv', sep='\t', header=True, index=None)

    return df

if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(description="Clean and split catnip output files based on taxonomic levels.")
    arg_parser.add_argument("--save_clean", action="store_true", help="If enabled, saves the cleaned file.")
    args = arg_parser.parse_args()
    cleaned_df = clean_and_split(save_clean=args.save_clean)