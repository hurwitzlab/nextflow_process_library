# Lab Notebook — nextflow_modules

Chronological log of work sessions on this project. Newest entries at the bottom.
Append-only — never edit or reorder past entries.

Entry format:
## YYYY-MM-DD
- What was done / tried
- What happened (concrete results, errors, numbers — not a diff restatement)
- Decision or next step

---

## 2026-09-08
- Repo created today (`hurwitzlab/nextflow_modules`, scaffolded with `README.md`, `LICENSE`,
  `.gitignore`) as the lab's single shared home for Nextflow tool modules, so every pipeline
  reuses the same module files instead of each keeping its own copy.
- Moved (not copied) all 9 existing `.nf` module files plus `CLAUDE.md` out of
  `viral_inference_benchmark/nextflow_pipeline/modules/` into `modules/` here: `bbmap.nf`,
  `checkv.nf`, `deepvirfinder.nf`, `genomad.nf`, `marvel.nf`, `samtools.nf`, `vibrant.nf`,
  `virsorter2.nf`, and `filter_viral_genomad.nf` (still WIP — empty shell blocks). Updated
  every `include` in `viral_inference_benchmark` to the new relative path.
- Added `modules/TEMPLATE.nf`, a fill-in-the-blank module skeleton matching every rule in
  `CLAUDE.md`. Generalized `CLAUDE.md` itself: it no longer assumes one specific pipeline's
  directory/config layout (label-first-then-container convention, and modules treated as a
  contract of `params.*` names the consuming pipeline must define, not something modules own).
- Wrote `README.md`: the sibling-clone requirement for consuming pipelines, why `include`
  paths can't be config-driven (Nextflow resolves them as compile-time literals), a pinning
  caveat (clone tracks `main` unless you deliberately `git checkout` a tag/commit), the
  `params.*` contract, a module table, and how to add a new module.
- Separately, another operator ran a large legacy-tool migration into `modules/dev/`
  today (~87 files converted from `/Users/blhurwit/work/brc/nf/tools`, a staging step
  with nothing promoted to `modules/` pending human review). That operator's record
  originally lived in its own `LAB_NOTEBOOK.md` at the repo root; folding it in below
  (headers demoted one level) since a repo gets one chronological notebook, not two —
  `LAB_NOTEBOOK.md` itself has been deleted.

**Operator:** Claude Code, on behalf of blhurwit@ncsu.edu

### Purpose

Migrate legacy Nextflow process definitions from `/Users/blhurwit/work/brc/nf/tools`
(the old, per-pipeline "tools" directory, LSF/ad hoc-config era) into the shared
`nextflow_modules` repo's module conventions, as a staging step before promotion
out of `modules/dev`. The source directory was **not modified** — every file
below was read-only in `nf/tools` and copied+rewritten into
`nextflow_modules/modules/dev/`.

### Scope decision

`nf/tools` contains 107 top-level `.nf` files (excluding `backup/` and template
files). An agent-assisted read of every file classified each as:

- **TOOL** — a `process` block that thinly wraps a real, independently-named
  bioinformatics CLI tool (e.g. `blastn`, `samtools`, `checkm2`).
- **CUSTOM** — a bespoke, project-specific glue/report/analysis script with no
  independent tool identity (e.g. QC aggregators, report generators, ad hoc
  Biopython scripts).
- **MIXED** — a file containing both TOOL and CUSTOM processes side by side.
- **UNCLEAR/placeholder** — files with a container constant but no `process`
  block at all.

| Verdict | Count | Disposition |
|---|---|---|
| TOOL | 80 | Migrated |
| MIXED | 7 | Migrated (all processes, per decision below) |
| CUSTOM | 17 | **Skipped** — not a bioinformatics tool wrapper |
| UNCLEAR/placeholder | 3 | **Skipped** — no process block to convert |

**87 files were migrated** (TOOL + MIXED). Decisions confirmed with the user
before any editing began:

1. Scope = TOOL + MIXED (not TOOL-only).
2. For MIXED files, convert **every** process in the file (both the
   tool-wrapping ones and the custom glue ones living alongside them), per the
   target repo's "one file per tool, multiple processes" convention.
3. Do the full migration in one pass (no batch-by-batch checkpoints), using
   parallel subagents to manage the volume.
4. This notebook lives at the repo root.

#### Files skipped as CUSTOM (17) — not bioinformatics-tool wrappers

`ampliconcounting.nf`, `ampsaexp.nf`, `ani_analysis.nf`, `best_genome.nf`,
`biopython.nf`, `clustervariants.nf`, `failurereport.nf`, `fbesm.nf`,
`flowcellqcsummary.nf`, `kmercounting.nf`, `qc_threshold.nf`, `qcsummary.nf`,
`rearrange.nf`, `scaffoldmetrics.nf`, `sha256.nf`, `stockpurityqc.nf`,
`variantcaller.nf`

#### Files skipped as placeholders (3) — no process block present

`ncbi-blast.nf`, `phageterm.nf`, `smrtlink.nf`

### Conversion rules applied

Full rules: [`modules/CLAUDE.md`](modules/CLAUDE.md). Summary of the mechanical
transforms applied to every migrated file:

- Shebang fixed to `#!/usr/bin/env nextflow` (source files often carried a
  garbled `-e #!/usr/local/apps/nextflow/nextflow`).
- `nextflow.enable.dsl=2` line removed (belongs in the consuming pipeline, not
  the module).
- One-line `//` plain-English comment added above every `process` block.
- Process names normalized to lowercase `snake_case`.
- `label "process_<tier>"` added as the first line in every process block,
  sized to the tool's actual cpu/memory footprint from the source file.
- `container "${params.container__<tool>}"` replaces the hardcoded
  `CONTAINER = "..."` constant.
- `publishDir "${params.<tool>_outdir}", mode: 'copy'` added for
  terminal/final outputs only; omitted for purely intermediate steps.
- Inputs converted to `tuple val(sampleid), path(...)` for per-sample data;
  reference databases/shared resources kept as separate `path(...)` inputs;
  generic `stageAs:`-renamed inputs given descriptive variable names instead.
- Every output given an explicit, descriptive `emit:` name; `sampleid`
  preserved through per-sample output tuples.
- `script:` + `"""..."""` (`${...}` interpolation) converted to `shell:` +
  `'''...'''` (`!{...}` interpolation); backslash-escaped bash locals
  (`\$VAR`) un-escaped since shell blocks don't need it.
- Thread counts switched to `!{task.cpus}` throughout.
- No `#` comments left on backslash-continued shell lines.
- Brace balance verified on every process block.

### Per-file change log

#### gatk.nf
- Source processes: `call_somatic_variants`, `filter_somatic_variants`, `annotate_vcf_with_bam_depth`, `compare_references` (4 processes)
- Converted processes: same names (already snake_case)
- Label(s): `process_single` for all 4 (source used `cpus=1`)
- Container param: `container__gatk`
- publishDir: `filter_somatic_variants`, `annotate_vcf_with_bam_depth`, `compare_references` — not on `call_somatic_variants` (feeds the filter step)
- Outputs: `variant_calls`, `filtered_variant_calls`, `depth_annotated_variants`, `comparison_stats`, `comparison_variants`, `comparison_variants_index`
- Params referenced: `container__gatk`, `gatk_outdir`
- Notes: Kept `stageAs: "ref.fasta"`/`"refcomp.fasta"` in `compare_references` only, because GATK `CompareReferences` derives its output VCF name from the two input basenames — a deliberate exception to the "no stageAs" default. **Needs human review**: whether `filter_somatic_variants`/`annotate_vcf_with_bam_depth` are both genuinely meant to be `publishDir` terminal points is a pipeline-semantics call the agent made without full context.

#### amrfinder.nf
- Source processes: `amrfinder` (1)
- Label: `process_single`
- Container param: `container__amrfinder`
- publishDir: yes (`resistance_genes`)
- Params referenced: `container__amrfinder`, `amrfinder_outdir`, `amrfinder_organism`
- Notes: **Behavior change flagged** — promoted the hardcoded `-O Escherichia` flag to `params.amrfinder_organism`. Consuming pipeline config must now set this param (e.g. to `"Escherichia"`) to preserve old behavior, or the process will fail on an undefined param.

#### bakta.nf
- Source processes: `annotate_bacterial` (1, from the OLD source — different/more outputs than the pre-existing `modules/bakta.nf`)
- Label: `process_medium` (borderline — 8 cpus/30GB mem, `process_high` also defensible)
- Container param: `container__bakta`
- publishDir: yes, all 13 emits
- Outputs: `annotation_table`, `annotation_gff3`, `annotation_genbank`, `annotation_embl`, `annotated_contigs`, `annotated_genes`, `annotated_proteins`, `hypothetical_proteins_table`, `hypothetical_proteins`, `summary`, `summary_plot_png`, `summary_plot_svg`, `annotation_json`
- Params referenced: `container__bakta`, `bakta_outdir`
- Notes: **Intentional behavior addition** — added `--prefix !{sampleid}` (a real Bakta flag) so per-sample output naming stays deterministic once the input is a natural `path(contigs)` instead of a fixed `stageAs` filename; not present in the original script. The pre-existing `modules/bakta.nf` uses a different, more collapsed I/O shape (single output dir) — this dev/ version intentionally preserves the OLD source's full 13-output granularity instead of matching it; a human should decide whether to reconcile the two eventually.

#### bandage.nf
- Source processes: `visualize_assembly` (1)
- Label: `process_single`
- Container param: `container__bandage`
- publishDir: yes (`assembly_graph_image`)
- Notes: Source output was unnamed; added `emit: assembly_graph_image` and renamed file to `${sampleid}.svg`.

