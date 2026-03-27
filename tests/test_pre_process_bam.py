from src.catnip.pre_process_bam import *
import pandas.testing as pdt
from pathlib import Path

def test_process_bam_empty_df():
    self_aligment_only = "tests/test_files/self-alignment-only.bam"
    mapping_file = "tests/test_files/test_mapping_file.tsv"
    columns = [0,1]

    empty_df = process_bam(self_aligment_only, mapping_file, columns)

    assert isinstance(empty_df, pd.DataFrame)
    assert empty_df.empty

def test_process_bam():
    aligment= "tests/test_files/test_align.bam"
    mapping_file = "tests/test_files/test_mapping_file.tsv"
    columns = [0,1,2,3]
    expected_df = pd.read_csv("tests/test_files/test_align_intraclst_mins.tsv", sep='\t', index_col=False, header=0)

    df = process_bam(aligment, mapping_file, columns, save_processed=True)
    df['query_cat'] = df['query_cat'].apply(str)
    df['target_cat'] = df['target_cat'].apply(str)

    pdt.assert_frame_equal(df, expected_df, check_dtype=False)

    try:
        pdt.assert_frame_equal(df, expected_df, check_dtype=False)

    finally:
        df_path=Path("test_align_intraclst_mins.tsv")
        df_path.unlink(missing_ok=True)










