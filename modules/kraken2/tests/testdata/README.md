# kraken2 test fixtures

- `test.kreport` -- a hand-written 8-line kraken2 report (standard 6-column format: percent,
  clade reads, taxon reads, rank code, taxid, indented name) for a 50-read sample: 10
  unclassified, 40 assigned to Escherichia phage phiX174 (taxid 10847) with its lineage
  root > Viruses > Duplodnaviria > Phixviricota > Microviridae > Sinsheimervirus.
  Percent column is space-padded and names are space-indented, as kraken2 writes them.