#### bbmerge.nf
- Source processes: `merge_fastqs` (1)
- Label: `process_single`
- Container param: `container__bbmerge` (note: source's hardcoded image tag was actually `bbnorm:20201228_235829`, shared with the bbnorm package — param still follows the file/tool name per rule 6)
- publishDir: yes, all 5 emits
- Outputs: `merged_reads`, `unmerged_r1`, `unmerged_r2`, `detected_adapters`, `log`
- Params referenced: `container__bbmerge`, `bbmerge_outdir`
- Notes: All output filenames given a `${sampleid}.` prefix to preserve sample association.

#### bbnorm.nf
- Source processes: `downsample_paired_end_bacterial`, `downsample_paired_end_phage`, `downsample_paired_end` (3)
- Label: `process_high` for all 3 (source: cpus=16, mem=24GB fixed)
- Container param: `container__bbnorm`
- publishDir: yes, all 3 (independent alternatives, not intermediates)
- Outputs: `r1_normalized`, `r2_normalized` (per process)
- Params referenced: `container__bbnorm`, `bbnorm_outdir`, `bbnorm_kmer_cov_bacterial`, `bbnorm_min_depth_bacterial`, `bbnorm_kmer_cov_phage`, `bbnorm_min_depth_phage`, `bbnorm_target`
- Notes: **New params required** — promoted 5 previously-hardcoded Groovy constants (`KMER_COV_BACTERIAL`, `MIN_DEPTH_BACTERIAL`, `KMER_COV_PHAGE`, `MIN_DEPTH_PHAGE`, `KMERX`) to `params.bbnorm_*`; consuming pipeline config must now define all 5 (previously not configurable at all). Also replaced the hardcoded `MAXMEM` heap constant with a dynamic `Math.round(task.memory.toGiga() * 0.83)` expression tied to actual task memory allocation, mirroring `samtools.nf`'s pattern.

#### bcl2fastq.nf
- Source processes: `demux`, `demux_samplesheet` (2)
- Label: `process_high` for both (source: cpus=32, mem=64GB)
- Container param: `container__bcl2fastq`
- publishDir: yes, both (standalone terminal runs)
- Outputs: `demuxed_reads` (both)
- Params referenced: `container__bcl2fastq`, `bcl2fastq_outdir`
- Notes: No natural sampleid (demultiplexes an entire flowcell into many samples at once) — kept plain `path()` inputs, no tuple. Dropped source's redundant `type: "dir"` output qualifier (style-only, `path` auto-detects directories).

#### mothur.nf
- Source processes: `generate_asvs` (1)
- Label: `process_low`
- Container param: `container__mothur`
- publishDir: yes (`taxonomy`, `count_table`, `log_file`)
- Params referenced: `container__mothur`, `mothur_outdir`
- Notes: Kept `stageAs` for reads and both reference DBs because the process shells out to an opaque `run_mothur.sh` that (per the source's own comment) checks the environment/expects files at fixed locations — **could not inspect that script to confirm**; flagging for review.

#### mafft.nf
- Source processes: `mafft_linsi` (1)
- Label: `process_low`
- Container param: `container__mafft`
- publishDir: yes (`aligned_fasta`)
- Notes: No natural sampleid — MAFFT aligns an arbitrary multi-sequence fasta; kept plain `path()` input. **Human should confirm** this pipeline's actual usage isn't per-sample.

#### maxbin2.nf
- Source processes: `binContigs`, `binContigsSingleEnd` (2) → renamed `maxbin2_bin_contigs`, `maxbin2_bin_contigs_single_end`
- Label: `process_single` (both)
- Container param: `container__maxbin2`
- publishDir: yes, both (`fasta_bins`, `bin_manifest`, `summary`, `log_file`)
- Notes: Renamed away from generic `binContigs` to avoid colliding with `metadecoder.nf`'s process of the same source name. No thread flag invented (source never passed one to `run_MaxBin.pl`, even though the tool supports `-thread` — adding it would be a behavior change beyond the source, left alone).

#### medaka.nf
- Source processes: `medaka_polish_assembly` (1)
- Label: `process_high`
- Container param: `container__medaka`
- publishDir: yes (`polished_assembly`, `results`)
- Params referenced: `container__medaka`, `medaka_outdir`, `medaka_basecall_model`
- Notes: **New param required** — promoted hardcoded `BASECALL_MODEL = "r941_min_sup_g507"` to `params.medaka_basecall_model` (source's own comment says this varies by pore/basecaller version); consuming pipeline must now set it to preserve old behavior. Also changed output dir from fixed `medaka_out` to `!{sampleid}` — deliberate deviation from literal translation, low risk but worth a second look.

#### megahit.nf
- Source processes: `assemble`, `assemble_single_end` (2, from the OLD source — different from the pre-existing `modules/megahit.nf`) → renamed `megahit_paired_end`, `megahit_single_end`
- Label: `process_high` (both)
- Container param: `container__megahit` (reused existing param name for consistency with `modules/megahit.nf`)
- publishDir: yes, both (`contigs`, `log_file`, `options`)
- Notes: Kept this source's own hardcoded flags (`--min-contig-len 200`, `--min-count 2`, `--low-local-ratio 0.2`, `--no-mercy`) literal rather than reconciling with the different flag set (`--presets`) used in the pre-existing `modules/megahit.nf` — the two megahit modules are intentionally not option-identical; a human should decide whether to reconcile them. Kept default `megahit_out` output-dir name (did not switch to per-sample dir naming, unlike the medaka change above) — flagged as an inconsistency worth aligning later.

#### metabat2.nf
- Source processes: `bin` (1) → renamed `metabat2_bin`
- Label: `process_medium`
- Container param: `container__metabat2`
- publishDir: yes (`fasta_bins`, `bin_manifest`)
- Notes: Kept `stageAs: "assembly.fasta"` deliberately — the script greps for the literal string `assembly.fasta.metabat` (MetaBAT2 derives its output dir name from the actual input filename); without the fixed stage name this would silently break.

#### metadecoder.nf
- Source processes: `binContigs` (1, name collided with maxbin2.nf's source process) → renamed `metadecoder_bin_contigs`
- Label: `process_medium`
- Container param: `container__metadecoder`
- publishDir: yes (`fasta_bins`, `bin_manifest`, `coverage`, `seed`, `dpgmm`, `kmers`)
- Notes: Kept `stageAs: "assembly.fasta"` for the same reason as metabat2.nf — MetaDecoder's own output filenames (`assembly.fasta.2500.metadecoder.dpgmm`/`.kmers`) are derived from the input basename.

#### bcftools.nf
- Source processes: `add_uncalled_variants`, `normalize_variants`, `add_variants_to_fasta`, `filter_variants`, `set_genotype`, `concat_vcfs` (6)
- Label: `process_single` (all 6)
- Container param: `container__bcftools`
- publishDir: `add_variants_to_fasta` (`edited_genome`), `concat_vcfs` (`final_variants`/`final_variants_tabix`)
- Outputs: `merged_variants(+tabix)`, `normalized_variants(+tabix)`, `edited_genome`, `filtered_variants(+tabix)`, `regenotyped_variants(+tabix)`, `final_variants(+tabix)`
- Notes: No natural sampleid anywhere — this reads as a single genome-editing workflow (compare called vs. expected variants, normalize/filter, concat). **Human should double-check** bcftools/tabix `.tbi` name-matching still holds since `stageAs` fixed names were dropped in favor of natural variable names — verify any consuming pipeline supplies VCF/`.tbi` pairs with matching basenames. publishDir placement on 2 of 6 steps is a judgment call.

#### bedtools.nf
- Source processes: `bam_to_fastq`, `get_fasta` (2)
- Label: `process_single` (both)
- Container param: `container__bedtools`
- publishDir: none — both intermediate
- Notes: `get_fasta`'s sampleid-ness is ambiguous (looks like it may belong to the same CRISPR-editing workflow as bcftools.nf) — kept as plain `path` inputs; **flagged for human confirmation**.

#### bracken.nf
- Source processes: `estimate_abundance` (1) → renamed `bracken` (matches the already-established `modules/bracken.nf`)
- Label: `process_high` (mem 32GB despite cpus=1)
- Container param: `container__bracken`
- publishDir: yes (`bracken_stats`, `bracken_kreport`)
- Notes: Kept `kreport` staged under a fixed name because `est_abundance.py` derives a secondary output filename from the input report's basename. Added an explicit `mv` afterward to rename the per-sample output so it doesn't collide with other samples under a flat `publishDir` — a deliberate behavior-preserving addition worth double-checking.

#### busco.nf
- Source processes: `busco_assess` (1)
- Label: `process_high`
- Container param: `container__busco`
- publishDir: yes (`json_report`, `txt_report`, `busco_results`)
- Notes: Changed `-o` from fixed `busco_out` to `!{sampleid}_busco_out`, which changes BUSCO's derived summary filename accordingly (reflected in emit paths) — **human should verify** this naming pattern matches the actual BUSCO output convention in the pinned container version. `bacteria_odb10` lineage left hardcoded (baked into both command and expected output filename).

#### bwa.nf
- Source processes: `align`, `align_single_end`, `align_to_index` (3, from OLD source — materially different from the pre-existing `modules/bwa.nf`, which only has `bwa_index`+`bwa_mem` on an already-indexed reference) → renamed `bwa_align`, `bwa_align_single_end`, `bwa_align_to_index`
- Label: `process_high` (all 3)
- Container param: `container__bwa` (kept consistent with existing module)
- publishDir: none — all three intermediate `.sam` feeding a downstream samtools step
- Notes: This source re-indexes the reference inline on every call and supports single-end/pre-built-index variants that the existing `modules/bwa.nf` doesn't have. **Not reconciled** with the existing module — flagging for a human decision on whether to consolidate.

#### centrifuge.nf
- Source processes: `readContamination` (1) → renamed `read_contamination`
- Label: `process_high` (mem 64GB)
- Container param: `container__centrifuge`
- publishDir: yes (`classified_reads`, `classification_report`, `kraken_report`)
- Notes: Kept `database` as `val(centrifuge_db)` (not `path`) exactly as source — it's passed to a custom `file_handler` script rather than staged by Nextflow, looks deliberate (likely an S3 path resolved at runtime).

#### checkm.nf
- Source processes: `checkm_lineage`, `checkMLineageBins` (2) → renamed `checkm_lineage`, `checkm_lineage_bins`
- Label: `process_high` (both, mem 40GB)
- Container param: `container__checkm`
- publishDir: yes, both (`quality_assessment`)
- Notes: Kept `stageAs: "bins/contigs.fna"` on `checkm_lineage`'s contigs input — CheckM requires a directory of bin fasta files as its positional arg, a genuine tool-structure requirement, not just a filename preference.

#### picard.nf
- Source processes: `fastqToSam`, `estimateLibraryComplexity`, `markDuplicates`, `collectInsertSizeMetrics`, `collectGcBiasMetrics`, `collectAlignmentSummaryMetrics`, `collectQualityYieldMetrics`, `collectBaseDistributionByCycle`, `collectWgsMetrics`, `collectVariantCallingMetrics` (10 processes; source also had 2 `workflow` blocks) → renamed all to snake_case
- Label: `process_single` (all 10)
- Container param: `container__picard`
- publishDir: all except `fastq_to_sam` (intermediate)
- Notes: **Dropped the 2 `workflow` blocks entirely** — module files in this repo hold only `process` blocks; workflow wiring belongs to the consuming pipeline. **Fixed a source bug**: `fastqToSam` declared two inputs both named `r1` — corrected to a proper paired tuple. `markDuplicates`'s illegal-in-shell `def maxmem = ...` Groovy assignment replaced with the same dynamic `Xmx` pattern used in `bbnorm.nf`. Dropped `errorStrategy 'ignore'` (not used elsewhere in this repo's modules — should live in pipeline config if still wanted). Renamed hardcoded placeholder `SM=foo RG=foo` to `SM=!{sampleid} RG=!{sampleid}` — a behavior improvement now that a real sampleid exists; flag in case the fixed value was intentional.

#### checkm2.nf
- Source processes: `checkMLineageBins` (1) → renamed `checkm2`
- Label: `process_medium`
- Container param: `container__checkm2`
- publishDir: yes (`quality_report`)
- Notes: Dropped `stageAs` per source's own comment that it "only renames files" and doesn't handle a directory of multiple files; made `--output-directory` per-sample instead of fixed `results`.

#### checkv.nf
- Source processes: `checkv_end_to_end` (1, from OLD source — a different, more granular implementation than the pre-existing `modules/checkv.nf`, which emits one directory)
- Label: `process_high`
- Container param: `container__checkv` (reused existing param name)
- publishDir: yes, all 6 outputs
- Notes: **Flagging a real conflict** — reused `checkv_outdir`/`container__checkv` param names for consistency with the sibling `modules/checkv.nf`, but if both processes are ever used in the same pipeline they'd write to the same output dir. A human should decide whether to rename this dev/ version's params or reconcile the two checkv modules.

#### comparem.nf
- Source processes: `identify_reference_genome`, `find_candidate_references` (2)
- Label: `identify_reference_genome` → `process_low`; `find_candidate_references` → `process_high`
- Container param: `container__comparem`
- publishDir: yes, both
- Notes: `find_candidate_references` compares many genomes against many candidate references (both directories) — no sampleid, kept plain `path` inputs, mirrors `gatk.nf`'s `compare_references` pattern. Eliminated `stageAs` everywhere in favor of building the required directory structure in the shell body itself.

#### concoct.nf
- Source processes: `binContigs` (1) → renamed `bin_contigs`
- Label: `process_medium` (judgment call — cpus=8 but mem trivial)
- Container param: `container__concoct`
- publishDir: yes, all outputs
- Notes: Rewrote outputs to live under a per-sample `!{sampleid}/` directory instead of the fixed `concoct_output/` to avoid `publishDir` collisions across samples.

#### crispredict.nf
- Source processes: `predict_arrays` (1, unchanged name)
- Label: `process_single`
- Container param: `container__crispredict`
- publishDir: yes, both outputs
- Notes: Renamed fixed output dir `out/` to `!{sampleid}/` for the same collision-avoidance reason as concoct.nf.

**Cross-file note from this batch's agent:** dropped `errorStrategy 'ignore'` (picard, concoct) since no existing module in the repo uses it — if that behavior is still wanted it should be reintroduced via the consuming pipeline's config, not the module.

#### shortbred.nf
- Source processes: `virulenceFactors` (1) → renamed `identify_virulence_factors`
- Label: `process_high`
- Container param: `container__shortbred`
- publishDir: yes, all emits
- Notes: Preserved `sampleid` through every output tuple even though the original had no sample identity at all (pure `path` outputs) — worth a human check this doesn't break a downstream consumer expecting a bare path.

#### shovill.nf
- Source processes: `assemble` (1, unchanged)
- Label: `process_high`
- Container param: `container__shovill`
- publishDir: yes, all emits
- Notes: Renamed misleading emit labels to match what the files actually are (`assembly_graph` instead of `fastg` for a `.gfa` file — looked like a copy-paste labeling mistake in the source).

#### sickle.nf
- Source processes: `trim_paired_end` (1, unchanged)
- Label: `process_single`
- Container param: `container__sickle`
- publishDir: none — all intermediate
- Notes: No `task.cpus` usage added — original tool invocation never threaded either.

#### sketch.nf
- Source processes: `spaced_seed_sketch_single_read` (1, unchanged)
- Label: `process_low`
- Container param: `container__sketch`
- publishDir: yes, all 4 CSV emits
- Notes: **Flag for review** — these CSVs might be intermediate inputs to a downstream aggregation step outside this file rather than a true terminal output; published them since nothing in-file consumes them.

#### snippy.nf
- Source processes: `snippy_from_reads`, `snippy_from_contigs` (2, unchanged)
- Label: `process_medium` (both)
- Container param: `container__snippy`
- publishDir: yes, both, all emits

#### sourmash.nf
- Source processes: `sourmash_hash` (1, unchanged)
- Label: `process_single`
- Container param: `container__sourmash`
- publishDir: yes
- Notes: **Flag for review** — a `.sig` file is often just fed into a later `sourmash compare`/`search` step; chose to publish since signatures are typically reused/cheap to keep, but drop `publishDir` if this pipeline treats it as purely intermediate.

#### spades.nf
- Source processes: `assemble`, `assemble_metagenome`, `assemble_metagenome_single_end` (3, unchanged)
- Label: `process_high` (all 3)
- Container param: `container__spades`
- publishDir: yes, all 3
- Notes: **Important flag** — the two source processes used two *different* hardcoded container versions (`spades:20201216_235053` vs `spades:20220721_001047`); collapsed to a single `params.container__spades` per house style, so the consuming pipeline's config now controls the version and **loses the original version distinction**. A human should confirm the two SPAdes versions were actually interchangeable, or split into two container params if not. Kept tool-specific `errorStrategy` directives (real retry logic tied to a specific SPAdes exit code, not a resource-tier concern).

#### strainge.nf
- Source processes: `strainge_run_straingst_paired_end`, `strainge_run_straingst_single_end` (2, unchanged)
- Label: `process_high` (both)
- Container param: `container__strainge`
- publishDir: yes, both

#### stringmlst.nf
- Source processes: `mlst` (1) → **renamed to `stringmlst`**
- Label: `process_medium` (ambiguous tier: cpus=1 but mem=16GB)
- Container param: `container__stringmlst`
- publishDir: yes
- Notes: Renamed away from `mlst` specifically because a real `mlst.nf` module also exists in this migration batch (batch 8) — a process literally named `mlst` here would collide/confuse in a shared modules repo. Preserved the source's `--fastq1 !{r2} --fastq2 !{r1}` reversed argument order exactly as-is (possibly a source bug, possibly intentional) — did not attempt to "fix" tool logic, only interpolation syntax.

#### blast.nf
- Source processes: `blastn_reference_fasta`, `megablast_reference_database`, `blastn_pairwise_all_vs_all`, `summarize_blastn_all_pairwise`, `visualize_blastn_all_pairwise`, `parse_blast_xml`, `refine_and_filter_hits` (7, all converted per the MIXED-file decision, no renames needed)
- Label: `process_single`/`process_high`/`process_medium` per-process (mixed — see notes)
- Container param: `container__blast` (reused existing param name — see `modules/blast.nf` overlap note in Scope section)
- publishDir: `reference_blast_hits`, `megablast_hits`, `pairwise_blast_summary`, `pairwise_dotplots`, `guide_seeds` — not on `pairwise_blast_results`/`parsed_hits` (feed the next process in-file)
- Notes: `parse_blast_xml`/`refine_and_filter_hits` are part of a distinct guide-editing "campaign" workflow unrelated to the vector/megablast flows in the same file — no sampleid semantics apparent. **Flag**: `process_medium` label calls for those two (1 cpu, 8–16GB mem) didn't cleanly fit the cpu/mem tier buckets, worth a second look. Kept `stageAs: "blast_db/reference.fasta"` on `blastn_reference_fasta`'s reference input since the script does `cd blast_db && makeblastdb` — load-bearing.

#### fastp.nf
- Source processes: `trim_paired_end`, `trim_single_end` (2, unchanged)
- Label: `process_medium` (both)
- Container param: `container__fastp`
- publishDir: yes, both
- Notes: **Flag** — the original script never passes a thread/CPU flag to `fastp` at all despite reserving 8 cpus; preserved that exactly (no invented `--thread` flag) rather than "fixing" it — a human should decide if `--thread !{task.cpus}` should be added.

#### fastqc.nf
- Source processes: `fastqc`, `fastqc_single_reads`, `fastqc_unpaired_reads` (3, unchanged)
- Label: `process_single`/`process_single`/`process_low`
- Container param: `container__fastqc`
- publishDir: yes, all 3
- Notes: Kept `stageAs` on all three read inputs deliberately — FastQC names its output files from the input's basename, a genuine fixed-filename requirement. **Flag** — dropped the source's dynamic `memory { N.GB * task.attempt }` / `30m` timeout directives in favor of the label system; the source comment explained the 30m timeout existed specifically to catch a known silent-OOM issue — a human should confirm the consuming pipeline's label tiers provide equivalent retry/memory-escalation behavior.

#### filtlong.nf
- Source processes: `filtlong_qc_downsample_phage`, `filtlong_light_qc`, `filter_ont_reads_by_length` (3, unchanged)
- Label: `process_single` (all 3)
- Container param: `container__filtlong`
- publishDir: none — all 3 feed a downstream assembler, no `_outdir` param introduced since nothing is published from this file (would need to be added if a pipeline wants filtered reads published directly)

#### flye.nf
- Source processes: `flye_assembly`, `meta_assembly` (2, unchanged)
- Label: `process_high` (both)
- Container param: `container__flye`
- publishDir: yes, both
- Notes: Preserved `errorStrategy 'ignore'` on `meta_assembly` exactly as source — tool-specific resiliency behavior, not a resource directive, kept outside the label system.

#### gtdbtk.nf
- Source processes: `gtdbtk_classify_genome` (1, unchanged)
- Label: `process_high`
- Container param: `container__gtdbtk`
- publishDir: yes, all outputs
- Notes: Kept `stageAs: "genome.fna"` — GTDB-Tk's default genome-directory extension expectation is `.fna` and the source never passes `--extension`, so the fixed name is load-bearing exactly as originally written.

#### pandaseq.nf
- Source processes: `merge_fastqs` (1, unchanged)
- Label: `process_single`
- Container param: `container__pandaseq`
- publishDir: none — intermediate (feeds downstream amplicon processing)

#### phacts.nf
- Source processes: `lifestyle` (1, unchanged)
- Label: `process_single`
- Container param: `container__phacts`
- publishDir: yes (`lifestyle_prediction`)

#### pilon.nf
- Source processes: `refine_assembly` (1, unchanged)
- Label: `process_high`
- Container param: `container__pilon`
- publishDir: yes (`refined_contigs`)
- Notes: Dropped source's `maxRetries = 3` directive, consistent with samtools.nf/checkv.nf leaving retry policy to the pipeline's `withLabel:` config.

#### pirate.nf
- Source processes: `build_pangenome` (1, unchanged)
- Label: `process_high` (cpus=96, mem 128GB)
- Container param: `container__pirate`
- publishDir: yes, all 12 emits
- Notes: **Flag for careful review** — this file had the densest bash-escaping in the batch (`check_error`/`trap` logic, sed/awk locus-translation block); the agent called out this specific area as highest-risk for transcription error during the `\$`→`$` conversion.

#### plasmidfinder.nf
- Source processes: `plasmidfinder` (1, unchanged)
- Label: `process_single`
- Container param: `container__plasmidfinder`
- publishDir: yes (`plasmid_predictions`)

#### vsearch.nf
- Source processes: `count_unique_amplicons`, `denoise_amplicons`, `detect_chimeras_de_novo`, `count_denoised_amplicons`, `detect_chimeras_from_reads`, `match_amplicons` (6, unchanged)
- Label: `process_low` (all 6)
- Container param: `container__vsearch`
- publishDir: `count_denoised_amplicons`, `detect_chimeras_from_reads`, `match_amplicons` — not on the 3 earlier intermediate steps
- Notes: **Flag for careful review** — `detect_chimeras_from_reads` and `match_amplicons` had the densest awk/escaping in this batch (field refs, tab-separator literals, WT/non-WT join logic); worth a close second read.

#### mmseqs.nf
- Source processes: `cluster_proteins` (1, unchanged)
- Label: `process_high`
- Container param: `container__mmseqs`
- publishDir: yes, all 4 emits
- Notes: **Flag** — added `--threads !{task.cpus}` to the `easy-cluster` call even though the original never passed a thread flag (only declared `cpus=64` on the process) — very likely a legacy oversight, adding it preserves evident intent, but a human should confirm.

#### minimap2.nf
- Source processes: `find_engineered_snvs`, `align`, `align_to_index`, `ont_read_accuracy` (4, unchanged)
- Label: `process_single`/`process_low`/`process_low`/`process_medium`
- Container param: `container__minimap2`
- publishDir: `find_engineered_snvs`, `ont_read_accuracy` only — `align`/`align_to_index` are intermediate

#### mlst.nf
- Source processes: `mlst` (1, unchanged)
- Label: `process_single`
- Container param: `container__mlst`
- publishDir: yes (`mlst_calls`)

#### mummer.nf
- Source processes: `find_engineered_snvs` (1, unchanged)
- Label: `process_single`
- Container param: `container__mummer`
- publishDir: yes (`variant_calls`, `variant_calls_index`)
- Notes: Shares its process name `find_engineered_snvs` with the one in `minimap2.nf` — harmless since each lives in its own file, but flag in case a consuming workflow ever imports both without aliasing.

#### muscle.nf
- Source processes: `generate_multiple_sequence_alignment_dir` (1, unchanged)
- Label: `process_high`
- Container param: `container__muscle`
- publishDir: yes (`aligned_sequences_archive`)
- Notes: Input is a tarball of many fastas across potentially many samples — no sampleid, matches rule 8's "merging across many samples" exception.

#### nanoplot.nf
- Source processes: `nanoplot_qc` (1, unchanged)
- Label: `process_low`
- Container param: `container__nanoplot`
- publishDir: yes (`html_report`, `report_dir`)
- Notes: Kept source's `errorStrategy 'ignore'` (QC failure on one sample shouldn't halt the run) — not covered by CLAUDE.md rules but clearly intentional; flag for a human to confirm this is still wanted in house style.

#### nanosim.nf
- Source processes: `nanosim_read_analysis`, `alignment_analysis` (2, unchanged)
- Label: `process_medium`/`process_high`
- Container param: `container__nanosim`
- publishDir: yes, both
- Notes: **Behavior change flagged** — the original `alignment_analysis` awk command referenced a legacy `params.sample_id` global (with what looks like a pre-existing stray-backslash bug, `\\${params.sample_id}`) to identify "the current sample"; replaced with the process's own `!{sampleid}` from the new tuple input — more correct and idiomatic, but an intentional behavioral change from a literal translation. Kept `errorStrategy 'ignore'` on both, same rationale as nanoplot.nf.

#### trycycler.nf
- Source processes: `trycycler_long_read_assembly` (1, unchanged)
- Label: `process_high`
- Container param: `container__trycycler`
- publishDir: yes (`consensus_contig`, `partitioned_reads`, `assembly_results`)
- Params referenced also: `params.expected_phage_genome_size` (left unprefixed — pre-existing global option, not tool-specific)

#### unicycler.nf
- Source processes: `unicycler_short_read_assembly`, `unicycler_long_read_assembly`, `unicycler_hybrid_assembly`, `unicycler_hybrid_assembly_bacterial` (4, unchanged)
- Label: `process_high` (all 4)
- Container param: `container__unicycler`
- publishDir: yes, all 4

#### uniqsketch.nf
- Source processes: `uniqsketch_build_index_stock`, `uniqsketch_query_stock_sample` (2, unchanged)
- Label: `process_high` (both — chosen by cpu count even though the query process only needs 4GB mem)
- Container param: `container__uniqsketch`
- publishDir: yes, both
- Notes: **Flag** — in the awk line, a two-layer escaping case was resolved (Groovy-only `\\"`→`\"`, `\$1`→`$1`, but a single backslash on `\"` was preserved since awk itself needs it to emit literal quotes in JSON output) — worth a human double-check.

#### vamb.nf
- Source processes: `binContigs` (1) → renamed `bin_contigs`
- Label: `process_medium` (source had no explicit cpus, defaulted per rule 5)
- Container param: `container__vamb`
- publishDir: yes (`genome_bins`, `bin_name_map`, `cluster_assignments`, `run_log`)

#### vibrant.nf
- Source processes: `vibrant` (1, from the OLD source — a materially different code path than the pre-existing `modules/vibrant.nf`: this one extracts `databases.tar.gz`/`files.tar.gz` archives and uses `-d/-m` flags, vs. the existing module's direct `-f/-l/-o` invocation with no db archives)
- Label: `process_high`
- Container param: `container__vibrant`
- publishDir: yes, all 4 emits
- Notes: **Risk flag** — process name `vibrant` is identical to the process name in the already-existing `modules/vibrant.nf`; if a pipeline ever includes both files, Nextflow will collide on process name. Left as-is per the "stay consistent with existing module naming" instruction, but a human should confirm these two are never included together without an `as` alias.

#### virsorter2.nf
- Source processes: `find_phages_sensitive`, `find_phages_specific` (2, from the OLD source — which, unlike the pre-existing `modules/virsorter2.nf`, takes no explicit `virsorter2_db` path input at all)
- Label: `process_high` (both)
- Container param: `container__virsorter2`
- publishDir: `find_phages_specific` only (pass 2 final output) — pass 1 feeds pass 2 in-file
- Params referenced also: `params.viralinference_minlength` (reused unprefixed shared param, matching the existing `modules/virsorter2.nf` convention)
- Notes: **Functional gap flagged** — did not add a `virsorter2_db` input since the old source truly never had one; this dev/ version may be functionally behind the current `modules/virsorter2.nf` — human should check whether this old source is even still relevant/current.

#### virulencefinder.nf
- Source processes: `virulencefinder` (1, unchanged)
- Label: `process_single`
- Container param: `container__virulencefinder`
- publishDir: yes (`virulence_factors`)

#### kraken.nf
- Source processes: `readContamination`, `singleEndReadClassification`, `pairedEndReadSelector`, `pairedEndReadExcluder`, `singleEndReadSelector`, `singleEndReadExcluder`, `kreportToJson` (7, all converted per MIXED-file decision) → renamed to snake_case
- Label: `process_high` (classification processes, mem 92GB) / `process_single` (selector/excluder/json processes)
- Container param: `container__kraken`
- publishDir: classification + `kreport_to_json` outputs — not on the 4 selector/excluder processes (intermediate)
- Notes: `kreportToJson`'s inline python (originally invoked via a `#!/usr/bin/env python3` shebang trick unique to `script:` blocks) had to be restructured as a `python3 <<'PYEOF' ... PYEOF` heredoc inside the `shell:` block since `shell:` always executes via bash. **Flag**: `database` kept as `val(kraken_db)` (not `path`) since it pairs with a custom `file_handler` command (likely an S3-fetch helper) — human should confirm `file_handler` still works under the new param contract.

#### hmmer.nf
- Source processes: `jackhmmer_seq`, `jackhmmer_dir`, `hmmbuild` (3, unchanged)
- Label: `process_high`/`process_high`/`process_single`
- Container param: `container__hmmer`
- publishDir: `jackhmmer_dir`, `hmmbuild` — not `jackhmmer_seq` (feeds a downstream hmmbuild call)

#### insilicoseq.nf
- Source processes: `createMockCommunityReadsAbundanceDistribution`, `createMockCommunityReadsAbundanceFile`, `createAbundanceFile` (3) → renamed to snake_case
- Label: `process_medium`/`process_medium`/`process_single`
- Container param: `container__insilicoseq`
- publishDir: both `iss generate` processes — not `create_abundance_file` (feeds the abundance-file process)
- Notes: No natural sampleid anywhere — these simulate a synthetic mock community from a set of input genomes. Source's `create_abundance_file` oddly mixed `shell:` with a double-quoted `"""` body and un-escaped `$` — fully rewritten to the standard `shell:`+`'''...'''`+`!{...}` form.

#### interop.nf
- Source processes: `illumina_interop_qc` (1, unchanged)
- Label: `process_single`
- Container param: `container__interop`
- publishDir: yes, all 15 emits
- Notes: This source was already close to house style. Kept all `stageAs` directives since the script hardcodes tests against exact literal paths (e.g. `if [ -f bcl_convert_unknowns.csv ]`) — a legitimate fixed-filename exception. **Flag** — preserved a pre-existing apparent logic quirk verbatim (an `awk 'NR!=1 {print}' | awk -F","...` pipeline where the first awk has no input source) — did not attempt to fix source logic bugs, only syntax conversion; a human should double check this.

#### interproscan.nf
- Source processes: `annotate` (1) → renamed `interproscan` (matches genomad/checkv tool-naming convention)
- Label: `process_high`
- Container param: `container__interproscan`
- publishDir: yes (`functional_annotation_gff3`, `functional_annotation_tsv`)
- Notes: Outputs declared via `path("${proteins}.gff3")`/`path("${proteins}.tsv")` referencing the input variable directly in the `output:` block (standard Nextflow, not `!{...}` shell interpolation) since interproscan.sh derives output filenames by appending extensions to the given input filename — human should confirm this resolves correctly at runtime.

#### kmergo.nf
- Source processes: `findGroupSpecificKmers` (1) → renamed `find_group_specific_kmers`
- Label: `process_high`
- Container param: `container__kmergo`
- publishDir: yes, all 14 emits (renamed from terse `A_ace`/`B_ace`-style names for clarity)
- Notes: No sampleid — compares two arbitrary groups (A vs. B) of genomes/metagenomes against each other, matches rule 8's comparison-input carve-out.

#### snpeff.nf
- Source processes: `annotate_variants_no_index`, `annotate_variants`, `annotate_expected_variants`, `variant_report` (4, all converted per MIXED-file decision, unchanged names)
- Label: `process_single` (all 4)
- Container param: `container__snpeff`
- publishDir: `annotate_expected_variants`, `variant_report` — not the other two (intermediate; `annotate_variants` is also marked DEPRECATED in source)
- Notes: **Flag** — `annotate_variants_no_index`'s `ann` command reads a literal `variants.vcf` (no `.gz`) even though the staged input is `variants.vcf.gz` with no intervening `gunzip` — looks like a pre-existing source bug, preserved verbatim rather than silently "fixed."

#### vcontact2.nf
- Source processes: `build_viral_ortholog_clusters`, `build_proteins_fp` (2, both converted per MIXED-file decision, unchanged names)
- Label: `process_high`/`process_single`
- Container param: `container__vcontact2` for the clustering process; **`container__shellbasic`** for `build_proteins_fp`
- publishDir: `build_viral_ortholog_clusters` only
- Notes: **Deliberate rule-6 exception, flag for review** — `build_proteins_fp` used a genuinely different container image in the source (`shellbasic:...`, a plain shell/awk utility image) than the clustering process (`vcontact2:...`); forcing both to `container__vcontact2` would silently change runtime behavior, so kept the distinct image as its own `container__shellbasic` param — confirm this matches the project's actual naming convention.

#### samtools.nf
- Source processes: `index`, `to_bam`, `mapped_reads_to_bam`, `unmapped_reads_to_bam`, `sort_to_bam`, `sort_by_name_to_bam`, `fasta_index`, `bam_to_fastq`, `bam_to_fastq_single_end` (9, from OLD source — different/more processes than the pre-existing `modules/samtools.nf`, unchanged names)
- Label: `process_single` (all 9)
- Container param: `container__samtools`
- publishDir: `index`, `fasta_index` only — mirrors the precedent in the existing `modules/samtools.nf` where only the terminal indexing step publishes
- Notes: **Flag** — added `-@ !{task.cpus}` to view/sort/index/fastq calls even where the source hardcoded `cpus=1` and no thread flag at all; matches the parent module's style but is a deliberate addition beyond literal 1:1 port. Also treated the original `index` process's hardcoded `input.bam.bai` output (regardless of whether input was actually BAM/SAM/CRAM) as a source bug and derived the index name from the real input filename instead.

#### semibin.nf
- Source processes: `binContigs` (1) → renamed `bin_contigs`
- Label: `process_medium` (no explicit cpus in source)
- Container param: `container__semibin`
- publishDir: yes (`fasta_bins`, `bin_names_json`)
- Notes: **Flag** — added `--threads !{task.cpus}` to the SemiBin call even though the original had no thread flag at all; without it the `process_medium` label's CPU allocation would go unused, but this is a deliberate addition beyond literal translation.

#### seqkit.nf
- Source processes: `seqtk_remove_duplicate` (1, source name referenced the wrong tool — "seqtk" vs. the actually-invoked `seqkit`) → renamed `deduplicate_sequences`
- Label: `process_medium`
- Container param: `container__seqkit`
- publishDir: none — treated as intermediate, **genuinely ambiguous, flag for review**
- Notes: Added `-j !{task.cpus}` to both seqkit calls even though source had no thread flag — same deliberate-addition caveat as semibin.nf.

#### serotypefinder.nf
- Source processes: `serotypefinder` (1, unchanged)
- Label: `process_single`
- Container param: `container__serotypefinder`
- publishDir: yes (`serotype_calls`)

#### usearch.nf
- Source processes: `count_unique_amplicons`, `denoise_amplicons`, `count_denoised_amplicons`, `create_uniques_count_table`, `create_denoised_count_table` (5, all converted per MIXED-file decision, unchanged names)
- Label: `process_single` (all 5)
- Container param: `container__usearch`
- publishDir: the two count-table processes only
- Notes: No sampleid anywhere — classic USEARCH/UNOISE3 amplicon workflows dereplicate/denoise pooled study-level reads (all samples concatenated, sample labels embedded in headers), not one sample at a time. **Human should confirm** this pooled assumption matches how the pipeline actually invokes this file.

#### prokka.nf
- Source processes: `annotate_bacterial`, `annotate_phage`, `annotate_phage_with_proteins`, `annotateMetagenome`, `annotate_custom_phage`, `annotate_named_phage` (6) → `annotateMetagenome` renamed `annotate_metagenome`
- Label: `process_medium` (all 6)
- Container param: `container__prokka`
- publishDir: yes, all 6
- Notes: **Fixed a real bug** — source had `—-compliant` (em dash + hyphen) instead of `--compliant` in all 6 processes, which would have broken the actual Prokka CLI call; corrected to `--compliant`, flagging for human sign-off since this changes literal script text, not just style. Kept `stageAs: "contigs.fasta"` in 5 of 6 processes because the shell's own `check_error()` function greps prokka's output for the literal string `contigs.fasta` — a genuine fixed-filename dependency. Preserved an odd double-timestamp naming pattern (`${phage}.${timestamp}.${timestamp}`) from the original rather than "fixing" it.

#### pycoqc.nf
- Source processes: `pycoqc_qc` (1, unchanged)
- Label: `process_medium`
- Container param: `container__pycoqc`
- publishDir: yes (`qc_report_html`, `qc_report_json`)
- Notes: No sampleid — source comment explicitly says "flowcell level metrics"; one ONT flowcell's summary can span multiple multiplexed samples.

#### quast.nf
- Source processes: `evaluate_assembly`, `evaluate_assembly_with_reference`, `evaluate_long_read_assembly`, `evaluate_ont_phage_assembly`, `evaluate_hybrid_assembly`, `evaluate_illumina_metagenome_assembly_paired_end`, `evaluate_illumina_metagenome_assembly_single_end`, `evaluate_ont_metagenome_assembly`, `evaluate_contigs` (9, unchanged)
- Label: `process_high` (all 9)
- Container param: `container__quast`
- publishDir: yes, all 9
- Notes: Standardized `--output-dir` to `!{sampleid}/quast_results` (was a fixed `quast_results/` for every sample) to avoid publishDir collisions across samples.

#### resfinder.nf
- Source processes: `resfinder` (1, unchanged)
- Label: `process_single`
- Container param: `container__resfinder`
- publishDir: yes (`resistance_genes`, `log`)

#### salmon.nf
- Source processes: `quantify_transcripts_aligned`, `quantify_transcripts_mapping_mode` (2, unchanged)
- Label: `process_medium` (both)
- Container param: `container__salmon`
- publishDir: yes, both
- Notes: Replaced in-place `gunzip r1.fq.gz` (which relied on the dropped `stageAs` fixed filename) with explicit `gunzip -c !{r1_fq_gz} > r1.fq` — preserves a deterministic local filename without depending on a forced input name; human should double-check this behaves identically to the original.

#### hhsuite.nf
- Source processes: `hhblits`, `hhblits_seq`, `ffindex_get`, `reformat_msa`, `download_pdb_structure`, `hhmake`, `convert_jackhammer` (7, unchanged names)
- Label: `process_high` (hhblits, hhblits_seq) / `process_single` (ffindex_get, reformat_msa, download_pdb_structure, hhmake) / `process_medium` (convert_jackhammer, no resources declared in source)
- Container param: `container__hhsuite`
- publishDir: `hhblits`, `hhblits_seq` only
- Notes: **Flag** — `ffindex_get`'s final `tar -czvf records.tar.gz -C records` is missing a trailing `.` (compare to `hhblits`'s correct form) — looks like a source bug, preserved verbatim rather than silently fixed; a human should confirm/fix. Kept `stageAs: "input.a3m"` on `hhmake`'s input since hh-suite tools often rely on the `.a3m` extension for format detection — unverified assumption.

#### hhsuiteparse.nf
- Source processes: `parse_hhr_dir`, `join_clusters_to_hhr` (2, both converted per MIXED-file decision, unchanged names)
- Label: `process_low` (both)
- Container param: `container__hhsuiteparse` (kept distinct from `container__hhsuite` per rule 6)
- publishDir: `join_clusters_to_hhr` only (`parse_hhr_dir` feeds it directly, in-file)
- Notes: `join_clusters_to_hhr`'s script is Python under a `#!/usr/bin/env python3` shebang inside the shell block — kept as-is (Nextflow honors the shebang).

#### cutadapt.nf
- Source processes: `trim_merged_fastq`, `trim_single_fastq`, `trim_amplicon_reads` (3, unchanged)
- Label: `process_single` (all 3)
- Container param: `container__cutadapt`
- publishDir: yes, all 3
- Notes: **Fixed a source bug** — `trim_amplicon_reads` declared `cpus = CPUS` (=1) but hardcoded `--cores 4` in the script; both now correctly derive from `!{task.cpus}` — flagging this behavior change for human confirmation. Subtle escaping in `trim_merged_fastq`'s awk print statement (quadruple-escaped `\\\$` reduced to single `\$`) — worth a sanity-check against a real run.

#### defensefinder.nf
- Source processes: `find_defenses` (1, unchanged)
- Label: `process_low`
- Container param: `container__defensefinder`
- publishDir: yes (`hmmer_hits`, `defense_systems`, `defense_genes`)

#### diamond.nf
- Source processes: `diamond_makedb`, `diamond_blastp`, `diamond_blastx`, `diamond_test`, `diamond_similarity_search` (5, unchanged)
- Label: `process_low`/`process_high`/`process_high`/`process_single`/`process_high`
- Container param: `container__diamond`
- publishDir: `diamond_blastp`, `diamond_blastx`, `diamond_similarity_search` — not `diamond_makedb` (infrastructure) or `diamond_test` (no output at all)

#### ezclermont.nf
- Source processes: `ezclermont` (1, unchanged)
- Label: `process_single`
- Container param: `container__ezclermont`
- publishDir: yes (`phylogroup`, `log`)

#### visualize_16s.nf
- Source processes: `visualize_16s`, `make_checkfile` (2, both converted per MIXED-file decision, unchanged names)
- Label: `process_low` (both)
- Container param: `container__visualize_16s`
- publishDir: yes, both
- Notes: No sampleid — both operate on whole-cohort taxonomy/feature tables, not one sample's data. Preserved the source's own apparent inconsistency verbatim: the script passes plain filenames (`asv_table.tsv`, `genus_breakdown.png`) to `asv_table_viz.py`, but the process's `output:` block declares them under a `visualize_output/` prefix — almost certainly because the script itself creates and writes into that subdirectory internally. Did not "fix" this; a straight syntax conversion only. **This file was originally reported converted by the batch-13 subagent but was never actually written to disk** — caught by an independent verification pass and created directly afterward.

### Post-conversion verification

An independent automated pass (not just each subagent's self-report) was run across all 87 output files in `modules/dev/`:

- **File count**: all 87 target files present (one, `visualize_16s.nf`, was initially missing despite being reported done — see note above; created directly to close the gap).
- **Brace balance**: all 87 files balance (`{` count == `}` count). (Two *pre-existing, unrelated* `modules/dev/` files — `deepmicroclass.nf` and `virfinder.nf`, not part of this migration — are unbalanced; out of scope, left untouched. Two other pre-existing files, `phamb.nf` and `viralverify.nf`, are empty placeholders, also out of scope.)
- **Shebang**: all 87 files start with exactly `#!/usr/bin/env nextflow`.
- **No leftover `nextflow.enable.dsl=2`** in any of the 87 files.
- **No leftover `script:` blocks** — all converted to `shell:`.
- **Source directory untouched**: `/Users/blhurwit/work/brc/nf/tools` was confirmed read-only throughout (every subagent explicitly checked this); no source `.nf` file was modified.

### Summary of flags for human review

Collected across all batches — search this notebook for **"Flag"**/**"flag"** for full context on each:

1. **Container-version ambiguity** (`spades.nf`): two SPAdes source processes used different hardcoded container versions, collapsed to one `container__spades` param — confirm the versions were interchangeable.
2. **Container mismatch, deliberate exception** (`vcontact2.nf`): `build_proteins_fp` needed its own `container__shellbasic` param since its source container differed from the tool's own image.
3. **Param-naming collision risk** (`checkv.nf`, in `dev/`): reused `container__checkv`/`checkv_outdir` from the pre-existing `modules/checkv.nf` — would collide if both are ever used in the same pipeline.
4. **Process-name collision risk** (`vibrant.nf` in `dev/`): process named `vibrant`, identical to the pre-existing `modules/vibrant.nf`'s process name.
5. **Behavior/default changes requiring new pipeline config**: `amrfinder.nf` (organism flag → param), `bbnorm.nf` (5 thresholds → params), `medaka.nf` (basecall model → param) — each needs the consuming pipeline's config updated to preserve prior behavior.
6. **Fixed source bugs** (preserved-vs-fixed calls made explicit per file): `prokka.nf`'s `—-compliant` em-dash typo (fixed), `cutadapt.nf`'s cpus/`--cores` mismatch (fixed), `picard.nf`'s duplicate `r1` input bug (fixed) — vs. bugs *preserved* verbatim: `snpeff.nf`'s ungzipped `variants.vcf` reference, `hhsuite.nf`'s missing `tar` trailing dot, `interop.nf`'s headerless awk pipeline, `stringmlst.nf`'s reversed `--fastq1`/`--fastq2` args.
7. **Deliberate new additions beyond literal translation** (thread flags added where the source never had one): `mmseqs.nf`, `semibin.nf`, `seqkit.nf`, `samtools.nf` — flagged individually as these change behavior (better CPU utilization) but aren't 1:1 ports.
8. **Ambiguous `publishDir` placement** (genuinely unclear whether output is terminal or intermediate): `bedtools.nf`'s `get_fasta`, `sketch.nf`, `sourmash.nf`, `seqkit.nf`, `mafft.nf` (also ambiguous on sampleid), `mothur.nf` (unverified `run_mothur.sh` internals).
9. **Two parallel, non-reconciled implementations** now exist for the same tool in several cases (`bakta`, `blast`, `bwa`, `checkv`, `megahit`, `samtools`, `vibrant`, `virsorter2`) — the pre-existing `modules/<tool>.nf` and this migration's `modules/dev/<tool>.nf` cover different/overlapping process sets and were deliberately not merged. A human should decide whether/how to consolidate before promoting anything out of `dev/`.

### Scope note

Nothing in `modules/dev/` was promoted to the parent `modules/` directory — per the task, everything stops at `dev/` for human review before promotion.
- Checked `modules/` vs `modules/dev/` for duplicate tool coverage (asked to look into this
  after the migration landed). Exact-filename overlap in both dirs: `bakta.nf`, `blast.nf`,
  `bracken.nf`, `bwa.nf`, `checkv.nf`, `megahit.nf`, `samtools.nf`, `vibrant.nf`,
  `virsorter2.nf` (9). Near-duplicates under a different name: `kraken2.nf` (root) /
  `dev/kraken.nf`, `mmseqs2.nf` (root) / `dev/mmseqs.nf`, `deepmicroclass2.nf` (root) /
  `dev/deepmicroclass.nf`. Verified via `diff`: all of these cover genuinely different or
  non-overlapping process sets (different process names/counts, e.g. root `bwa.nf` has
  `bwa_index`+`bwa_mem` vs. dev's `bwa_align`/`bwa_align_single_end`/`bwa_align_to_index`)
  **except** `bracken` and `vibrant`, which use the *same* process name in both files — a real
  Nextflow name collision if a pipeline ever includes both without an `as` alias. Also found a
  stray `modules/bbmap.nf copy` (content differs from `bbmap.nf`) — looks like an accidental
  Finder duplicate, not a real module.
- Decision / next step: nothing in `modules/dev/` gets promoted to `modules/` until a human
  reconciles the 9 (+3 near) parallel tool implementations — the migration record's own
  scope note above already says the same. `bracken`/`vibrant`'s process-name collision needs resolving
  before both could ever be included in the same pipeline. `modules/bbmap.nf copy` should be
  deleted or explained.
- Acted on the review above: for the 9 non-colliding tool pairs (`bakta`, `blast`, `bwa`,
  `checkv`, `megahit`, `samtools`, `virsorter2`, plus the near-duplicates `kraken2`/`dev/kraken`
  and `mmseqs2`/`dev/mmseqs`), merged each `modules/dev/*.nf`'s process(es) into the matching
  root `modules/*.nf` as additional process blocks in the same file, then deleted the `dev/`
  source. Verified brace balance and process counts on every merged file before deleting
  anything (e.g. `blast.nf` went from 2 to 9 processes, `samtools.nf` from 3 to 12) — all
  balanced, all end in `}`.
- One planned merge was aborted: `modules/dev/deepmicroclass.nf` is missing its closing `}`
  entirely (the `process deepmicroclassr` block just never closes) — this is the same
  pre-existing, unrelated brokenness the migration record above already flagged as out of
  scope for its migration. Reverted `deepmicroclass2.nf` back to its committed state via `git checkout` rather
  than merge broken content into it; `dev/deepmicroclass.nf` needs a human fix before it can be
  merged or promoted.
- For the 2 colliding tools (`bracken`, `vibrant` — same process name in both `modules/` and
  `modules/dev/`), deleted the `modules/dev/` copy without merging, per instruction — the two
  implementations aren't reconcilable into one file under Nextflow's per-file process-name
  uniqueness, so the existing root version stands as the only one.
- Flagged in-file: `checkv.nf`'s two processes (`checkv`, `checkv_end_to_end`) now share
  `container__checkv`/`checkv_outdir` — added a `NOTE:` comment above `checkv_end_to_end`
  since using both in the same pipeline run would collide on output directory; not renamed,
  left for a human decision.
- `modules/dev/` now holds only files untouched by this pass (never had a root-level
  duplicate) plus the one flagged exception (`deepmicroclass.nf`). `modules/bbmap.nf copy`
  (the stray accidental-duplicate file noted earlier) is still there, still unaddressed.
- Consolidated this repo's two notebooks into one, per lab convention (one chronological,
  append-only `NOTEBOOK.md` per repo, not a separate ad hoc report): merged
  `LAB_NOTEBOOK.md`'s content into this file's entry above and deleted the standalone file.
- Checked in the `notebook` skill itself as a project-scoped skill
  (`.claude/skills/notebook/SKILL.md`, copied verbatim from the user-level one at
  `~/.claude/skills/notebook/`), so anyone who clones this repo and uses Claude Code gets
  the same `/notebook` dated-entry convention automatically, without a per-user setup
  step. Documented the convention (and the checked-in skill) in a new README section.
- Expanded the README's notebook section into a "Working on this repo" section:
  states the expectation up front (record changes in `NOTEBOOK.md`, not just the commit
  message, since the notebook is for the *why*/*outcome* a diff can't carry) and adds a
  copy-pasteable prompt template for anyone recording a session manually or via a
  non-Claude-Code assistant, alongside the existing `/notebook` mention for Claude Code
  users.
- Noticed (before making any more README changes) that `modules/dev/` had gone from
  ~80 files down to 3 since our last check — a separate commit, `fcacaf3` "resolved
  conflicts between tools" (same user, different session), had promoted every
  remaining non-colliding `dev/` module to root and deleted the broken
  `dev/deepmicroclass.nf` outright rather than fixing it. Root module count is now 105.
- Updated `README.md` accordingly: added a "Repo layout: modules/ vs modules/dev/"
  section (what each directory is for, the promotion decision tree); replaced the
  now-9-rows-vs-105-actual-files module table with a `ls`/`grep` pointer instead of a
  table, since a hand-maintained list at this scale and edit pace goes stale within a
  day; added a "Contributing" section on checking for name collisions before adding a
  module (referencing the real `vibrant` collision from earlier as the concrete reason);
  added a "Known issues" section documenting the still-stray `modules/bbmap.nf copy`
  and the 3 remaining `dev/` files verified just now: `phamb.nf`/`viralverify.nf` are
  both literally empty (0 bytes), `virfinder.nf` has unbalanced braces (8 `{` vs. 7 `}`).

## 2026-09-10
- Established a `publishDir` convention that lets a consuming pipeline opt into
  per-sample, manifest-driven output paths without changing behavior for anyone else:
  `publishDir { params.<tool>_outdir instanceof Closure ? params.<tool>_outdir(sampleid) : params.<tool>_outdir }, mode: 'copy'`.
  A module still only ever assumes the `params.<tool>_outdir` contract — a pipeline
  opts in by setting that param to a `sampleid`-taking Closure instead of a plain
  string; every other pipeline is unaffected. Made this a required rule in
  `CLAUDE.md` (a plain-string `publishDir` is now a violation, not just an older
  style), including an exception only found after applying it repo-wide: a process
  with no `sampleid` in its `input:` (index-building, cross-sample merge/compare,
  whole-batch/run steps) must keep the plain-string form — forcing the Closure
  there is a hard compile-time error (`sampleid is not defined`), not a style
  issue. `TEMPLATE.nf` updated to show the required pattern. `modules/dev/`
  deliberately excluded from all of the below — still a pre-promotion staging
  area per the 2026-09-08 entry above, with its own unresolved issues; not touched.
- Ran a full compliance sweep (4 parallel passes, ~24 files each) across all 96
  real module files / ~225 `process` blocks: converted every existing static
  `publishDir` to the Closure form (~90 processes), correctly left ~20 as plain
  strings (no `sampleid` in scope, each annotated inline with why), and audited
  every process against every other `CLAUDE.md` rule. Missing `label
  "process_<tier>"` lines were filled in by matching a comparable already-labeled
  tool rather than defaulting to `process_medium` — e.g. `bwa_mem`→high (matches
  labeled `bwa_align*` siblings), `eggnogmapper`/`iphop`→high (matches
  `interproscan`/`genomad`, database-driven), `metabuli`/`metaphlan`→high (matches
  `centrifuge`/`kraken2`), `viralm`/`virrep`→medium (matches `deepvirfinder`, GPU
  classifiers). `samestr.nf`'s 6 processes got medium/medium/low/low/high/low with
  no repo precedent to match — a judgment call from each stage's computational
  shape, worth a second look.
- The stray duplicate file flagged unaddressed since 2026-09-08
  (`modules/bbmap.nf copy`) is resolved: its `bbduk`/`bbstats` processes were
  merged into `bbmap.nf` (by the repo owner, mid-session) and brought into full
  compliance (labels, Closure `publishDir`) along with everything else. In the
  sibling `viral_inference_benchmark` repo, `s_i_mg_readqc.nf` was updated to
  `include { bbduk }` from `bbmap.nf` (it previously pointed at a `bbduk.nf` that
  never existed) and a real emit-name mismatch (`bbduk.out.trimmed_reads` should
  have been `.clean_reads`) was fixed — that mismatch predated this session and
  had never been exercised against a real module until now.
- Sweep surfaced 5 pre-existing bugs, all confirmed via `git diff` to predate this
  session:
  - `mmseqs2.nf` (`cluster_proteins`) — fixed. Root cause: the Groovy
    triple-single-quoted shell-block string was itself decoding the nested awk
    script's escape sequences — `\(`/`\)` are invalid Groovy escapes and hard-fail
    the parse (`Unexpected character: '''`); `\047`/`\057` are valid octal escapes
    and were silently turned into literal `'`/`/` characters instead; a `"\n"`
    further down became a real embedded newline instead of a two-character
    escape. Fixed by doubling every backslash so Groovy passes them through
    unmodified to awk. Verified the mechanism with isolated minimal repros before
    touching the real file, then confirmed the generated `.command.sh` matches
    the original script's intent byte-for-byte.
  - `kraken2.nf` — fixed. 7 of its 8 processes used
    `container__kraken`/`kraken_outdir` instead of
    `container__kraken2`/`kraken2_outdir`, mismatched against the file's own name
    and its first process. Renamed all 7 to match. This is a breaking param-name
    change for any pipeline currently setting the old names for this module — none
    found in a repo-wide grep, but this repo has no visibility into every consumer.
  - `gatk.nf`'s `compare_references` — investigated, turned out NOT to be a bug.
    The `path(reference), stageAs: "ref.fasta"` comma placement looked wrong on
    read; a direct empirical test (invoking the process with real files) showed
    both inputs stage under exactly the intended names. Left untouched.
  - `pirate.nf`'s `build_pangenome` — same class of bug as `mmseqs2.nf`
    (unescaped quotes breaking the Groovy shell-block parse). Found, not fixed —
    out of scope this session.
  - `hhsuiteparse.nf` — separate, unrelated compile error
    (`path("results", type: 'dir')` syntax). Found, not fixed — out of scope this
    session.
- Also flagged, not touched: `filter_viral_genomad.nf` is an unfinished stub —
  both processes have empty shell bodies, and one looks copy-pasted from
  `bbmap.nf` with the wrong container/params/output names. Needs a real
  implementation from whoever owns that tool.
- Next steps for whoever picks this up: `pirate.nf` and `hhsuiteparse.nf` need the
  same treatment `mmseqs2.nf` got before they'll compile at all; `filter_viral_genomad.nf`
  needs an actual implementation; `samestr.nf`'s label tiers are a judgment call
  worth a second opinion; none of this session's ~87 changed files are committed yet.
- Implemented `filter_viral_genomad.nf`'s two processes (the stub flagged above),
  requested for a geNomad post-processing SLURM job: `filter_viral_contigs` runs
  `genomad_filterviral.r` (filters geNomad calls using checkV `quality_summary.tsv`
  + a coverage file, writes `<sample>_selection1.csv`); `extract_fasta_viral_selection`
  runs `genomad_getselectionviral.py` (extracts provirus/viral FASTA + ID-mapping CSVs
  from that selection). Both call the script by bare name, relying on Nextflow's
  auto-added pipeline `bin/` on `PATH`, matching the convention already used by
  `quast.nf`/`concoct.nf`/etc.
- The actual bin scripts weren't in this repo — traced them from
  `viral_inference_benchmark/nextflow_pipeline/bin/`, where their real filenames
  are `genomad_filterviral.r` and `genomad_getselectionviral.py` (the SLURM job
  that prompted this referenced `.R` and `getviralselection.py` — stale/incorrect
  names). Used the real filenames in the module.
- New params a consuming pipeline must define: `container__genomad_filterviral`,
  `genomad_filterviral_outdir`, `container__genomad_viralselection`,
  `genomad_viralselection_outdir`. Checked against `modules/CLAUDE.md` (balanced
  braces, Closure `publishDir` on both since `sampleid` is in scope, named `emit:`s,
  `shell:`/`!{...}` throughout) — clean, nothing to fix.
- Replaced the per-process in-module `publishDir` convention with a centralized,
  label-based one: a process now carries a second label — `publish_intermediate`
  or `publish_final` — alongside its resource label, with **no** `publishDir`
  directive of its own. The actual `publishDir` (path *and* `mode`) is owned by
  whichever pipeline runs the process, via `withLabel:publish_intermediate`/
  `withLabel:publish_final` blocks in that pipeline's own config —
  `viral_inference_benchmark/nextflow_pipeline/conf/base.config` is the reference
  implementation (see that repo's own notebook for the config-side details).
  Verified the mechanism empirically before trusting it, in isolated scratch
  tests: a `publishDir` closure defined in a config `withLabel:` block *can* see
  a process's own `sampleid`, even defined in a different file; `task.process`
  resolves fully-qualified with its subworkflow path (e.g.
  `"s_i_mg_readqc:trimmomatic"`), not the bare name, so dynamic per-tool lookup
  strips it (`task.process.tokenize(':').last()`); a config file can't define a
  top-level `def function(){}` (same restriction class as `if`/`exit` not being
  valid top-level config statements) nor a multi-statement closure body (`def x
  = ...` then a second line using `x` fails with "x is not defined") — the
  dispatch logic had to be one Closure, one expression.
- Scoped this first to the 6 processes `viral_inference_benchmark` actually uses
  (`bbduk`, `trimmomatic`, `megahit`, `genomad`, `checkv`, `pileup`), with each
  process's `publish_intermediate`/`publish_final` tier confirmed by the user
  per-process, not guessed (`bbduk`=intermediate; the other 5=final). This
  surfaced a real naming inconsistency: `pileup`'s outdir param was
  `bbmap_outdir` (file-name-based) while every other process used
  `<processname>_outdir` — renamed to `pileup_outdir` (same class of fix as the
  `kraken2.nf` `container__kraken`/`kraken_outdir` rename earlier this session).
- Updated `modules/CLAUDE.md` to make the label-based pattern the standard going
  forward (not just an alternative), keeping the older in-module Closure-ternary
  form as a documented, *required* exception for any process with no `sampleid`
  in scope (index builds, cross-sample merges, whole-batch/run steps —
  referencing `sampleid` in the centralized dispatch is a hard compile error for
  these). Updated `TEMPLATE.nf` to match.
- Before extending this repo-wide, flagged a real concern rather than proceeding
  unilaterally: this repo has no pipeline/config of its own, so stripping
  `publishDir` from every remaining process in favor of just a label would mean
  any consumer that hasn't adopted the same `withLabel:` convention gets nothing
  published at all, silently. Checked empirically: no other repo on this machine
  currently consumes `nextflow_modules` at all. The user clarified
  `viral_inference_benchmark` is deliberately the reference architecture every
  future pipeline in the lab will replicate, which resolved the concern.
- Ran a 4-way parallel sweep (subagents) across every remaining eligible file:
  **70 files, 130 processes total** now carry `publish_intermediate` (11) or
  `publish_final` (119) — the original 6 plus 124 more. Confirmed via repo-wide
  grep that zero `instanceof Closure` occurrences remain anywhere in
  `modules/*.nf` (every eligible process converted); ~27 files' processes
  correctly kept the old in-module form (no `sampleid` in scope) and were left
  untouched; `modules/dev/` untouched throughout. Tier classification used a
  stated heuristic (would a researcher want this file independent of the
  pipeline, or does it only feed the next same-file process) with
  precedent-matching against the first 6 and against comparable tools already
  classified elsewhere — flagged a handful of thinner-reasoning calls rather
  than presenting everything as equally confident: `cutadapt.nf` and
  `sourmash.nf`'s hash step (intermediate, reasoned by analogy without a
  confirmed downstream consumer), `kraken2.nf`'s `kreport_to_json` (final, but
  it's a re-export of already-published data), `nanosim.nf`'s
  `nanosim_read_analysis` (final, but its own comment says the real downstream
  consumer doesn't exist yet), `bbmerge.nf`/`fastp.nf` (depend on whether a
  future pipeline chains them further), `pilon.nf` (final, correct only if it's
  the pipeline's last polishing step), `hmmer.nf`'s `hmmbuild` and `gatk.nf`'s
  filter/annotate split (no visible channel wiring in this repo to confirm
  against).
- Full verification: all 88 modified files brace-balanced; every touched file
  passed a clean `nextflow run <file>.nf` standalone syntax check; `git status`
  confirmed exactly 88 `M` entries, zero deletions, zero untracked files, zero
  leftover test artifacts (one shared `modules/work` dir needed a second
  removal attempt after all forks finished).
- Next: the handful of thinner-reasoning tier calls listed above are worth a
  second look once real pipelines start using those tools. None of this
  session's changes are committed yet.

## 2026-09-30
- Restructured `modules/` so every tool lives in its own directory:
  `modules/<tool>.nf` → `modules/<tool>/<tool>.nf` (96 files, via `git mv` so
  history follows). Kept the tool name as the filename rather than nf-core's
  `main.nf`. Left in place: `TEMPLATE.nf` (a copy-paste starting point, not a
  tool), `bbmap.nf copy` (still the known stray file), and `modules/dev/`.
  Updated the README's `include` example and `ls`/`grep` discovery commands to
  `modules/*/*.nf`, and the File layout rule in `modules/CLAUDE.md`. Old paths
  in earlier notebook entries were left as-is (append-only log).
- Checked for in-repo breakage: none. No module `include`s another, and the
  only `../` paths in module code (`vibrant.nf`, `mmseqs2.nf`) are relative to
  the task work dir at runtime, not the `.nf` file's location.
- **Breaking for consuming pipelines:** any pipeline that `include`s a module
  by its old path fails at parse time once it picks up this change, until the
  path gains the `<tool>/` segment. Pipelines pinned to an earlier commit are
  unaffected. Consumer repos haven't been audited yet.
- Also removed the 3 tracked `.DS_Store` files (root, `modules/`,
  `modules/dev/`) and added `.DS_Store` to `.gitignore`.
- Opened PR #1 (branch `restructure-modules-into-dirs`). Next: update
  consuming pipelines' `include` paths after merge; decide on `bbmap.nf copy`,
  whether `TEMPLATE.nf` gets a directory, and whether the README commands
  should exclude `dev/` (`modules/*/*.nf` now matches it too).

## 2026-10-07
- Added `templates/base.config`, a copy-from starting point that defines all
  six labels modules use (`process_single`/`low`/`medium`/`high`,
  `publish_final`/`publish_intermediate`). Until now the README told pipelines
  to define them but gave nothing to copy, and the only working definitions
  lived in one lab pipeline (`hurwitzlab/merys_nf_pipelines`,
  `nextflow_pipeline/conf/base.config`). Prompted by the BRC Infrastructure
  site's Nextflow tab, which needed somewhere neutral to point for what the
  labels mean instead of one pipeline's own settings.
- Tier numbers, retry policy (retry once on exit 130-145/104, all requests
  scaled by `task.attempt`) and the `resolvePublishDir` dispatch were carried
  over from that pipeline unchanged, as starting values. Header comments say
  to copy rather than `includeConfig` it from here, and to tune from
  trace/`seff` results.
- Checked it parses: `nextflow config` (26.04.3, BRC module) on a stub
  `nextflow.config` that includes it resolves every tier and both publish
  blocks. Not exercised by a real pipeline run.
- **Doc fix — outdir naming:** the label-based `publishDir` looks up
  `params.<process name>_outdir` (the last segment of `task.process`), not
  `params.<tool>_outdir` as the README and `modules/CLAUDE.md` said. 106 of
  the 129 label-published processes in `modules/` have a process name that
  differs from their file's tool name (e.g. `bbmap.nf`'s `pileup` →
  `params.pileup_outdir`), and the reference pipeline already defines them
  that way (`pileup_outdir`, `bbduk_outdir`, `filter_viral_contigs_outdir`).
  Corrected both docs; in-module `publishDir` processes are unchanged (they
  use whatever param their own line names).
- Flag: `publish_mode_intermediate` defaults to `'symlink'`, which points into
  the work dir — published links break if `cleanup = true` (the reference
  pipeline sets it) or work/ sits on 30-day-purged scratch. Kept as the
  default to match existing behavior, with a warning comment; worth deciding
  whether the template should default to `'copy'`.
- Next: open a PR; once merged, the BRC site's `parse_nextflow.py` can read
  the tier values from this file instead of anyone hand-copying them.
