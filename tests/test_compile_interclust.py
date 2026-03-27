from src.catnip.compile_interclust import *
import pandas.testing as pdt

def test_compile_interclust():
    test_dir = "tests/"
    test_df = pd.read_csv("tests/test_files/test_interclst.tsv", sep='\t', index_col=False, header=0)


    df = compile_interclust(test_dir)

    try:
        pdt.assert_frame_equal(test_df, df, check_dtype=False)

    finally:
        df_path=Path("final_output_interclst.tsv")
        df_path.unlink(missing_ok=True)