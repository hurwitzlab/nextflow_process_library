#!/usr/bin/env nextflow

// Quality-trim a sample's paired-end reads with fastp
process trim_paired_end {
    label "process_medium"
    label "publish_final"
    container "${params.container__fastp}"

    input:
        tuple val(sampleid), path(r1), path(r2)

    output:
        tuple val(sampleid), path("${sampleid}_R1.trimmed.fq.gz"), path("${sampleid}_R2.trimmed.fq.gz"), emit: trimmed_reads
        tuple val(sampleid), path("${sampleid}_single_reads.fq.gz"), emit: unpaired_reads
        tuple val(sampleid), path("${sampleid}_fastp.html"), emit: html_report
        tuple val(sampleid), path("${sampleid}_fastp.json"), emit: json_report

    shell:
    '''
    fastp --in1 !{r1} \
          --in2 !{r2} \
          --out1 !{sampleid}_R1.trimmed.fq.gz \
          --out2 !{sampleid}_R2.trimmed.fq.gz \
          --unpaired1 !{sampleid}_single_reads.fq.gz \
          --unpaired2 !{sampleid}_single_reads.fq.gz \
          --html !{sampleid}_fastp.html \
          --json !{sampleid}_fastp.json \
          --detect_adapter_for_pe \
          --trim_poly_g \
          --poly_g_min_len 10 \
          --correction \
          --cut_front \
          --cut_tail \
          --cut_mean_quality 20 \
          --cut_window_size 10 \
          --length_required 50
    '''
}

// Quality-trim a sample's single-end reads with fastp
process trim_single_end {
    label "process_medium"
    label "publish_final"
    container "${params.container__fastp}"

    input:
        tuple val(sampleid), path(r1)

    output:
        tuple val(sampleid), path("${sampleid}_R1.trimmed.fq.gz"), emit: trimmed_reads
        tuple val(sampleid), path("${sampleid}_fastp.html"), emit: html_report
        tuple val(sampleid), path("${sampleid}_fastp.json"), emit: json_report

    shell:
    '''
    fastp --in1 !{r1} \
          --out1 !{sampleid}_R1.trimmed.fq.gz \
          --html !{sampleid}_fastp.html \
          --json !{sampleid}_fastp.json \
          --detect_adapter_for_pe \
          --trim_poly_g \
          --poly_g_min_len 10 \
          --cut_front \
          --cut_tail \
          --cut_mean_quality 20 \
          --cut_window_size 10 \
          --length_required 50
    '''
}
