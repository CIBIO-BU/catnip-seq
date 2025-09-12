#!/usr/bin/env python3
"""
Extract sequences from a FASTA file based on a specific cluster from a clustering file.
"""

import re
import sys
from pathlib import Path

def parse_cluster_file(cluster_file, target_cluster):
    """
    Parse the clustering file and extract sequence IDs from the specified cluster.

    Parameters:
        cluster_file (str): Path to the clustering file
        target_cluster (int): Cluster number to extract

    Returns:
        set: Set of sequence IDs in the target cluster
    """
    print(f"Parsing cluster file {cluster_file} for cluster {target_cluster}...")
    seq_ids = []
    current_cluster = None
    in_target_cluster = False

    with open(cluster_file, 'r') as f:
        for line in f:
            line = line.strip()

            # Check if this is a cluster header
            cluster_header = re.match(r'>Cluster\s+(\d+)', line)
            if cluster_header:
                current_cluster = int(cluster_header.group(1))
                in_target_cluster = (current_cluster == target_cluster)

                # If we're in the target cluster, extract sequence IDs
            if in_target_cluster and line:
                # Extract sequence ID from lines like "0	421aa, >EMPUL14850-22|TX022... at 80.05%"
                seq_id_match = re.search(r'>([^|]+)\|', line)
                if seq_id_match:
                    seq_id = seq_id_match.group(1)
                    seq_ids.append(seq_id)

    print(f"Found {len(seq_ids)} sequences in cluster {target_cluster}.")

    return seq_ids

def extract_sequences_from_fasta(fasta_file, target_seq_ids, primer_number=None):
    """
    Extract sequences from FASTA file that match target sequence IDs and optionally primer.

    Parameters:
        fasta_file (str): Path to FASTA file
        target_seq_ids (set): Set of sequence IDs from cluster
        primer_number (str): Optional primer to filter by (e.g., 'PR0001')

    Returns:
        dict: Dictionary of extracted sequences
    """
    print(f"Extracting sequences from {fasta_file}...")
    if primer_number:
        print(f"Filtering by primer: {primer_number}")

    sequences = {}
    current_id = None
    current_seq = []
    total_in_cluster = 0
    filtered_by_primer = 0

    with open(fasta_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                # Save the previous sequence
                if current_id and current_id in sequences:
                    sequences[current_id]["seq"] = ''.join(current_seq)

                # Parse the header: >HPPPE1777-13|PR0008|TX36848
                full_header = line
                # print('full_header:', full_header)
                header_parts = line[1:].split('|')

                if len(header_parts) >= 2:
                    seq_id = header_parts[0]     # HPPPE1777-13
                    # print('seq_id:', seq_id)
                    primer = header_parts[1]     # PR0008
                    # print('primer:', primer)
                else:
                    seq_id = header_parts[0] if header_parts else line[1:]
                    primer = None

                current_id = None
                current_seq = []

                # Check if this sequence is in our target cluster
                if seq_id in target_seq_ids:
                    total_in_cluster += 1

                    # If primer filtering is requested, check primer match
                    if primer_number is None or primer == primer_number:
                        current_id = seq_id
                        sequences[current_id] = {"header": full_header, "seq": ""}
                        filtered_by_primer += 1

            elif current_id:
                current_seq.append(line)

        # Save last sequence
        if current_id and current_id in sequences:
            sequences[current_id]["seq"] = ''.join(current_seq)

    print(f"Found {total_in_cluster} sequences in cluster")
    if primer_number:
        print(f"After primer filtering ({primer_number}): {filtered_by_primer} sequences")
    else:
        print(f"No primer filtering applied: {len(sequences)} sequences extracted")

    return sequences

def write_fasta_output(sequences, output_file):
    """
    Write extracted sequences to a new FASTA file.

    Parameters:
        sequences (dict): Dictionary of sequences
        output_file (str): Path to output FASTA file
    """
    with open(output_file, 'w') as f:
        for seq_id, data in sequences.items():
            header = data['header']
            seq_id = header.split('|')[0][1:]
            tx_id = header.split('|')[2] if len(header.split('|')) > 2 else 'ERROR'
            new_header = f">{seq_id}|{tx_id}"
            f.write(f"{new_header}\n")
            f.write(f"{data['seq']}\n")

    print(f"Wrote {len(sequences)} sequences to {output_file}")

def extract_cluster_sequences(cluster_file, fasta_file, cluster_number, primer_number=None, output_file=None):
    """
    Convenience function to extract cluster sequences.

    Parameters:
        cluster_file (str): Path to clustering file
        fasta_file (str): Path to FASTA file
        cluster_number (int): Cluster number to extract
        primer_number (str): Optional primer to filter by (e.g., 'PR0001')
        output_file (str): Path to output FASTA file

    Returns:
        int: Number of sequences extracted
    """
    target_seq_ids = parse_cluster_file(cluster_file, cluster_number)
    if not target_seq_ids:
        print(f"No sequences found in cluster {cluster_number}")
        return 0

    sequences = extract_sequences_from_fasta(fasta_file, target_seq_ids, primer_number)

    if sequences and output_file:
        write_fasta_output(sequences, output_file)

    return len(sequences)

if __name__ == "__main__":
    cluster_file = 'cdhit-mico-90_102440.clstr'
    fasta_file = 'total_input-ID.fasta'
    primer_number = 'PR0001'
    cluster_number = 418
    output_file = 'mico_90pcnt_lrg_mix.fasta'
    extract_cluster_sequences(cluster_file, fasta_file, cluster_number, primer_number, output_file)