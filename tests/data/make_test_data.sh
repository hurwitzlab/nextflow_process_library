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
