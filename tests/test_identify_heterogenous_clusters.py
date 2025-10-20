from src.identify_heterogenous_clusters import list_heterogenous_clusters

def test_list_heterogenous_clusters():
    cluster_file = "tests/test_cluster_file.clstr"
    mapping_file = "tests/test_mapping_file.tsv"
    columns = [0,1]
    expected = ['2']

    result = list_heterogenous_clusters(cluster_file, mapping_file, columns)

    assert result == expected, f"Expected {expected}, but got {result}"