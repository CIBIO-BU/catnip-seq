import pysam
import pandas as pd
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

def process_bam(alignment_file, mapping_file=None, save_processed=False, output_file=None):
    seqid_to_cat = create_mapping_lookup_dictionary(mapping_file)
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

    # TODO: for OTL lookup find a hit in either query_cat and target_cat

    # print(f"Successfully filtered the bam file:")
    # print(processed_df.head())
    # print(f"Total alignments after filtering: {processed_df.shape[0]}.")

    if save_processed == True:
        if not output_file:
            base = os.path.splitext(os.path.basename(alignment_file))[0]
        # processed_df.to_csv(f"{base}_processed".tsv", sep='\t', header=True, index=None)
        minimums.to_csv(f'{base}_intraclst_mins.tsv', sep='\t', header=True, index=None)

    return processed_df

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description="Pre-process bam file to remove selg-aligments and same group aligments and retrieve edit distances and divergence scores.")
    arg_parser.add_argument("--bam_file", type=str, help="Path to the bam file.")
    arg_parser.add_argument("--mapping_file", type=str, help="Path to the mapping file (tab-separated).")
    arg_parser.add_argument("--save", action="store_true", help="If enabled, saves the processed file.")
    args = arg_parser.parse_args()
    process_bam(alignment_file=args.bam_file, mapping_file=args.mapping_file, save_processed=args.save)
    # path = '/home/camilababo/Documents/coding-projects/CD-HIT/test-workflow/coi_micointf_mil_4_align.bam'
    # mapping_file = '/home/camilababo/Documents/coding-projects/CD-HIT/test-workflow/coi_micointf_mil_mapping.tsv'
    # process_bam(path, mapping_file)
    # # Before: (219699, 4)
    # # After: (4762, 4)

