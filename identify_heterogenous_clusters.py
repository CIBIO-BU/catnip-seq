import pandas as pd
from collections import defaultdict
import logging
import argparse

def list_heterogenous_clusters(cluster_file, mapping_file):
    try:
        map_df = pd.read_csv(mapping_file, sep='\t', header=None, index_col=None)
        print(f"Loaded mapping file with {len(map_df)} entries:")
        print(map_df.head())
    except FileNotFoundError:
        raise FileNotFoundError(f"Mapping file not found: {mapping_file}")
    except Exception as e:
        raise Exception(f"Error loading mapping file: {e}")

    # lookup dictionary for seq_id/tax mappings
    seqid_to_tax = {}
    for ind, row in map_df.iterrows():
        seq_id = row.iloc[0]
        tax_tuple = tuple(row.iloc[1:4])
        seqid_to_tax[seq_id] = tax_tuple

    heterogenous_clusters = []
    cluster_data = defaultdict(list)
    current_cluster = None

    try:
        with open(cluster_file, 'r') as file:
            for line_number, line in enumerate(file, 1):
                line = line.strip()

                if not line: # skip empty lines
                    continue

                if line.startswith('>'):
                    # process the previous cluster if it exists
                    if current_cluster is not None:
                        _check_cluster_heterogeneity(current_cluster, cluster_data, heterogenous_clusters)

                    # start a new cluster
                    cluster = line.strip('>').split(' ')[-1]
                    current_cluster = cluster
                    cluster_data[current_cluster] = []

                else:
                    if current_cluster is None:
                        logging.warning(f"Line without cluster head at line {line_number}: {line}.")
                        continue

                    try: # extract seq_id
                        seq_id = line.split(' ')[1].strip('>').strip('.').split('|')[0]

                    except (IndexError, AttributeError) as e:
                        logging.warning(f" Could not parse seq_id at line {line_number}: {line}.")
                        continue

                    if seq_id in seqid_to_tax: # retrive taxonomy tuple for this sequence
                        tax_tuple = seqid_to_tax[seq_id]
                        cluster_data[current_cluster].append((seq_id, tax_tuple))

                    else:
                        logging.warning(f"Seq_id '{seq_id}' not found in mapping file.")

        # Process the last cluster
        if current_cluster is not None:
            _check_cluster_heterogeneity(current_cluster, cluster_data, heterogenous_clusters)

    except FileNotFoundError:
        raise FileNotFoundError(f"Cluster file not found: {cluster_file}")
    except Exception as e:
        raise Exception(f"Error loading cluster file: {e}")

    print(f"Found {len(heterogenous_clusters)} heterogenous clusters.")

    return heterogenous_clusters

def _check_cluster_heterogeneity(cluster_number, cluster_data, heterogenous_clusters):
    sequences = cluster_data[cluster_number]

    if len(sequences) < 2:
        return

    first_tax = sequences[0][1]
    for seq_id, tax_tuple in sequences[1:]:
        if tax_tuple != first_tax:
            heterogenous_clusters.append(cluster_number)
            return


if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description="Identify and list heterogenous clusters.")
    arg_parser.add_argument("--cluster_file", type=str, help="Path to the cluster file.")
    arg_parser.add_argument("--mapping_file", type=str, help="Path to the mapping file between seq_ids to taxonomy.")
    args = arg_parser.parse_args()
    list_heterogenous_clusters(cluster_file=args.cluster_file, mapping_file=args.mapping_file)




