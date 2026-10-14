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

# Give this run its own workDir so concurrent runs don't share (or delete) each other's work dirs.
# nf-test has no workDir flag, so write a per-run copy of nf-test.config and pass it with -c.
RUN_ID="${SLURM_JOB_ID:-local_$$}"
WORK_DIR=".nf-test/run_${RUN_ID}"
RUN_CONFIG=".nf-test.${RUN_ID}.config"
trap 'rm -f "$RUN_CONFIG"' EXIT
sed -E "s|^([[:space:]]*workDir[[:space:]]+).*|\1\"${WORK_DIR}\"|" nf-test.config > "$RUN_CONFIG"
grep -q "workDir \"${WORK_DIR}\"" "$RUN_CONFIG" || { echo "ERROR: could not set workDir in $RUN_CONFIG" >&2; exit 1; }

nf-test test -c "$RUN_CONFIG" "$@"

# --- Cleanup --- (only reached if all tests passed, thanks to set -e)
# Remove only this run's work dir; failed runs keep theirs for debugging.
rm -rf "$WORK_DIR"

# --- Exit ---
echo run_tests.sh: All tests submitted
