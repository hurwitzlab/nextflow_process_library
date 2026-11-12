---
name: nf-test-writer
description: Write nf-test tests and test data for a process in this nextflow_process_library repo, run them on Hazel with run_tests.sh --stale, and commit-ready pass records. Use whenever the user asks to add, write, fix or extend tests for a module or process (e.g. "test coverm", "add tests for mmseqs2", "this process has no tests"), to make a test fixture or test data for a process, to snapshot a process's output, or to work out why an nf-test fails — even if they don't say "nf-test".
---

# Writing nf-tests for a process

This repo is a shared library of Nextflow processes (`modules/<tool>/<tool>.nf`), tested with
nf-test on the NC State Hazel cluster against the BRC container images. A test proves a process
runs in its image and produces the right output; the pass record it leaves is what lets CI
(`No stale tests`) allow a merge to `main`. Your job: get a process from "untested" to "tested,
passing, recorded", without changing the process itself unless the user says so.

Read these first — they hold conventions this skill doesn't repeat:
- `modules/CLAUDE.md` — how processes are written (sampleid/pooledid tuples, `shell:` + `!{}`, labels)
- `tests/data/README.md` — the shared fixtures and exactly what's in them
- `README.md`, section **Testing** — run_tests.sh modes, pass records, the CI check
- [references/patterns.md](references/patterns.md) — copyable test code for each situation below

## 1. Understand the process before writing anything

Read the process block and note:
- **Inputs and outputs.** Every `input:` element becomes `input[N]`; every `emit:` is a channel in
  `process.out.<name>`. Note which tuples carry `sampleid` (per-sample) or `pooledid` (one output
  for all samples).
- **Every `params.*` it uses.** `tests/nextflow.config` defines none of the tool options, so the
  test must set each one in a `params { }` block, with a realistic value.
- **The container.** `container "${params.container__<tool>}"` must have a line in
  `conf/containers_hazel.config`; if not, the process can't be tested yet — tell the user.
- **What it needs that the shared data can't give:** a database (absolute path on Hazel, tag
  `needs_db`), long contigs, real marker genes, more than 12 GB of memory, GPU, internet. The test
  job has 4 CPUs, 12 GB, no internet, and a 15-minute cap per task.
- **`errorStrategy 'ignore'`** hides failures — assert the outputs exist, not just `process.success`.

If another test in the same module exists, read it and match its style.

## 2. Choose the input data

Prefer the shared "mini world" in `tests/data/` (phiX174 genome, contigs, reads, BAMs, VCFs,
proteins, a tiny kraken2 db). Its README says exactly what each file contains — e.g. the
paired reads align as 420 records, 20 unmapped — and those known facts make the best assertions.

When nothing shared fits, make a **module-specific fixture** in `modules/<tool>/tests/testdata/`:
- Keep it tiny (KB, not MB) and derive it from the shared data where you can (e.g. phiX174 with
  three planted SNVs), so expected results are known exactly.
- Make it reproducible: commit a small generator script next to it (seeded random, gzip with
  `mtime=0`), or put the exact commands in a comment in the test. If building it needs a tool,
  run that tool from the BRC image (`apptainer exec <image from conf/containers_hazel.config> ...`)
  inside an `srun` job, not on a login node.
- Reference it as `file("${moduleDir}/tests/testdata/<name>")`, and shared data as
  `file("${baseDir}/tests/data/<name>")`. Use those two forms only: they are how the test ledger
  finds a test's fixtures, so a fixture reached any other way won't make the test stale when it
  changes.

**Ask before adding to or regenerating anything in `tests/data/`.** Every test shares it, so a
change there can alter other tests' outputs and makes all their pass records stale.

## 3. Write the test

One file per process: `modules/<tool>/tests/<process>.nf.test`, with
`script "../<tool>.nf"`, `process "<process>"`, and `tag "<tool>"` + `tag "<process>"`.
Name test samples `test_<process>` (or `test_<process>_<variant>`). Each `test("...")` name says
what it proves, e.g. `"Sorts and indexes an unsorted SAM (bwa mem read order)"`.

Assert, in roughly this order:
1. `process.success` (or `process.failed` for a failure test).
2. **The shape of each emitted tuple** — `assert process.out.x[0].size() == 3` before
   `def (id, a, b) = process.out.x[0]`. Groovy's multiple assignment silently drops extra values
   and fills missing ones with `null`, so without this a changed output shape goes unnoticed.
3. The `sampleid`/`pooledid` passes through unchanged, and output file names are as declared.
4. **Content you can predict** from the fixture: record counts, which reads map, which contigs
   are classified, which SNVs are found. These are the assertions that catch wrong science.
5. A `snapshot(...)` of output that's too long to assert by hand.

Snapshots must not change between tool versions, because `run_tests.sh --all-versions` checks
every image version against the same snapshot. Snapshot core content only — SAM fields 1–11 rather
than whole BAMs (samtools adds `@PG` lines), hit rows rather than report headers (dates, paths,
versions), the plain-text parts of an index. If a value differs between runs (timestamps, random
padding, thread order), leave it out of the snapshot and assert something stable about it instead.

Add a **failure test** when the process has a known way to fail on bad input (unsorted BAM,
missing index): assert `process.failed` and that `process.errorReport` contains the real cause.

## 4. Run it on Hazel

From the repo root (never run tests directly on a login node):

```bash
sbatch tests/run_tests.sh --stale modules/<tool>
squeue -u $USER                                   # wait for it to finish
sed 's/\x1b\[[0-9;]*m//g' test_logs/nf-test_<jobid>.out | less   # strip colours
```

`--stale` runs only tests without a current pass record, one file at a time, and writes
`<process>.nf.test.pass` for each that passes. A new test writes its `.snap` on the first run —
open it and check it holds what you meant to snapshot, with no paths, dates or versions. For a new
snapshot, run once more with `sbatch tests/run_tests.sh --stale --force modules/<tool>/tests/<process>.nf.test`
to confirm it's stable. If a test fails, the log names its work directory; `.command.sh`,
`.command.err` and `.command.log` there show exactly what ran and why it died.

## 5. Triage failures: is it the test or the process?

**Problems in the test** — wrong input shape, a params value missing, a wrong assumption about the
output: fix them and rerun.

**Problems in the process** — wrong flags, a binary missing from the image, wrong output
declarations, a command that can't work, wrong results: **stop, don't edit the process.** The
user reviews module changes before they're made. Report:
- the failing command and its error (from `.command.sh` / `.command.err`),
- the relevant lines of the process,
- the likely cause and a proposed fix as a diff,
- what the test currently does about it.

Then let the user choose: fix the module now (its own change), or keep the test passing on what
works today with a `// TODO(module bug): <what's wrong>` comment where an assertion is held back.
Don't assert wrong behaviour as if it were correct.

## 6. Finish

- `python3 tests/test_ledger.py status --why modules/<tool>` should show every test `ok`.
- The change is: the `.nf.test` file(s), their `.nf.test.snap`, their `.nf.test.pass` records, and
  any `testdata/` fixtures (plus generator). Pass records must be committed with the change, or
  the `No stale tests` check will fail the PR.
- Don't commit, push or open a PR unless the user asks; list the files and the job ID instead.
- Summarise for the user: what each test proves, the fixtures used or created and why, the job
  result, and any module problems found (with the report from step 5).
