#!/usr/bin/env nextflow

// Classify paired reads taxonomically with kraken2
 process kraken2 {
    label "process_high"
    label "publish_final"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(clean_r1), path(clean_r2)
        path(kraken2_db)

    output:
        tuple val(sampleid), path("${sampleid}.kreport"), path("${sampleid}.kraken"), emit: classification

    shell:
    '''
    kraken2 \
    --db !{kraken2_db} \
    --threads !{task.cpus} \
    --report !{sampleid}.kreport \
    --paired !{clean_r1} !{clean_r2} \
    > !{sampleid}.kraken
    '''
}

// Classify paired-end reads taxonomically with kraken2 to identify contamination
process read_contamination {
    label "process_high"
    label "publish_final"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(r1), path(r2)
        val(kraken_db)

    output:
        tuple val(sampleid), path("${sampleid}.kraken_results.txt"), emit: classification_results
        tuple val(sampleid), path("${sampleid}.kreport.txt"), emit: classification_report

    shell:
    '''
    file_handler !{kraken_db}

    kraken2 --db !{kraken_db} \
        --paired \
        --classified-out cseqs#.fq \
        --output !{sampleid}.kraken_results.txt \
        --report !{sampleid}.kreport.txt \
        --use-names \
        --threads !{task.cpus} \
        !{r1} !{r2}
    '''
}

// Classify single-end reads taxonomically with kraken2
process single_end_read_classification {
    label "process_high"
    label "publish_final"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(r1)
        val(kraken_db)

    output:
        tuple val(sampleid), path("${sampleid}.kraken_results.txt"), emit: classification_results
        tuple val(sampleid), path("${sampleid}.kreport.txt"), emit: classification_report

    shell:
    '''
    file_handler !{kraken_db}

    kraken2 --db !{kraken_db} \
        --classified-out cseqs#.fq \
        --output !{sampleid}.kraken_results.txt \
        --report !{sampleid}.kreport.txt \
        --use-names \
        --threads !{task.cpus} \
        !{r1}
    '''
}

// Select paired-end reads matching a set of Kraken taxids (and their children)
process paired_end_read_selector {
    label "process_single"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(r1), path(r2), path(kraken_results), path(kraken_report)
        val(taxids)

    output:
        tuple val(sampleid), path("${sampleid}.selected_R1.fastq.gz"), emit: selected_r1
        tuple val(sampleid), path("${sampleid}.selected_R2.fastq.gz"), emit: selected_r2

    shell:
    '''
    python3 /KrakenTools-master/extract_kraken_reads.py \
    -k !{kraken_results} \
    --report !{kraken_report} \
    -s1 !{r1} \
    -s2 !{r2} \
    --taxid !{taxids.join(" ")} \
    --output !{sampleid}.selected_R1.fastq \
    --output2 !{sampleid}.selected_R2.fastq \
    --include-children \
    --fastq-output > /dev/null

    # Some downstream tools expect gzipped fastqs, compress to save space and for ease
    gzip !{sampleid}.selected_R1.fastq
    gzip !{sampleid}.selected_R2.fastq
    '''
}

// Exclude paired-end reads matching a set of Kraken taxids (and their children)
process paired_end_read_excluder {
    label "process_single"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(r1), path(r2), path(kraken_results), path(kraken_report)
        val(taxids)

    output:
        tuple val(sampleid), path("${sampleid}.excluded_R1.fastq.gz"), emit: excluded_r1
        tuple val(sampleid), path("${sampleid}.excluded_R2.fastq.gz"), emit: excluded_r2

    shell:
    '''
    python3 /KrakenTools-master/extract_kraken_reads.py \
    -k !{kraken_results} \
    --report !{kraken_report} \
    -s1 !{r1} \
    -s2 !{r2} \
    --taxid !{taxids.join(" ")} \
    --output !{sampleid}.excluded_R1.fastq \
    --output2 !{sampleid}.excluded_R2.fastq \
    --include-children \
    --exclude \
    --fastq-output > /dev/null

    # Some downstream tools expect gzipped fastqs, compress to save space and for ease
    gzip !{sampleid}.excluded_R1.fastq
    gzip !{sampleid}.excluded_R2.fastq
    '''
}

// Select single-end reads matching a set of Kraken taxids (and their children)
process single_end_read_selector {
    label "process_single"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(r1), path(kraken_results), path(kraken_report)
        val(taxids)

    output:
        tuple val(sampleid), path("${sampleid}.selected_R1.fastq.gz"), emit: selected_r1

    shell:
    '''
    python3 /KrakenTools-master/extract_kraken_reads.py \
    -k !{kraken_results} \
    --report !{kraken_report} \
    -s1 !{r1} \
    --taxid !{taxids.join(" ")} \
    --output !{sampleid}.selected_R1.fastq \
    --include-children \
    --fastq-output > /dev/null

    # Some downstream tools expect gzipped fastqs, compress to save space and for ease
    gzip !{sampleid}.selected_R1.fastq
    '''
}

// Exclude single-end reads matching a set of Kraken taxids (and their children)
process single_end_read_excluder {
    label "process_single"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(r1), path(kraken_results), path(kraken_report)
        val(taxids)

    output:
        tuple val(sampleid), path("${sampleid}.excluded_R1.fastq.gz"), emit: excluded_r1

    shell:
    '''
    python3 /KrakenTools-master/extract_kraken_reads.py \
    -k !{kraken_results} \
    --report !{kraken_report} \
    -s1 !{r1} \
    --taxid !{taxids.join(" ")} \
    --output !{sampleid}.excluded_R1.fastq \
    --include-children \
    --exclude \
    --fastq-output > /dev/null

    # Some downstream tools expect gzipped fastqs, compress to save space and for ease
    gzip !{sampleid}.excluded_R1.fastq
    '''
}

// Convert a kreport to line-delimited JSON for loading into an Athena table
process kreport_to_json {
    label "process_single"
    label "publish_final"
    container "${params.container__kraken2}"

    input:
        tuple val(sampleid), path(kreport)

    output:
        tuple val(sampleid), path("${sampleid}.json"), emit: kreport_json

    shell:
    '''
    python3 <<'PYEOF'
import csv
import json

header = ["percent_reads", "rooted_reads", "tax_reads", "rank_code", "tax_id", "scientific_name"]
with open("!{kreport}") as handle, open("!{sampleid}.json", "w") as out_handle:
    for line in csv.reader(handle, delimiter="\t", skipinitialspace=True):
        # Writes each line as its own JSON formatted dict
        # This is invalid json, but its what athena ingests
        out_handle.write(json.dumps(dict(zip(header, line))) + "\n")
PYEOF
    '''
}
