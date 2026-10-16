#!/bin/bash
#SBATCH --partition=xfer
#SBATCH --qos=xfer
#SBATCH --job-name=nf-test
#SBATCH --output=test_logs/%x_%j.out
#SBATCH --err=test_logs/%x_%j.err
#SBATCH --mem=12G
#SBATCH --time=01:00:00

# run_tests.sh -- load the environment then run nf-test with arguments passed through.
#
#   sbatch run_tests.sh [nf-test args]                 tests use each tool's default container
#                                                       (conf/containers_hazel.config)
#   sbatch run_tests.sh --all-versions [nf-test args]  every module that has tests is run once per
#                                                       image version in conf/container_catalog.tsv;
#                                                       all versions must match the same snapshot

set -euo pipefail

ALL_VERSIONS=false
if [[ "${1:-}" == "--all-versions" ]]; then
    ALL_VERSIONS=true
    shift
fi

# --- Environment --- (Comment out if not on hazel)
module use /usr/local/usrapps/brc/brc_modules/modules
module load nextflow/26.04.3
module load nf-test/0.9.5

# --- Run test(s) ---
# Run from the repo root, where nf-test.config lives. Under sbatch, $0 points at a copy of this
# script in Slurm's spool dir, so resolve the repo from the submit dir instead.
REPO="$(git -C "${SLURM_SUBMIT_DIR:-$(dirname "$0")}" rev-parse --show-toplevel)"
cd "$REPO"

# Give this run its own workDir so concurrent runs don't share (or delete) each other's work dirs.
# nf-test has no workDir flag, so write a per-run copy of nf-test.config and pass it with -c.
RUN_ID="${SLURM_JOB_ID:-local_$$}"
WORK_DIR=".nf-test/run_${RUN_ID}"
RUN_CONFIG=".nf-test.${RUN_ID}.config"
trap 'rm -f .nf-test.${RUN_ID}.*config' EXIT
sed -E "s|^([[:space:]]*workDir[[:space:]]+).*|\1\"${WORK_DIR}\"|" nf-test.config > "$RUN_CONFIG"
grep -q "workDir \"${WORK_DIR}\"" "$RUN_CONFIG" || { echo "ERROR: could not set workDir in $RUN_CONFIG" >&2; exit 1; }

if ! $ALL_VERSIONS; then
    nf-test test -c "$RUN_CONFIG" "$@"
else
    for arg in "$@"; do
        [[ "$arg" == --update-snapshot || "$arg" == --updateSnapshot ]] && {
            echo "ERROR: --all-versions can't update snapshots; update them with a default run first" >&2; exit 1; }
    done

    CATALOG="conf/container_catalog.tsv"
    [[ -f "$CATALOG" ]] || { echo "ERROR: $CATALOG not found (run conf/make_containers.py)" >&2; exit 1; }

    failed=()
    n=0
    # Each module directory that has tests: modules/<tool>/tests/*.nf.test
    for module_dir in $(find modules -path '*/tests/*.nf.test' | xargs -n1 dirname | xargs -n1 dirname | sort -u); do
        for param in $(grep -ohE 'params\.container__\w+' "$module_dir"/*.nf | sed 's/params\.container__//' | sort -u); do
            # catalog columns: param version default local_image public_uri note
            while IFS=$'\t' read -r version image; do
                n=$((n + 1))
                # Per-version nextflow config: the test config, then this version's image on top
                VERSION_CONFIG="${REPO}/.nf-test.${RUN_ID}.${n}.nextflow.config"
                printf "includeConfig '%s/tests/nextflow.config'\nparams.container__%s = '%s'\n" \
                    "$REPO" "$param" "$image" > "$VERSION_CONFIG"
                sed -E "s|^([[:space:]]*configFile[[:space:]]+).*|\1\"${VERSION_CONFIG}\"|" "$RUN_CONFIG" \
                    > ".nf-test.${RUN_ID}.${n}.config"

                echo "=== ${module_dir} | container__${param} = ${version} (${image##*/})"
                # --ci: fail on a missing snapshot instead of writing one
                if nf-test test --ci -c ".nf-test.${RUN_ID}.${n}.config" "$@" "$module_dir"; then
                    echo "=== PASS: ${param} ${version}"
                else
                    echo "=== FAIL: ${param} ${version}"
                    failed+=("${param} ${version}")
                fi
            done < <(awk -F'\t' -v p="$param" 'NR > 1 && $1 == p && $4 != "" {print $2 "\t" $4}' "$CATALOG")
        done
    done

    echo "run_tests.sh: ${n} module/version combinations run, ${#failed[@]} failed"
    if (( ${#failed[@]} )); then
        printf '  FAILED: %s\n' "${failed[@]}"
        exit 1
    fi
fi

# --- Cleanup --- (only reached if all tests passed, thanks to set -e)
# Remove only this run's work dir; failed runs keep theirs for debugging.
rm -rf "$WORK_DIR"

# --- Exit ---
echo run_tests.sh: All tests passed
