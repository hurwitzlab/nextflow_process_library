# hmmer test fixtures

All derived from `tests/data/proteins.faa` and `modules/mafft/tests/testdata/homologs.faa`
(prot_10 plus three hand-edited variants; see that README for the edits).

- `prot_10.faa` -- the `prot_10` record from `homologs.faa` (single query for `jackhmmer_seq`).
- `prot_10_family.sto` -- the four `homologs.faa` sequences as a hand-made Stockholm MSA, with the
  4-residue deletion in `prot_10_var2` gapped (`----`) at columns 30-33. Input for `hmmbuild`.
- `protein_db.faa.gz` (1.3 KB) -- the search database (the modules `gzip -dc` it):
  `tests/data/proteins.faa` + `prot_10_var1..3`, i.e. 13 proteins.
  `cat tests/data/proteins.faa <(awk '/^>/{p=($1!=">prot_10")} p' modules/mafft/tests/testdata/homologs.faa) | gzip -n -9 > protein_db.faa.gz`
- `queries.tar.gz` (0.5 KB) -- query tarball for `jackhmmer_dir`, containing `./prot_1.faa`
  (`prot_1` from `tests/data/proteins.faa`) and `./prot_10.faa` (the file above). Built
  reproducibly from a directory `q/` holding those two files:
  `tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C q -cf - . | gzip -n -9 > queries.tar.gz`
