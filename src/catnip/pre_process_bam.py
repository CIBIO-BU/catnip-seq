import pysam
import pandas as pd
import numpy as np
import argparse
import os

from identify_heterogenous_clusters import create_mapping_lookup_dictionary

def find_minimums(df):
    def format_category(cat):
        """
        Convert category to string, handling NaN values in tuples/lists.
        """
        if pd.isna(cat):
            return "nan"
        elif isinstance(cat, (tuple, list)):
            return "_".join(str(x) for x in cat)
        else:
            return str(cat)

    # Make pairs of symmetric keys
    df['pair'] = df.apply(
        lambda row: "_".join(sorted([
            format_category(row['query_cat']),
            format_category(row['target_cat'])
        ])),
        axis=1
    )

    minimums = (df.loc[df.groupby('pair')['edit_distance'].idxmin()].reset_index(drop=True))
    minimums = minimums.drop(columns=['pair'])

    return minimums

def process_bam(alignment_file, mapping_file, columns, save_processed=False):
    seqid_to_cat = create_mapping_lookup_dictionary(mapping_file, columns)
    processed_data = []

    with pysam.AlignmentFile(alignment_file, 'rb') as bamfile:
        for read in bamfile.fetch(until_eof=True):  # stream sequentially without an index
            if read.is_unmapped:
                continue

            query, target = read.query_name, read.reference_name

            if query == target:
                continue

            query_cat = seqid_to_cat.get(query)
            target_cat = seqid_to_cat.get(target)

            if query_cat and target_cat and query_cat == target_cat:
                continue

            alignment_length = sum(value for operations, value in read.cigartuples)
            edit_distance = read.get_tag('NM')
            divergence = round(edit_distance/alignment_length * 100, 1)

            processed_data.append([query, query_cat, target, target_cat, edit_distance, divergence])

    processed_df = pd.DataFrame(processed_data, columns=['query', 'query_cat', 'target', 'target_cat', 'edit_distance', 'divergence_prct'])

    minimums = find_minimums(processed_df)

    minimums = minimums[['query', 'query_cat', 'target', 'target_cat', 'edit_distance', 'divergence_prct']]

    if save_processed == True:
        base = os.path.splitext(os.path.basename(alignment_file))[0]
        # processed_df.to_csv(f"{base}_processed.tsv", sep='\t', header=True, index=None)
        minimums.to_csv(f'{base}_intraclst_mins.tsv', sep='\t', header=True, index=None)

    return minimums

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description="Pre-process bam file to remove self-aligments and same group aligments and retrieve edit distances and divergence scores.")
    arg_parser.add_argument("--bam_file", type=str, help="Path to the bam file.")
    arg_parser.add_argument("--mapping_file", type=str, help="Path to the mapping file (tab-separated).")
    arg_parser.add_argument("--index_cols", type=str, required=True, help="Index of the columns to use for mapping file.")
    arg_parser.add_argument("--save", action="store_true", help="If enabled, saves the processed file.")
    args = arg_parser.parse_args()

    if args.index_cols:
        args.index_cols = [int(value) for value in args.index_cols.split(",")]

    process_bam(alignment_file=args.bam_file, mapping_file=args.mapping_file, columns=args.index_cols, save_processed=args.save)
    # path = 'test-workflow/coi_micointf_mil_4_align.bam'
    # mapping_file = 'test-workflow/coi_micointf_mil_mapping.tsv'
    # process_bam(path, mapping_file, columns=[0, 1, 2, 3])
    # # Before: (219699, 4)
    # # After: (4762, 4)

