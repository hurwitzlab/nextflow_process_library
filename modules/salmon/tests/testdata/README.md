# salmon test fixtures

- `transcriptome_aligned.bam` (15 KB) -- input for `quantify_transcripts_aligned`: the shared reads
  (`tests/data/reads_R1/R2.fastq.gz`) aligned to `tests/data/transcripts.fasta` with `bwa mem`, then
  filtered to **proper pairs only** (`-f 2 -F 0x904`: both mates mapped concordantly, primary
  alignments): 130 pairs, 260 records, in bwa's output order (not coordinate-sorted), no `@PG` lines.

  The filter matters. Raw `bwa mem` output here includes 22 discordant pairs whose mates align to
  *different* transcripts (phiX174's genes overlap), and salmon 1.10.3 segfaults (exit 139) on that
  file. salmon's alignment mode expects concordant input, e.g. STAR `--quantMode TranscriptomeSAM`.

  Built with the bwa and samtools images from `conf/containers_hazel.config` (bwa 0.7.19,
  samtools 1.24); byte-reproducible:

  ```bash
  cp tests/data/transcripts.fasta "$TMP/tx.fa"
  apptainer exec "$BWA_IMAGE" bwa index "$TMP/tx.fa"
  apptainer exec "$BWA_IMAGE" bwa mem -t 1 "$TMP/tx.fa" tests/data/reads_R1.fastq.gz tests/data/reads_R2.fastq.gz \
      | grep -v '^@PG' \
      | apptainer exec "$SAMTOOLS_IMAGE" samtools view --no-PG -b -f 2 -F 0x904 -o transcriptome_aligned.bam -
  ```
