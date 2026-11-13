# nf-test patterns used in this repo

Each pattern comes from a test that passes in this repo (the path after the heading is the full
example); a few lines were added to show current practice, such as the tuple-size assertion in
pattern 1, which older tests don't have yet. Contents:

1. Basic per-sample process
2. Tool options via `params`
3. Pooled process (`pooledid`)
4. Another process's output as input (`setup`)
5. Failure test
6. Reading outputs: gzipped FASTQ, BAM/SAM, JSON, text with headers
7. Module-specific fixture, including one that must be decompressed first
8. Database-backed test (`needs_db`)
9. Holding back an assertion for a module bug

## 1. Basic per-sample process — `modules/samtools/tests/index.nf.test`

```groovy
nextflow_process {
    name "Test index"
    script "../samtools.nf"
    process "index"
    tag "samtools"
    tag "index"

    test("Indexes a coordinate-sorted BAM") {
        when {
            process {
                """
                input[0] = [ 'test_index', file("${baseDir}/tests/data/alignments.sorted.bam") ]
                """
            }
        }
        then {
            assert process.success

            assert process.out.indexed_alignment[0].size() == 3
            def (sampleid, bam_path, bai_path) = process.out.indexed_alignment[0]

            assert sampleid == 'test_index'
            assert bam_path.endsWith('alignments.sorted.bam')
            assert bai_path.endsWith('alignments.sorted.bam.bai')
            // same bytes as the fixture's index, built by tests/data/make_test_data.sh
            assert path(bai_path).md5 == path("${baseDir}/tests/data/alignments.sorted.bam.bai").md5
        }
    }
}
```

The script inside `process { """ ... """ }` is Nextflow code: `input[0]` is the first `input:`
element, `input[1]` the second. A tuple input is a Groovy list; a channel works too
(`Channel.of([...])`).

## 2. Tool options via `params` — `modules/bbmap/tests/bbwrap.nf.test`

`tests/nextflow.config` sets only containers and resources, so set every `params.*` the process
reads:

```groovy
        when {
            params {
                bbmap_kfilter = 22
                bbmap_subfilter = 15
                bbmap_maxindel = 80
            }
            process {
                """
                input[0] = [ 'test_bbwrap',
                             file("${baseDir}/tests/data/contigs.fasta"),
                             file("${baseDir}/tests/data/reads_R1.fastq.gz"),
                             file("${baseDir}/tests/data/reads_R2.fastq.gz") ]
                """
            }
        }
```

A params value that's missing shows up as the literal `null` in `.command.sh`.

## 3. Pooled process (`pooledid`) — `modules/bwa/tests/bwa_index.nf.test`

Processes whose output covers all samples (a catalog, a count table, a shared index) take
`tuple val(pooledid), path(...)`. A list of files for one `path()` is passed as a Groovy list:

```groovy
                input[0] = [ 'test_bwa_index', file("${baseDir}/tests/data/genome.fasta") ]
                // several files into one path(): [ 'test_pool', [ file(a), file(b) ] ]
```
```groovy
            assert process.out.indexed_sequence[0].size() == 3 // (pooledid, reference, index files)
            def (pooledid, reference, index_files) = process.out.indexed_sequence[0]
            assert pooledid == 'test_bwa_index'
```

## 4. Another process's output as input (`setup`) — `modules/bwa/tests/bwa_mem.nf.test`

Run the upstream process in `setup` instead of committing its output as a fixture; refer to its
output as `<process>.out.<emit>`. Use `script` with a relative path for a process in another module
(e.g. `"../../kraken2/kraken2.nf"`).

```groovy
    test("Aligns paired-end reads to the output of bwa_index") {
        setup {
            run("bwa_index") {
                script "../bwa.nf"
                process {
                    """
                    input[0] = [ 'test_bwa_index', file("${baseDir}/tests/data/genome.fasta") ]
                    """
                }
            }
        }
        when {
            process {
                """
                input[0] = Channel.of([ 'test_bwa_mem',
                                        file("${baseDir}/tests/data/reads_R1.fastq.gz"),
                                        file("${baseDir}/tests/data/reads_R2.fastq.gz") ])
                               // drop bwa_index's pooledid: bwa_mem takes (sampleid, r1, r2, index_prefix, index_files)
                               .combine(bwa_index.out.indexed_sequence.map { _id, ref, idx -> tuple(ref, idx) })
                """
            }
        }
```

