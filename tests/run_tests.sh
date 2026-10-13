#!/bin/bash
#run_tests.sh -- load the environment then run nf-test with arguments passed through.

set -euo pipefail

# --- Environment --- (Comment out if not on hazel)
module use /usr/local/usrapps/brc/brc_modules/modules
module load nextflow/26.04.3
module load nf-test/0.9.5

# --- Run test(s) ---
cd "$(dirname "$0")"            # run from the repo root, where nf-test.config lives
nf-test test "$@"

# --- Exit ---
echo run_tests.sh: All tests submitted