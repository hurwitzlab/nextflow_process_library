# bcftools test fixtures

`unnormalized.vcf` -- input for `normalize_variants`. Three hand-written records against the shared
`tests/data/genome.fasta` (phiX174), each one something `bcftools norm -m -both` must change:

- `2000 G>A,C` (`AF=0.3,0.6`, `GT:AD 1/2:2,6,12`): multiallelic, so it splits into `G>A` and
  `G>C`, with `INFO/AF` (Number=A) and `FORMAT/AD` (Number=R) split along with the alleles
- `2436 TT>T`: deletes one T of the T7 run at 2431-2437 (`AAC TTTTTTT CTG`, 2428-2440), written at
  the run's right end; left-aligns to `2430 CT>C`
- `2437 T>TT`: inserts one T at the run's right end; left-aligns to `2430 C>CT`
