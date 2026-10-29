# cutadapt test data

`single_reads.fastq` (60 reads, plain text, ~19 KB) — input for `trim_single_fastq`, which stages
its input as an uncompressed `reads.fastq`. Built from the shared amplicon fixtures
(`tests/data/amplicon_R1/R2.fastq.gz`):

- `amp00/1` … `amp49/1`: the 50 amplicon R1 reads, each starting with the forward primer;
  the first 10 (`amp00/1` … `amp09/1`) are reverse-complemented (quality reversed), so they
  only match the anchored primer via `--revcomp`
- `amp00/2` … `amp09/2`: 10 amplicon R2 reads, which start with the reverse primer instead and
  so should land in `untrimmed.fastq`

```python
import gzip
comp = str.maketrans("ACGTN", "TGCAN")
recs = lambda p: (lambda l: [l[i:i + 4] for i in range(0, len(l), 4)])(gzip.open(p, "rt").read().splitlines())
r1, r2 = recs("tests/data/amplicon_R1.fastq.gz"), recs("tests/data/amplicon_R2.fastq.gz")
out = [[n, s.translate(comp)[::-1], p, q[::-1]] if i < 10 else [n, s, p, q] for i, (n, s, p, q) in enumerate(r1)]
out += r2[:10]
open("modules/cutadapt/tests/testdata/single_reads.fastq", "w").write("".join("\n".join(r) + "\n" for r in out))
```
