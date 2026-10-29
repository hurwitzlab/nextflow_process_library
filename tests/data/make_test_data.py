#!/usr/bin/env python3
"""Generate the shared nf-test fixtures in tests/data/ from tests/data/genome.fasta (phiX174).

Pure Python and seeded, so rerunning it reproduces the same files byte-for-byte (gzip with
mtime=0). Alignment/BAM/VCF.gz fixtures need real tools and are built afterwards by
make_test_data.sh, which calls this script first.

Usage (from the repo root):  python3 tests/data/make_test_data.py
"""
import gzip
import random
from pathlib import Path

DATA = Path(__file__).resolve().parent
SEED = 20261019

# Illumina TruSeq adapters, as they appear at the 3' end of R1 / R2 on read-through
ADAPTER_R1 = "AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC"
ADAPTER_R2 = "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTA"

# Amplicon: phiX174 positions 1000-1249 (250 bp); primers are its first 20 bp and the reverse
# complement of its last 20 bp
AMPLICON_START, AMPLICON_LEN, PRIMER_LEN = 1000, 250, 20

COMP = str.maketrans("ACGTN", "TGCAN")
CODON = {}
for i, a in enumerate("FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG"):
    CODON["TCAG"[i // 16] + "TCAG"[(i // 4) % 4] + "TCAG"[i % 4]] = a


def revcomp(s):
    return s.translate(COMP)[::-1]


def read_fasta(path):
    name, seq = None, []
    for line in Path(path).read_text().splitlines():
        if line.startswith(">"):
            name = line[1:].split()[0]
        else:
            seq.append(line.strip().upper())
    return name, "".join(seq)


def fasta(records, width=70):
    out = []
    for name, seq in records:
        out.append(f">{name}")
        out.extend(seq[i:i + width] for i in range(0, len(seq), width))
    return "\n".join(out) + "\n"


def fastq(records):
    return "".join(f"@{n}\n{s}\n+\n{q}\n" for n, s, q in records)


def write(name, text):
    (DATA / name).write_text(text)


def write_gz(name, text):
    with open(DATA / name, "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as gz:
        gz.write(text.encode())


def mutate(rng, seq, sub_rate, indel_rate=0.0):
    out = []
    for base in seq:
        r = rng.random()
        if r < indel_rate / 2:
            continue                                  # deletion
        if r < indel_rate:
            out.append(base + rng.choice("ACGT"))     # insertion
        elif r < indel_rate + sub_rate:
            out.append(rng.choice([b for b in "ACGT" if b != base]))
        else:
            out.append(base)
    return "".join(out)


def illumina_quality(rng, length):
    # High quality with a degrading 3' tail, so quality trimmers have something to trim
    return "".join("I" if i < length - 15 else rng.choice("I?5+#") for i in range(length))


def orfs(genome, min_aa):
    """ATG..stop ORFs on both strands of the circular-free (linear) genome, longest first."""
    found = []
    for strand, seq in (("+", genome), ("-", revcomp(genome))):
        for frame in range(3):
            prot, start = [], None
            for i in range(frame, len(seq) - 2, 3):
                aa = CODON.get(seq[i:i + 3], "X")
                if start is None and aa == "M":
                    start, prot = i, []
                if start is not None:
                    if aa == "*":
                        if len(prot) >= min_aa:
                            found.append((len(prot), strand, start, seq[start:i + 3], "".join(prot)))
                        start = None
                    else:
                        prot.append(aa)
    found.sort(key=lambda o: (-o[0], o[1], o[2]))
    return found


def main():
    rng = random.Random(SEED)
    name, genome = read_fasta(DATA / "genome.fasta")
    assert name == "phiX174" and len(genome) == 5386, "tests/data/genome.fasta should be phiX174 (5386 bp)"

    # --- contigs: phiX split into 3 pieces (a tiny "assembly") ---
    cuts = [0, 2500, 4300, len(genome)]
    write("contigs.fasta", fasta([(f"contig_{i + 1}", genome[a:b]) for i, (a, b) in enumerate(zip(cuts, cuts[1:]))]))

    # --- paired-end reads: 200 phiX pairs (2x100, inserts 60-400; inserts under 100 read
    #     through into adapter) + 10 random pairs that won't map ---
    r1s, r2s = [], []
    for n in range(200):
        insert = rng.randint(60, 400)
        start = rng.randint(0, len(genome) - insert)
        frag = genome[start:start + insert]
        if rng.random() < 0.5:
            frag = revcomp(frag)
        r1 = (frag + ADAPTER_R1 + "A" * 100)[:100]
        r2 = (revcomp(frag) + ADAPTER_R2 + "A" * 100)[:100]
        r1s.append((f"pair{n:03d}/1", mutate(rng, r1, 0.005), illumina_quality(rng, 100)))
        r2s.append((f"pair{n:03d}/2", mutate(rng, r2, 0.005), illumina_quality(rng, 100)))
    for n in range(200, 210):
        r1s.append((f"pair{n:03d}/1", "".join(rng.choice("ACGT") for _ in range(100)), illumina_quality(rng, 100)))
        r2s.append((f"pair{n:03d}/2", "".join(rng.choice("ACGT") for _ in range(100)), illumina_quality(rng, 100)))
    for suffix, records in (("R1", r1s), ("R2", r2s)):
        write(f"reads_{suffix}.fastq", fastq(records))
        write_gz(f"reads_{suffix}.fastq.gz", fastq(records))
    write("adapters.fa", fasta([("TruSeq_R1", ADAPTER_R1), ("TruSeq_R2", ADAPTER_R2)]))

    # --- amplicon reads: 50 pairs of 2x150 over one 250 bp amplicon (50 bp overlap, so they
    #     merge), each starting with its primer ---
    amplicon = genome[AMPLICON_START:AMPLICON_START + AMPLICON_LEN]
    a1s, a2s, merged = [], [], []
    for n in range(50):
        q = illumina_quality(rng, 150)
        a1s.append((f"amp{n:02d}/1", mutate(rng, amplicon[:150], 0.002), q))
        a2s.append((f"amp{n:02d}/2", mutate(rng, revcomp(amplicon)[:150], 0.002), q))
        merged.append((f"amp{n:02d}", mutate(rng, amplicon, 0.002), "I" * AMPLICON_LEN))
    write_gz("amplicon_R1.fastq.gz", fastq(a1s))
    write_gz("amplicon_R2.fastq.gz", fastq(a2s))
    write_gz("amplicon_merged.fastq.gz", fastq(merged))
    write("amplicon_primers.txt",
          f"forward\t{amplicon[:PRIMER_LEN]}\nreverse_complement_of_3prime\t{amplicon[-PRIMER_LEN:]}\n"
          f"reverse_primer\t{revcomp(amplicon[-PRIMER_LEN:])}\n")

    # --- long reads: 30 ONT-like reads, 500-3000 bp, ~5% substitutions + ~4% indels ---
    longs = []
    for n in range(30):
        length = rng.randint(500, 3000)
        start = rng.randint(0, len(genome) - length)
        seq = genome[start:start + length]
        if rng.random() < 0.5:
            seq = revcomp(seq)
        seq = mutate(rng, seq, 0.05, 0.04)
        longs.append((f"ont{n:02d}", seq, "".join(rng.choice("+,-./0123456789:;") for _ in seq)))
    write_gz("long_reads.fastq.gz", fastq(longs))

    # --- proteins / transcripts: the 10 longest phiX ORFs ---
    top = orfs(genome, 80)[:10]
    write("proteins.faa", fasta([(f"prot_{i + 1}", o[4]) for i, o in enumerate(top)]))
    write("transcripts.fasta", fasta([(f"tx_{i + 1}", o[3]) for i, o in enumerate(top)]))

    # --- VCFs on phiX174 (bgzipped + indexed by make_test_data.sh). Sample "1" is what the
    #     bcftools module assumes is the real sample. ---
    header = ("##fileformat=VCFv4.2\n##contig=<ID=phiX174,length=5386>\n"
              '##INFO=<ID=AF,Number=A,Type=Float,Description="Allele frequency">\n'
              '##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">\n'
              '##FORMAT=<ID=AD,Number=R,Type=Integer,Description="Allelic depths">\n')

    def snv(pos, alt_of, af, gt, ad):
        ref = genome[pos - 1]
        alt = alt_of(ref)
        return f"phiX174\t{pos}\t.\t{ref}\t{alt}\t50\tPASS\tAF={af}\tGT:AD\t{gt}:{ad}\n"

    transition = {"A": "G", "G": "A", "C": "T", "T": "C"}.get
    transversion = {"A": "C", "C": "A", "G": "T", "T": "G"}.get
    cols = "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t{}\n"
    write("variants.vcf", header + cols.format("1")
          + snv(100, transition, 0.9, "0/1", "2,18")
          + snv(1500, transversion, 0.4, "0/1", "12,8")
          + snv(3000, transition, 1.0, "1/1", "0,20"))
    write("expected_variants.vcf", header + cols.format("expected")
          + snv(100, transition, 1.0, "1/1", "0,20")
          + snv(4000, transversion, 1.0, "1/1", "0,20"))
    write("variants_extra.vcf", header + cols.format("1")
          + snv(4500, transition, 0.8, "0/1", "4,16"))


if __name__ == "__main__":
    main()
