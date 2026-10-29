# 2026-10-19
Author: sweavs111

- Testability audit of the 52 module files that have a Hazel image (135 processes): 51 A
  (straightforward), 9 B (small fixture), 23 C (big db / assemblers / ML), 52 D (blocked). Most of
  the D's are real module bugs: hardcoded paths from old custom images (`/picard.jar`,
  `/snpEff/*.jar`, `/prokka-1.14.5/`, `/KrakenTools-master/`, interproscan 5.61), wrong command
  names for our own images (`DeepMicroClass2`, `ViraLM`, `dvf.py`, `../VIBRANT_run.py`), the
  missing `file_handler` helper, and quast's required `busco_stats`. Full table is on the Notion
  page "nf-test testability audit: image-backed processes" under Nextflow Meetings → Testing suite.
  The first counts reported (159 processes) came from the audit agents' own summaries and were
  wrong; a grep of the process blocks gives 135.
- Confirmed by `apptainer exec … command -v` in a compute job: samtools is missing from the bowtie2
  and gatk4 images; bgzip/tabix are missing from gatk4, minimap2, mummer4 and snpeff; mummer4 has
  no `delta2vcf`. bcftools/kraken2/concoct/busco/bwa have the helpers they need.
- Test data layout: one shared `tests/data/` (phiX174 genome + everything derived from it), plus
  per-module `tests/testdata/` for single-use inputs. Inputs overlap heavily (~15 tier-A processes
  take the genome, ~12 the PE reads, ~11 SAM/BAM), and the derived files stay consistent with
  each other (the BAMs are the shared reads aligned to the shared genome). `make_test_data.py`
  (seeded) + `make_test_data.sh` (bwa/samtools/bcftools images) rebuild everything
  byte-identically; checked by rebuilding and comparing md5s.
- Wrote tests for all 51 tier-A processes (52 tests). Full-suite job 1442889: 45 pass, 7 fail.
  Every failure has a confirmed cause:
  - Module bugs: bbmerge `outu1/outu2` makes bbtools 39.84 throw an AssertionError and then
    sometimes hang the JVM (it now hits the 15-min task cap instead of the job limit); cutadapt
    `paste -sd ""` isn't supported by the image's busybox; kreport_to_json writes `"\n"` inside a
    `'''` block, which Groovy turns into a real newline, so Python gets a SyntaxError.
  - Broken images: hmmer 3.1b2 (Debian) has no `ps`, which Nextflow tracing needs, so all 3 hmmer
    tests fail; salmon 1.11.4 dies with `locale::facet::_S_create_c_locale` for every locale
    setting tried (1.10.3 works).
- Tests that pass but leave a `TODO(module bug)` comment:
  - `bwa_index` emits only the FASTA, not the index files.
  - samtools `to_bam` indexes without sorting first.
  - minimap2 `ont_read_accuracy` runs `-x ava-ont` without `-c`, which reports about 0.47 identity
    for reads simulated at about 91%. Its snapshot was cut back to read names only, so the wrong
    values aren't frozen in.
  - jackhmmer_dir `hmms.tar.gz` is always empty, and its log is overwritten on every loop.
- Runner/config fixes:
  - `run_tests.sh` never ran `module load apptainer`; it had only worked because the submitting
    shell had apptainer loaded.
  - It requested 1 CPU, so every `process_low`+ task refused to start. Now `--cpus-per-task=4`
    and `--time=03:00:00`.
  - `tests/nextflow.config` now sets `env.TMPDIR=/tmp`. The submitting shell's TMPDIR
    (`/share/brc/$USER/tmp`) isn't mounted in containers, which broke mafft, prokka and bbnorm.
    Real pipelines on Hazel will hit the same thing.
  - Each task is capped at `time = 15.min`.
- Other findings:
  - My VCF fixtures first put AD in a stray 11th column; fixed and rebuilt.
  - Prokka 1.15.6 needs ≥20 kb even with `--metagenome` (a precedence bug in prokka itself), so
    those tests concatenate 4 copies of phiX to make a big enough input.
  - Only 1 CPU per xfer job queues jobs one after another, and the whole suite takes ~20 min.
- Next:
  - Fix the 3 module bugs and swap the hmmer/salmon images, which would make all 52 pass.
  - Then work through the cheap D-tier fixes from the audit.
  - Consider `env.TMPDIR` / a `-B /share` bind in `templates/base.config` for pipelines.
