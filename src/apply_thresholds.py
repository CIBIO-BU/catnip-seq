import argparse
import numpy as np

def filter_cat_thresholds(processed_bam, cat_thresholds: list):
        # If threhsold is the same just filter directly to save computation time
        if len(cat_thresholds) <= 1 or all(float(threshold == cat_thresholds[0]) for threshold in cat_thresholds):
            threshold = cat_thresholds[0]
            return processed_bam[processed_bam['divergence_prct'] > threshold]

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
            divergence_int = round(row['divergence_prct'], 1)
            return divergence_int >= threshold

        filt_threshold_df = processed_bam[processed_bam.apply(apply_threshold, axis=1)]

        filt_threshold_df.to_csv("processed_bam_filtered_thresholds.tsv", sep='\t', header=True, index=False)

        return filt_threshold_df

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description="Pre-process bam file to remove selg-aligments and same group aligments and retrieve edit distances and divergence scores.")
    arg_parser.add_argument("--bam_file", type=str, help="Path to the bam file.")
    arg_parser.add_argument("--cat_thresholds", type=str, help="List of thresholds for the categories.")
    args = arg_parser.parse_args()


    if args.cat_thresholds:
        args.cat_thresholds = [float(value.strip()) for value in args.cat_thresholds.split(",")]