# bwa test fixtures

- `ref_index.tar.gz` (9 KB) -- input for `bwa_align_to_index`: the shared phiX174 genome
  (`tests/data/genome.fasta`) as `ref.fa` plus its bwa index (`ref.fa.amb .ann .bwt .pac .sa`), all
  at the top level of the archive, the layout the process expects. Built with the bwa image from
  `conf/containers_hazel.config` (0.7.19); byte-reproducible:

  ```bash
  cp tests/data/genome.fasta "$TMP/ref.fa"
  apptainer exec "$BWA_IMAGE" bwa index "$TMP/ref.fa"
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C "$TMP" -cf - \
      ref.fa ref.fa.amb ref.fa.ann ref.fa.bwt ref.fa.pac ref.fa.sa | gzip -n -9 > ref_index.tar.gz
  ```

- `nested_ref.tar.gz` (2 KB) -- a wrong-layout input for `bwa_align_to_index`'s failure test:
  `tests/data/genome.fasta` as `ref/ref.fa`, i.e. inside a subdirectory instead of at the top level.

  ```bash
  mkdir "$TMP/ref" && cp tests/data/genome.fasta "$TMP/ref/ref.fa"
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C "$TMP" -cf - ref | gzip -n -9 > nested_ref.tar.gz
  ```

The failure tests also reuse `modules/minimap2/tests/testdata/ref.tar.gz` (`ref.fa` only, no index).
