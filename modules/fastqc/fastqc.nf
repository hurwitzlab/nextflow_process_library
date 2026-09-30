#!/usr/bin/env nextflow

// Run FastQC on a sample's paired reads, producing a report directory
// (fastqc can run out of memory without Nextflow catching the failure; keep this process's tier's
// retry/time policy in the pipeline's resource config to guard against that)
process fastqc {
    label "process_single"
    label "publish_final"
    container "${params.container__fastqc}"

    input:
        tuple val(sampleid), path(r1, stageAs: "R1.fastq.gz"), path(r2, stageAs: "R2.fastq.gz")

    output:
        tuple val(sampleid), path("${sampleid}_fastqc"), emit: fastqc_reports

    shell:
    '''
    mkdir !{sampleid}_fastqc
    fastqc !{r1} !{r2} --outdir=!{sampleid}_fastqc
    '''
}

// Run FastQC on a sample's single-end reads, producing a report directory
process fastqc_single_reads {
    label "process_single"
    label "publish_final"
    container "${params.container__fastqc}"

    input:
        tuple val(sampleid), path(r1, stageAs: "R1.fastq.gz")

    output:
        tuple val(sampleid), path("${sampleid}_fastqc"), emit: fastqc_reports

    shell:
    '''
    mkdir !{sampleid}_fastqc
    fastqc !{r1} --outdir=!{sampleid}_fastqc
    '''
}

// Run FastQC on a sample's unpaired reads, producing a single report zip (amplicon-sequencing use case)
process fastqc_unpaired_reads {
    label "process_low"
    label "publish_final"
    container "${params.container__fastqc}"

    input:
        tuple val(sampleid), path(unpaired_reads, stageAs: "unpaired_reads.fastq.gz")

    output:
        tuple val(sampleid), path("${sampleid}_fastqc/unpaired_reads_fastqc.zip"), emit: fastqc_report

    shell:
    '''
    mkdir !{sampleid}_fastqc
    fastqc !{unpaired_reads} \
           --nogroup \
           --noextract \
           --outdir=!{sampleid}_fastqc \
           --threads !{task.cpus}
    '''
}
