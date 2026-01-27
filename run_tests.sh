#!/usr/bin/env bash

TESTS_OK=0
TESTS_FAILED=0
set -e -o pipefail


# TEST 1
catnip -i test-workflow/coi_micointf_mil.fasta -f test-workflow/coi_micointf_mil_mapping.tsv -c 0,1,2,3 -p 10

# TODO: check if output is ok

TESTS_OK=1
#

echo "Tests OK: $TESTS_OK"
echo "Tests FAILED: $TESTS_FAILED"
exit $TESTS_FAILED
