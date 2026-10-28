# 2026-10-22
Author: Mery Touceda-Suárez

- New `modules/metapop/metapop.nf`, ported from a SLURM job that ran MetaPop
  (preprocessing + microdiversity) on vOTUs. Three processes:
  `metapop_preprocess` (`--preprocess_only`), `metapop_micro` (`--no_macro`,
  same as the SLURM job) and `metapop_micro_macro` (full run). Each runs once
  across all sample BAMs (collected list, like `coverm`) and runs
  `samtools quickcheck` first, so a truncated BAM from a failed mapping job
  fails the task early.
- Checked MetaPop's source (metaGmetapop/metapop) rather than the README:
  `--input_samples` and `--reference` are both read as directories
  (`os.listdir`); every file in the reference dir except `.fai`/`.R` is
  read as FASTA. Both inputs are staged into their own dirs
  (`stageAs: "input_bams/*"`, `"reference/*"`). Outputs land in
  `<output>/MetaPop/NN.*`; emits point at `02.Filtered_Samples`,
  `03.Breadth_and_Depth`, `10.Microdiversity`, `11.Macrodiversity` and the
  whole `MetaPop/` dir. `--norm` isn't passed: MetaPop builds its own
  normalization file from per-sample read counts.
- Passes `nextflow lint` (26.04.0). A local test run staged inputs and built
  the command correctly, then stopped at `samtools: command not found` (no
  samtools/MetaPop on the Mac), so MetaPop itself is untested — first real
  run should be on the HPC.
- **Doc fix — publishDir exception in `modules/CLAUDE.md` was wrong.** The
  prescribed form for processes with no `sampleid`
  (`publishDir { params.X instanceof Closure ? params.X(sampleid) : params.X }`)
  fails to compile under the strict parser: `` `sampleid` is not defined ``,
  even though `sampleid` only sits inside the Closure branch. The cited worked
  examples (`bbstats`, `checkv_end_to_end`, `megahit_paired_end`) all have
  `sampleid` and use the label form, so none of them actually exercised the
  exception. Rewrote the section to prescribe a plain
  `publishDir "${params.<tool>_outdir}", mode: 'copy'` (what
  `coverm`/`bakta`/`bcftools`/`blast` already did), with
  per-process `<process>_outdir` params when several such processes share a
  file; updated checklist item 1 to match. `metapop` uses
  `metapop_{preprocess,micro,micro_macro}_outdir` for this reason.
- Params a pipeline needs for metapop: `container__metapop` (image must also
  have samtools), `metapop_id_min`, `metapop_min_len`, `metapop_min_cov`,
  `metapop_min_dep`, the three outdirs, and optional `metapop_ref_sample`
  (a BAM filename minus `.bam`).
- Next: commit + PR; run metapop on real vOTU BAMs on the HPC.
