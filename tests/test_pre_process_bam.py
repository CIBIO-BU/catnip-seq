from src.pre_process_bam import *

def test_process_bam_empty_df():
    self_aligment_only = "tests/self-alignment-only.bam"
    mapping_file = "tests/test_mapping_file.tsv"
    columns = [0,1]
    cat_thresholds = [10]

    empty_df = process_bam(self_aligment_only, cat_thresholds, mapping_file, columns)

    assert isinstance(empty_df, pd.DataFrame)
    assert empty_df.empty






