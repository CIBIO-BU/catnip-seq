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

def filter_cat_thresholds(processed_bam, cat_thresholds: list):
        # If threhsold is the same just filter directly to save computation time
        if len(cat_thresholds) <= 1 or all(float(threshold == cat_thresholds[0]) for threshold in cat_thresholds):
            threshold = cat_thresholds[0]
            return processed_bam[processed_bam['divergence_prct'].astype(int) <= threshold]

        else:
            def count_non_nan(values):
                # count nan values in query category to discover at which level the entry is
                if not isinstance(values, (tuple, list)):
                    return 0
                count = 0
                for val in values:
                    if val is None:
                        continue
                    if isinstance(val, float) and np.isnan(val):
                        continue
                    count += 1

                return count

            processed_bam = processed_bam.copy()
            processed_bam['cat_level'] = processed_bam['query_cat'].apply(count_non_nan)

            def apply_threshold(row):
                level = row['cat_level'] # applies the threhsold according to the category/column
                if level == 0:
                    return False
                threshold = float(cat_thresholds[level - 1])
                divergence_int = int(row['divergence_prct'])
                return divergence_int <= threshold

            filt_threshold_df = processed_bam[processed_bam.apply(apply_threshold, axis=1)]
            return filt_threshold_df

def process_bam(alignment_file, cat_thresholds, mapping_file, columns, save_processed=False):
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

    cat_threshold_filt = filter_cat_thresholds(minimums, cat_thresholds)

    clean_cat_threshold_filt = cat_threshold_filt[['query', 'query_cat', 'target', 'target_cat', 'edit_distance', 'divergence_prct']]

    if save_processed == True:
        base = os.path.splitext(os.path.basename(alignment_file))[0]
        # processed_df.to_csv(f"{base}_processed.tsv", sep='\t', header=True, index=None)
        clean_cat_threshold_filt.to_csv(f'{base}_intraclst_mins.tsv', sep='\t', header=True, index=None)

    return clean_cat_threshold_filt

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description="Pre-process bam file to remove selg-aligments and same group aligments and retrieve edit distances and divergence scores.")
    arg_parser.add_argument("--bam_file", type=str, help="Path to the bam file.")
    arg_parser.add_argument("--cat_thresholds", type=str, help="List of thresholds for the categories.")
    arg_parser.add_argument("--mapping_file", type=str, help="Path to the mapping file (tab-separated).")
    arg_parser.add_argument("--index_cols", type=str, required=True, help="Index of the columns to use for mapping file.")
    arg_parser.add_argument("--save", action="store_true", help="If enabled, saves the processed file.")
    args = arg_parser.parse_args()

    if args.index_cols:
        args.index_cols = [int(value) for value in args.index_cols.split(",")]

    if args.cat_thresholds:
        args.cat_thresholds = [float(value.strip()) for value in args.cat_thresholds.split(",")]

    process_bam(alignment_file=args.bam_file, cat_thresholds=args.cat_thresholds, mapping_file=args.mapping_file, columns=args.index_cols, save_processed=args.save)
    # path = '/home/camilababo/Documents/coding-projects/CD-HIT/test-workflow/coi_micointf_mil_4_align.bam'
    # mapping_file = '/home/camilababo/Documents/coding-projects/CD-HIT/test-workflow/coi_micointf_mil_mapping.tsv'
    # process_bam(path, mapping_file)
    # # Before: (219699, 4)
    # # After: (4762, 4)

