# seqkit test fixtures

- `with_duplicates.faa` -- `prot_8`, `prot_9`, `prot_10` from `tests/data/proteins.faa` (with a
  description added to each header) plus `prot_8_copy` and `prot_9_copy`, exact sequence
  duplicates of `prot_8`/`prot_9`. Order: prot_8, prot_9, prot_8_copy, prot_10, prot_9_copy.
  Written by hand from the shared file (sequence lines copied verbatim).
