import pandas as pd
import argparse
from pathlib import Path

from pre_process_bam import find_minimums

def compile_interclust(path):
    dir = Path(path)
    files = list(dir.rglob('*intraclst_mins.tsv'))

    intra_clst_dfs = []
    for file in files:
        df = pd.read_csv(file, sep='\t', header=0, index_col=None)
        intra_clst_dfs.append(df)

    expected_columns = ['query', 'query_cat', 'target', 'target_cat', 'edit_distance', 'divergence_prct']

    # Filter out empty dataframes
    non_empty_dfs = [df for df in intra_clst_dfs if not df.empty]
    if non_empty_dfs:
        combined_clsts = pd.concat(non_empty_dfs, axis=0, ignore_index=True)
    else:
        combined_clsts = pd.DataFrame(columns=expected_columns)

    if list(combined_clsts.columns) != expected_columns:
        print(f"Warning: Column names don't match expected. Found: {list(combined_clsts.columns)}")
        combined_clsts.columns = expected_columns

    min_combined = find_minimums(combined_clsts)

    min_combined.to_csv("final_output_interclst.tsv", sep='\t', header=True, index=False)

    return min_combined

if __name__ == '__main__':
    arg_parse = argparse.ArgumentParser("description= Combine intra-cluster files.")
    arg_parse.add_argument("path", type=str, help='Path to the folder containing intra-cluster files.')
    args = arg_parse.parse_args()
    compile_interclust(path=args.path)