# mafft test fixtures

- `homologs.faa` -- four unaligned homologs of `prot_10` from `tests/data/proteins.faa` (86 aa):
  `prot_10` itself; `prot_10_var1` (substitutions D5E, R20K, N40Q, G60A, Q80E); `prot_10_var2`
  (Y15F, K45V, S75T, plus residues 30-33 `DALD` deleted -> 82 aa); `prot_10_var3` (R10K, L25I,
  R50F, G70S). Hand-designed point edits (no randomness), written wrapped at 60 columns.
  The same family is used as `modules/hmmer/tests/testdata/prot_10_family.sto` (aligned) and in
  `protein_db.faa.gz` there.
