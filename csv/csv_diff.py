#/usr/bin/env python

import sys, argparse, pandas as pd

def main(argv):
    parser = argparse.ArgumentParser(
        description="CSV File Compare",
        epilog="""Pass two CSV files as arguments, compare the files and output to a new file.""",
    )
    parser.add_argument(
        "-f",
        "--main-file",
        required=True,
        metavar="main_file",
        help="File to compare to",
    )
    parser.add_argument(
        "-d",
        "--diff-file",
        required=True,
	metavar="diff_file",
        help="File to compare with",
    )

    try:
        args = parser.parse_args()
    except:
        sys.exit(1)

    csvf1 = pd.read_csv(args.main_file)
    csvf2 = pd.read_csv(args.diff_file)

    csvf1['flag'] = 'main'
    csvf2['flag'] = 'diff'

    csvf = pd.concat([csvf1, csvf2])

    dups_dropped = csvf.drop_duplicates(csvf.columns.difference(['flag']), keep=False)
    dups_dropped.to_csv('output_file.csv', index=False)
    return

if __name__ == "__main__":
    main(sys.argv)
