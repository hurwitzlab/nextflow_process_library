#!/bin/bash
#SBATCH --partition=xfer
#SBATCH --qos=xfer
#SBATCH --job-name=nf-test
#SBATCH --output=test_logs/%x_%j.out
#SBATCH --err=test_logs/%x_%j.err
#SBATCH --mem=12G
#SBATCH --time=01:00:00

#run_tests.sh -- load the environment then run nf-test with arguments passed through.

set -euo pipefail

# --- Environment --- (Comment out if not on hazel)
module use /usr/local/usrapps/brc/brc_modules/modules
module load nextflow/26.04.3
module load nf-test/0.9.5

# --- Run test(s) ---
# Run from the repo root, where nf-test.config lives. Under sbatch, $0 points at a copy of this
# script in Slurm's spool dir, so resolve the repo from the submit dir instead.
cd "$(git -C "${SLURM_SUBMIT_DIR:-$(dirname "$0")}" rev-parse --show-toplevel)"
nf-test test "$@"

# --- Exit ---
echo run_tests.sh: All tests submitted
