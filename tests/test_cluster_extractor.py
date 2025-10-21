from src.cluster_extractor import *

def test_cluster_extractor():
    cluster_file = "tests/test_cluster_file.clstr"
    fasta_file = "tests/origin_fasta.fasta"
    cluster_number = 2
    output_file = Path("tests/test.fasta")
    nseqs_expected = 4
    expected_cluster_file = Path("tests/cluster2.fasta")

    nseqs = extract_cluster_sequences(cluster_file=cluster_file, fasta_file=fasta_file, cluster_number=cluster_number, output_file=output_file)

    assert nseqs_expected == nseqs, f"Expected {nseqs_expected}, but got {nseqs}"

    try:
        assert expected_cluster_file.read_text() == output_file.read_text()
    finally:
        output_file.unlink(missing_ok=True)



