# busco test fixtures

- `mgenitalium_G37.fna.gz` (167 KB) -- *Mycoplasma genitalium* G37 complete genome, NCBI RefSeq
  `NC_000908.2` (one record, 580,076 bp, uses genetic code 4). One of the smallest free-living
  bacterial genomes, so BUSCO runs in about a minute against `bacteria_odb12.2`. Fetched 2026-11-05:
  `curl -sSfL "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_000908.2&rettype=fasta&retmode=text" | gzip -n -9 > mgenitalium_G37.fna.gz`
  (uncompressed md5 `ce986e553285eb7a36ca0519e0dfd34d`).
