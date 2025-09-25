import pysam
import pandas as pd
import argparse
import os

from identify_heterogenous_clusters import create_mapping_lookup_dictionary

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
    # minimums = (processed_df.loc[processed_df.groupby(['query_cat', 'target_cat'])['edit_distance'].idxmin()].reset_index(drop=True))

    # TODO: find minimum between query_cat and target_cat symetrics
    # TODO: for OTL lookup find a hit in either query_cat and target_cat

    print(f"Successfully filtered the bam file:")
    print(processed_df.head())
    print(f"Total alignments after filtering: {processed_df.shape[0]}.")

    if save_processed == True:
        if not output_file:
            base = os.path.splitext(os.path.basename(alignment_file))[0]
            output_file = f"{base}_processed.tsv"
        processed_df.to_csv(output_file, sep='\t', header=True, index=None)
        # minimums.to_csv('min_processed.tsv', sep='\t', header=True, index=None)

    return processed_df

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description="Pre-process bam file to remove selg-aligments and same group aligments and retrieve edit distances and divergence scores.")
    arg_parser.add_argument("--bam_file", type=str, help="Path to the bam file.")
    arg_parser.add_argument("--mapping_file", type=str, help="Path to the mapping file (tab-separated).")
    arg_parser.add_argument("--save", action="store_true", help="If enabled, saves the processed file.")
    args = arg_parser.parse_args()
    process_bam(alignment_file=args.bam_file, mapping_file=args.mapping_file, save_processed=args.save)
    # path = '/home/camilababo/Documents/coding-projects/CD-HIT/test-cases/no_tx/ntx.bam'
    # mapping_file = '/home/camilababo/Documents/coding-projects/CD-HIT/test-cases/mapping_file.tsv'
    # process_bam(path, mapping_file)
    # # Before: (219699, 4)
    # # After: (4762, 4)
