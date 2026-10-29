# 2026-10-29
Author: sweavs111

- Worked through the 7 failures from full-suite job 1585399 (45/52 passing) on `test_suite`.
  Full suite job 1600387 now passes 52/52 in ~4 min, down from ~20 min, with no snapshot changes.
- Module bugs:
  - bbmerge: bbtools 39.84 fails an internal `assert ffout1.ordered()` (`WriterFactory.java:140`,
    read from the bytecode) whenever `outu1=` and `outu2=` are both set, then the JVM hangs until
    the 15-min task cap. `ordered=t` satisfies it on every version, keeps unmerged mates in sync,
    and showed no measurable cost on 1M pairs (identical output).
  - cutadapt: `echo`'s trailing newline lands in the last awk field (`RS=","`), splitting the
    `$` anchor onto its own line. The `paste -sd ""` workaround fails in the image's busybox.
    `printf '%s'` avoids the newline on any base image.
  - kraken2 `kreport_to_json`: Groovy turns `\n` inside a `shell: '''` block into a real
    newline, so python saw an unterminated string. Now `print(..., file=)`. Same trap: never
    write `'''` inside a shell block, even in a comment; my first fix did and broke parsing.
- Broken images, replaced via `run_nf_cm.sh` and removed from Hazel along with their modulefiles:
  - bbtools 39.84 → 40.01. 40.x also fixes TLEN (it stopped counting soft-clipped bases for mates
    off a contig end, per the SAM spec). bbwrap's snapshot now leaves TLEN out.
  - hmmer 3.1b2 (Debian 9, no `ps`, which Nextflow's task tracing needs) → 3.4. The hmmer
    snapshots had been recorded on 10-19 against a temporary scratchpad 3.4 image, which is why
    they could never pass on Hazel's image; they match 3.4 as is.
  - salmon 1.11.4 → 1.10.3. The 1.11.4 binary requests `en_US.UTF-8` by name, but its image
    only has `C.utf8`. It fails even with `LC_ALL=C`, and works once the host's `en_US.utf8` is
    bound in. salmon 2.x (Rust rewrite) was tested and rejected for now: it removes
    `--minAssignedFrags`, and on the test reads maps 146 vs 119 fragments with very different
    TPMs. Worth evaluating on real data before adopting.
- `run_tests.sh`: on nodes without internet, Nextflow's new-version check hangs ~280 s per test,
  so it now sets `NXF_DISABLE_CHECK_LATEST=true` and defaults to `compute_partners`/`p_brc`
  instead of the single shared xfer node. It stops early with xfer instructions if the nft-bam
  plugin isn't cached. This also affects any Nextflow pipeline launched on Hazel compute nodes.
- Also fixed: `make_containers.py` treated a version starting with `v` as the newest (that kept
  hmmer on 3.1b2). jackhmmer_dir wrote its HMMs outside `hmms/` (the tarball was always empty),
  and `-o` overwrote the log on every loop.
- Still open, to fix in their own PR (not test_suite). Each has a `TODO(module bug)` in its test:
  - minimap2 `ont_read_accuracy` reports ~0.47 identity for ~91% reads: no `-c`, the `ava-ont`
    overlap preset instead of `map-ont`, and secondary alignments counted as reads.
  - `bwa_index` never emits the index files, so `bwa_index → bwa_mem` can't work.
  - samtools `to_bam` indexes without sorting, so it fails on unsorted input.
  - Separately, `run_tests.sh --all-versions` ignores the module paths you pass it.
- Next: get the test_suite PR reviewed and merged.
