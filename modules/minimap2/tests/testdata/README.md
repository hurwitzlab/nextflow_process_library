# minimap2 test fixtures

- `ref.tar.gz` (2 KB) -- the shared phiX174 genome (`tests/data/genome.fasta`) packaged as
  `ref.fa`, the layout `align_to_index` expects. Made reproducibly with:

  ```bash
  cp tests/data/genome.fasta "$TMP/ref.fa"
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C "$TMP" -cf - ref.fa | gzip -n -9 > ref.tar.gz
  ```

- `chimeric_read.fastq` (4 KB) -- input for `ont_read_accuracy`'s split-read test. One 2000 bp
  read, `zz_chimera`, joined from two pieces of the shared phiX174 genome (`tests/data/genome.fasta`):
  - bases 1-1000: reference 500-1499 (1-based), exact
  - bases 1001-2000: reference 3500-4499 with a substitution at every 25th base starting at the
    13th (40 total, A→C, C→G, G→T, T→A), then reverse-complemented

  The inversion forces minimap2 to report the read as two `tp:A:P` pieces (primary + supplementary),
  with 1000/1000 and 960/1000 matches, so the summed identity is 1960/2000 = 0.98. (With both
  pieces on the forward strand, `map-ont` instead bridges them with one 2 kb deletion.) The name
  sorts after `phiX174`, which the old `ava-ont` preset silently filtered out. Quality is all `I`.