## 5. Failure test — `modules/samtools/tests/index.nf.test`

```groovy
    test("Fails on a BAM that isn't coordinate-sorted") {
        when {
            process {
                """
                input[0] = [ 'test_index_unsorted', file("${baseDir}/tests/data/alignments.namesorted.bam") ]
                """
            }
        }
        then {
            assert process.failed
            // fails for the right reason: samtools refuses to index out-of-order records
            assert process.errorReport.contains('Unsorted positions')
        }
    }
```

Some tools exit 0 on error (bracken, VIBRANT). Then the process has to check for its own output;
if it doesn't, that's a module problem to report (see bracken's fix in `modules/bracken/bracken.nf`).

## 6. Reading outputs

**Gzipped FASTQ** — `modules/fastp/tests/trim_paired_end.nf.test`. Don't snapshot `.gz` md5s
(compression level and headers vary); read the records:

```groovy
            def r1 = path(r1_path).linesGzip.collate(4)   // [name, seq, +, qual] per read
            def r2 = path(r2_path).linesGzip.collate(4)
            assert r1.size() == r2.size()
            assert r1.collect { it[0].split()[0] - ~/\/1$/ } == r2.collect { it[0].split()[0] - ~/\/2$/ }
```

**JSON** — `path(json_path).json` gives a map: `stats.summary.before_filtering.total_reads == 420`.

**BAM/SAM** — the nft-bam plugin (loaded in `nf-test.config`) reads BAMs; snapshot SAM fields 1–11
only, since headers carry version-stamped `@PG` lines (`modules/samtools/tests/to_bam.nf.test`):

```groovy
            def reads = bam(bam_path).getSamLines()
            def fields = reads.collect { it.split('\t')[0..10].join('\t') }
            assert reads.size() == 420 // unmapped reads are kept
            assert snapshot(fields.join('\n').md5()).match()
```

For a SAM file use `path(sam_path).readLines().findAll { !it.startsWith('@') }`.

**Text with a header** (hmmer tblout, reports with dates or command lines): snapshot only the data
rows, e.g. `path(p).readLines().findAll { !it.startsWith('#') }`.

**A directory output**: `file(outdir).listFiles()`, or `path("${outdir}/<file>")` for one file
inside it.

## 7. Module-specific fixture — `modules/bcftools/tests/normalize_variants.nf.test`

```groovy
                input[0] = file("${moduleDir}/tests/testdata/unnormalized.vcf")
```

`${moduleDir}` is the directory of the script under test (`modules/<tool>/`). If the tool needs
the fixture uncompressed and you've committed it gzipped to keep the repo small, decompress it in
the test (`modules/busco/tests/busco_assess.nf.test`):

```groovy
        when {
            // The fixture is committed gzipped; BUSCO is given the plain fasta
            def genome = new File("${outputDir}/mgenitalium_G37.fna")
            genome.parentFile.mkdirs()
            genome.withOutputStream { out ->
                new java.util.zip.GZIPInputStream(new FileInputStream("${moduleDir}/tests/testdata/mgenitalium_G37.fna.gz")).withStream { out << it }
            }
            process {
                """
                input[0] = [ 'test_busco', file("${genome}") ]
                """
            }
        }
```

## 8. Database-backed test (`needs_db`) — `modules/vibrant/tests/vibrant.nf.test`

Real databases live on Hazel only. Pass the absolute path, and tag the test so it can be skipped
off Hazel:

```groovy
    tag "vibrant"
    // Needs the BRC VIBRANT databases (~11 GB) on /gpfs_backup, so it only runs on Hazel.
    tag "needs_db"
    ...
                input[1] = file("/gpfs_backup/bioinfo_data/databases/vibrant_db/v1.2.1/databases", type: 'dir')
```

Find BRC databases under `/rs1/shares/brc/admin/databases/`. If the real database needs more
than 12 GB of memory, build a tiny one from the shared data instead, as `tests/data/kraken2_db/`
does (ask first: it goes in `tests/data/`), or in `testdata/`.

## 9. Holding back an assertion for a module bug

Only after the user has chosen to keep the module as it is for now (see SKILL.md step 5):

```groovy
            // TODO(module bug): ont_read_accuracy runs `minimap2 -x ava-ont` without -c, so PAF
            // column 10 is a seed-chain count, not matching bases; identities come out ~0.47 for
            // reads simulated at ~91%. Once fixed, assert mean identity is between 0.85 and 0.95.
            assert rows.size() > 0
```
