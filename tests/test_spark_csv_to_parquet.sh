#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-11-05 23:29:15 +0000 (Thu, 05 Nov 2015)
#
#  https://github.com/harisekhon/pytools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  http://www.linkedin.com/in/harisekhon
#

set -eu
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "
# ===================== #
# Spark CSV => Parquet
# ===================== #
"

cd "$srcdir/..";

. ./tests/utils.sh

cd "$srcdir"

for SPARK_VERSION in 1.3.1 1.4.0; do
    dir="spark-$SPARK_VERSION-bin-hadoop2.6"
    tar="$dir.tgz"
    if ! [ -d "$dir" ]; then
        if ! [ -f "$tar" ]; then
            echo "fetching $tar"
            # some systems don't have wget
            if which wget &>/dev/null; then
                wget "http://d3kbcqa49mib13.cloudfront.net/$tar"
            else
                curl -L "http://d3kbcqa49mib13.cloudfront.net/$tar" > "$tar"
            fi
        fi
        echo "untarring $tar"
        tar zxf "$tar" || rm -f "$tar" "$dir"
    fi
    echo
    export SPARK_HOME="$dir"
    # this works for both Spark 1.3.1 and 1.4.0 but calling from within spark_csv_to_parquet.py doesn't like it
    #spark-submit --packages com.databricks:spark-csv_2.10:1.3.0 ../spark_csv_to_parquet.py -c data/test.csv -p "test-$dir.parquet" --has-header $@ &&
    # resolved, was due to Spark 1.4+ requiring pyspark-shell for PYSPARK_SUBMIT_ARGS

    rm -fr "test-header-$dir.parquet"
    ../spark_csv_to_parquet.py -c data/test_header.csv --has-header -p "test-header-$dir.parquet" $@ &&
        echo "SUCCEEDED with header with Spark $SPARK_VERSION" ||
        { echo "FAILED with header with Spark $SPARK_VERSION"; exit 1; }

    rm -fr "test-header-schemaoverride-$dir.parquet"
    ../spark_csv_to_parquet.py -c data/test_header.csv -p "test-header-schemaoverride-$dir.parquet" --has-header -s Year:String,Make,Model,Length:float $@ &&
        echo "SUCCEEDED with header and schema override with Spark $SPARK_VERSION" ||
        { echo "FAILED with header and schema override with Spark $SPARK_VERSION"; exit 1; }

    rm -fr "test-noheader-$dir.parquet"
    ../spark_csv_to_parquet.py -c data/test.csv -s Year:String,Make,Model,Length -p "test-noheader-$dir.parquet" $@ &&
        echo "SUCCEEDED with no header with Spark $SPARK_VERSION" ||
        { echo "FAILED with no header with Spark $SPARK_VERSION"; exit 1; }

    rm -fr "test-noheader-types-$dir.parquet"
    ../spark_csv_to_parquet.py -c data/test.csv -s Year:String,Make,Model,Length:float -p "test-noheader-types-$dir.parquet" $@ &&
        echo "SUCCEEDED with no header and float type with Spark $SPARK_VERSION" ||
        { echo "FAILED with no header and float type with Spark $SPARK_VERSION"; exit 1; }

#    if [ "$(cksum < "test-header-$dir.parquet/part-r-00001.parquet")" = "$(cksum < "test-noheader-$dir.parquet/part-r-00001.parquet")" ]; then
#        echo "SUCCESSFULLY compared noheader with explicit schema and mixed implicit/explicit string types to headered csv parquet output"
#    else
#        echo "FAILED comparison of noheader vs header parquet generated files"
#        exit 1
#    fi

done
echo "SUCCESS"
