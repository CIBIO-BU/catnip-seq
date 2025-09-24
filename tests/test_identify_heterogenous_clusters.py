import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from identify_heterogenous_clusters import list_heterogenous_clusters

def test_list_heterogenous_clusters():
    cluster_file = "test_cluster_file.clstr"
    mapping_file = "test_mapping_file.tsv"
    expected = {2}

    result = set(list_heterogenous_clusters(cluster_file, mapping_file  ))

    assert result == expected, f"Expected {expected}, but got {result}"