#!/bin/bash
#SBATCH --partition=compute_partners
#SBATCH --qos=p_brc
#SBATCH --job-name=nf-test
#SBATCH --output=test_logs/%x_%j.out
#SBATCH --err=test_logs/%x_%j.err
#SBATCH --cpus-per-task=4   # = process_high in tests/nextflow.config; Nextflow won't start a task needing more CPUs than the job has
#SBATCH --mem=12G
#SBATCH --time=03:00:00

# run_tests.sh -- load the environment then run nf-test with arguments passed through.
#
#   sbatch run_tests.sh [nf-test args]                 tests use each tool's default container
#                                                       (conf/containers_hazel.config)
#   sbatch run_tests.sh --all-versions [nf-test args]  every module that has tests is run once per
#                                                       image version in conf/container_catalog.tsv;
#                                                       all versions must match the same snapshot
#   sbatch run_tests.sh --stale [--force] [PATH ...] [nf-test flags]
#                                                       run only tests whose code, snapshot, fixtures,
#                                                       container or config changed since they last
#                                                       passed (tests/test_ledger.py), one test file at
#                                                       a time, and write a <test>.nf.test.pass record
#                                                       for each that passes; commit those records.
#                                                       --force reruns (and re-records) every test in
#                                                       PATH. PATH: test files or dirs (default: all)
#
# Runs on compute nodes, which have no internet. The only download the suite needs is the nf-test
# plugins in nf-test.config, cached under .nf-test/plugins/ after the first run; on a fresh clone,
# run once on xfer to fetch them:
#   sbatch --partition=xfer --qos=xfer run_tests.sh [nf-test args]

set -euo pipefail

MODE=default
case "${1:-}" in
    --all-versions) MODE=all_versions; shift ;;
    --stale)        MODE=stale; shift ;;
esac
FORCE=false
if [[ $MODE == stale && "${1:-}" == --force ]]; then
    FORCE=true
    shift
fi
for arg in "$@"; do
    [[ "$arg" == --all-versions || "$arg" == --stale ]] && {
        echo "ERROR: $arg must be the first argument, and --all-versions and --stale can't be combined" >&2; exit 1; }
done

SUBMIT_DIR="$PWD"   # under sbatch, the directory the job was submitted from

# --- Environment --- (Comment out if not on hazel)
module use /usr/local/usrapps/brc/brc_modules/modules
module load nextflow/26.04.3
module load nf-test/0.9.5
module load apptainer   # processes run in their containers; don't rely on the submitting shell's PATH
# Nextflow checks online for a newer release at startup; with no internet on compute nodes that
# check hangs ~280 s per test before timing out
export NXF_DISABLE_CHECK_LATEST=true

# --- Run test(s) ---
# Run from the repo root, where nf-test.config lives. Under sbatch, $0 points at a copy of this
# script in Slurm's spool dir, so resolve the repo from the submit dir instead.
REPO="$(git -C "${SLURM_SUBMIT_DIR:-$(dirname "$0")}" rev-parse --show-toplevel)"
cd "$REPO"

# --stale: split arguments into test paths and nf-test flags. Like nf-test's own path arguments, a
# path may be relative to the repo root; one relative to the submit dir is accepted too.
STALE_PATHS=() NFTEST_FLAGS=()
if [[ $MODE == stale ]]; then
    for arg in "$@"; do
        if [[ -e "$arg" ]]; then STALE_PATHS+=("$(realpath "$arg")")
        elif [[ -e "$SUBMIT_DIR/$arg" ]]; then STALE_PATHS+=("$(realpath "$SUBMIT_DIR/$arg")")
        else NFTEST_FLAGS+=("$arg"); fi
    done
fi

# nf-test downloads the plugins listed in nf-test.config on first use. Compute nodes can't, so fail
# early with instructions unless they're cached (no internet check needed on xfer or a login node).
if [[ -n "${SLURM_JOB_ID:-}" && "${SLURM_JOB_PARTITION:-}" != xfer ]]; then
    for plugin in $(grep -oE 'load[[:space:]]+"[^"]+@[^"]+"' nf-test.config | grep -oE '"[^"]+"' | tr -d '"'); do
        name="${plugin%@*}" version="${plugin#*@}"
        [[ -f ".nf-test/plugins/${name}/${version}/${name}-${version}.jar" ]] || {
            echo "ERROR: nf-test plugin ${plugin} is not cached in .nf-test/plugins/ and this node has no internet." >&2
            echo "       Run once on the xfer partition to download it, e.g.:" >&2
            echo "         sbatch --partition=xfer --qos=xfer tests/run_tests.sh $*" >&2
            exit 1
        }
    done
fi

# Give this run its own workDir so concurrent runs don't share (or delete) each other's work dirs.
# nf-test has no workDir flag, so write a per-run copy of nf-test.config and pass it with -c.
RUN_ID="${SLURM_JOB_ID:-local_$$}"
WORK_DIR=".nf-test/run_${RUN_ID}"
RUN_CONFIG=".nf-test.${RUN_ID}.config"
trap 'rm -f .nf-test.${RUN_ID}.*config' EXIT
sed -E "s|^([[:space:]]*workDir[[:space:]]+).*|\1\"${WORK_DIR}\"|" nf-test.config > "$RUN_CONFIG"
grep -q "workDir \"${WORK_DIR}\"" "$RUN_CONFIG" || { echo "ERROR: could not set workDir in $RUN_CONFIG" >&2; exit 1; }

if [[ $MODE == default ]]; then
    nf-test test -c "$RUN_CONFIG" "$@"
elif [[ $MODE == stale ]]; then
    LEDGER=(python3 tests/test_ledger.py)
    if $FORCE; then
        mapfile -t tests < <("${LEDGER[@]}" stale --all "${STALE_PATHS[@]}")
    else
        "${LEDGER[@]}" status --why "${STALE_PATHS[@]}" | grep -v '^ok ' || true
        mapfile -t tests < <("${LEDGER[@]}" stale "${STALE_PATHS[@]}")
    fi
    echo "run_tests.sh: ${#tests[@]} test file(s) to run"

    # One nf-test call per file, so each file's pass/fail is known and only passes are recorded
    failed=()
    for t in "${tests[@]}"; do
        echo "=== ${t}"
        if nf-test test -c "$RUN_CONFIG" "${NFTEST_FLAGS[@]}" "$t"; then
            "${LEDGER[@]}" record "$t"
        else
            echo "=== FAIL: ${t}"
            failed+=("$t")
        fi
    done

    echo "run_tests.sh: ${#tests[@]} test file(s) run, ${#failed[@]} failed"
    if (( ${#failed[@]} )); then
        printf '  FAILED: %s\n' "${failed[@]}"
        exit 1
    fi
    echo "run_tests.sh: commit the updated *.nf.test.pass records with your change"
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
