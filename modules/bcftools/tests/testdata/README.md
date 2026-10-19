# bcftools test fixtures

- `variants_ad.vcf` -- `tests/data/variants.vcf` with each record's sample column written as
  `GT:AD` (e.g. `0/1:2,18`). The shared `variants*.vcf` files currently put AD in a stray 11th
  column (`0/1<TAB>2,18`), so bcftools reads AD as missing; `set_genotype` (`+setGT -n X`)
  needs real AD values. Made with:

  ```bash
  { zcat tests/data/variants.vcf.gz | grep '^##'
    printf '#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t1\n'
    zcat tests/data/variants.vcf.gz | grep -v '^#' \
      | awk -F'\t' -v OFS='\t' '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10":"$11}'
  } > modules/bcftools/tests/testdata/variants_ad.vcf
  ```
