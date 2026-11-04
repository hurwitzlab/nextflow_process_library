#!/bin/bash
#SBATCH --job-name=make_test_data
#SBATCH --output=test_logs/%x_%j.out
#SBATCH --error=test_logs/%x_%j.err
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00

# make_test_data.sh -- (re)build the shared nf-test fixtures in tests/data/.
#
#   cd tests && sbatch data/make_test_data.sh
#
# 1. make_test_data.py writes the text/fastq fixtures (seeded, reproducible).
# 2. This script builds the fixtures that need real tools, using the same BRC images the tests
#    use (conf/containers_hazel.config): alignments (SAM/BAM) and bgzipped + tabix-indexed VCFs.
# Only rerun when the fixtures need to change; they're committed, and every snapshot depends on them.

set -euo pipefail

REPO="$(git -C "${SLURM_SUBMIT_DIR:-$(dirname "$0")}" rev-parse --show-toplevel)"
DATA="$REPO/tests/data"
cd "$DATA"

module load apptainer 2>/dev/null || true

image() {  # image() <tool> -> that tool's default image path from the Hazel container config
    sed -nE "s/^[[:space:]]*container__$1[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$REPO/conf/containers_hazel.config"
}
run() {  # run <tool> <command...> -- inside that tool's image, working in tests/data
    local img; img="$(image "$1")"; shift
    [[ -f "$img" ]] || { echo "ERROR: no image for that tool in conf/containers_hazel.config" >&2; exit 1; }
    apptainer exec --pwd "$DATA" "$img" "$@"
}

echo "== make_test_data.sh: job ${SLURM_JOB_ID:-local}, $(hostname), $(date)"
python3 "$DATA/make_test_data.py"

# --- Alignments: the shared paired-end reads aligned to phiX174 with bwa mem (single thread so
#     the output order is deterministic). The 10 random pairs stay unmapped. ---
TMP="$(mktemp -d "$DATA/.tmp.XXXX")"
trap 'rm -rf "$TMP"' EXIT
cp genome.fasta "$TMP/"
run bwa bwa index "${TMP#$DATA/}/genome.fasta" 2>/dev/null
run bwa bwa mem -t 1 "${TMP#$DATA/}/genome.fasta" reads_R1.fastq.gz reads_R2.fastq.gz 2>/dev/null \
    | grep -v '^@PG' > alignments.sam
run bwa bwa mem -t 1 "${TMP#$DATA/}/genome.fasta" reads_R1.fastq.gz 2>/dev/null \
    | grep -v '^@PG' > alignments_single_end.sam

run samtools samtools sort --no-PG -o alignments.sorted.bam alignments.sam
run samtools samtools index alignments.sorted.bam
run samtools samtools sort --no-PG -n -o alignments.namesorted.bam alignments.sam
run samtools samtools sort --no-PG -o alignments_single_end.sorted.bam alignments_single_end.sam
run samtools samtools faidx genome.fasta

# --- VCFs: bgzip + tabix (htslib, from the bcftools image) ---
for vcf in variants expected_variants variants_extra; do
    run bcftools bgzip -f -c "$vcf.vcf" > "$vcf.vcf.gz"
    run bcftools tabix -f -p vcf "$vcf.vcf.gz"
done

# --- kraken2 db: phiX174 only, with a 3-node hand-made taxonomy (root -> Viruses -> phiX174,
#     NCBI taxids 1 / 10239 / 10847), so kraken2 needs no NCBI taxonomy download. Only the three
#     .k2d files are needed to classify; taxonomy/ is kept as the build's source.
#     Note: opts.k2d has 5 bytes of uninitialized struct padding (offsets 34-38), so its md5 changes
#     on every rebuild; hash.k2d and taxo.k2d are byte-reproducible, and classification is identical. ---
K2="${TMP#$DATA/}/kraken2_db"
mkdir -p "$K2/taxonomy"
printf '1\t|\t1\t|\tno rank\t|\n10239\t|\t1\t|\tsuperkingdom\t|\n10847\t|\t10239\t|\tspecies\t|\n' \
    > "$K2/taxonomy/nodes.dmp"
printf '1\t|\troot\t|\t\t|\tscientific name\t|\n10239\t|\tViruses\t|\t\t|\tscientific name\t|\n10847\t|\tEscherichia virus phiX174\t|\t\t|\tscientific name\t|\n' \
    > "$K2/taxonomy/names.dmp"
sed '1s/^>.*/>phiX174|kraken:taxid|10847 phiX174/' genome.fasta > "$TMP/phiX174_taxid.fa"
run kraken2 kraken2-build --add-to-library "${TMP#$DATA/}/phiX174_taxid.fa" --db "$K2" --no-masking >/dev/null
run kraken2 kraken2-build --build --db "$K2" --threads 1 >/dev/null
# bracken's k-mer distribution for 100 bp reads (the shared reads' length); needs the library/ that
# only exists here in $TMP, and is all bracken reads from the db
run bracken bracken-build -d "$K2" -k 35 -l 100 -t 1 >/dev/null
rm -rf kraken2_db && mkdir -p kraken2_db/taxonomy
cp "$K2"/{hash,opts,taxo}.k2d "$K2"/database100mers.kmer_distrib kraken2_db/
cp "$K2"/taxonomy/{nodes,names}.dmp kraken2_db/taxonomy/

# --- Report what was built ---
echo "== alignments.sam: $(grep -vc '^@' alignments.sam) records, $(awk '!/^@/ && and($2, 4)' alignments.sam | wc -l) unmapped"
ls -l "$DATA"

# --- Helper binaries the audit flagged as "likely missing" from single-tool images ---
echo "== helper binaries per image (found / MISSING)"
for pair in bowtie2:samtools gatk:samtools gatk:bcftools gatk:bgzip gatk:tabix \
            minimap2:bgzip minimap2:tabix mummer:bgzip mummer:tabix mummer:delta2vcf \
            snpeff:bgzip snpeff:tabix bcftools:bgzip bcftools:tabix bcftools:perl \
            kraken2:python3 concoct:python busco:tar bwa:tar; do
    tool=${pair%%:*} bin=${pair#*:}
    if run "$tool" sh -c "command -v $bin" >/dev/null 2>&1; then echo "  $tool image: $bin found"
    else echo "  $tool image: $bin MISSING"; fi
done
echo "== done"
