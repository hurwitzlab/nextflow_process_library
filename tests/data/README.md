# Shared test data

A small, self-consistent "mini world" built around one real genome, shared by every module's
nf-test tests. Reference it from a test as `file("${baseDir}/tests/data/<name>")`.

Data used by only one module goes in that module's own `modules/<tool>/tests/testdata/` instead.

**Don't edit these files by hand.** They're generated, and every snapshot depends on them:
`python3 tests/data/make_test_data.py` writes the text/FASTQ files (seeded, byte-reproducible),
and `cd tests && sbatch data/make_test_data.sh` reruns that and then builds the
alignment/BAM/VCF.gz files with the BRC images. Changing a fixture means re-checking the snapshots
of every test that uses it.

| File | What it is |
|---|---|
| `genome.fasta` (+ `.fai`) | Enterobacteria phage phiX174, 5386 bp, one record named `phiX174` (CP004084.1, from `/rs1/shares/brc/admin/databases/phiX174_virus.fa`) |
| `contigs.fasta` | phiX174 split into 3 contigs (`contig_1`–`contig_3`: 2500, 1800, 1086 bp) — a tiny "assembly" |
| `reads_R1/R2.fastq[.gz]` | 210 Illumina-like pairs, 2×100 bp: 200 from phiX174 (inserts 60–400 bp, ~0.5% errors, degraded 3' quality, TruSeq adapter read-through when insert < 100) + 10 random pairs that don't map. Read names `pair000/1` … |
| `adapters.fa` | The two TruSeq adapters used above |
| `amplicon_R1/R2.fastq.gz` | 50 pairs, 2×150 bp, over one 250 bp amplicon (phiX174:1001–1250); 50 bp overlap, so they merge |
| `amplicon_merged.fastq.gz` | 50 already-merged 250 bp amplicon reads |
| `amplicon_primers.txt` | The amplicon's forward primer and reverse primer (and its reverse complement) |
| `long_reads.fastq.gz` | 30 ONT-like reads, 500–3000 bp, ~5% substitutions + ~4% indels |
| `proteins.faa` | The 10 longest phiX174 ORFs (≥ 80 aa), translated (`prot_1` … `prot_10`) |
| `transcripts.fasta` | The same 10 ORFs as nucleotide sequences (`tx_1` … `tx_10`) |
| `alignments.sam` | `reads_R1/R2` aligned to `genome.fasta` with bwa mem: 420 records, 20 unmapped (the random pairs). No `@PG` lines |
| `alignments.sorted.bam` (+ `.bai`) | The same, coordinate-sorted |
| `alignments.namesorted.bam` | The same, name-sorted |
| `alignments_single_end.sam`, `alignments_single_end.sorted.bam` | `reads_R1` alone aligned single-end |
| `variants.vcf[.gz + .tbi]` | 3 SNVs on phiX174 (pos 100, 1500, 3000), sample `1`, `INFO/AF`, `FORMAT/GT:AD` |
| `expected_variants.vcf[.gz + .tbi]` | 2 SNVs (pos 100, 4000), sample `expected` |
| `variants_extra.vcf[.gz + .tbi]` | 1 SNV (pos 4500), sample `1` |
