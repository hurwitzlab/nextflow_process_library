# minimap2 test fixtures

- `ref.tar.gz` (2 KB) -- the shared phiX174 genome (`tests/data/genome.fasta`) packaged as
  `ref.fa`, the layout `align_to_index` expects. Made reproducibly with:

  ```bash
  cp tests/data/genome.fasta "$TMP/ref.fa"
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C "$TMP" -cf - ref.fa | gzip -n -9 > ref.tar.gz
  ```
