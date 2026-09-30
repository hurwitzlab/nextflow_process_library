#!/usr/bin/env nextflow

// Convert a name-sorted paired-end BAM into two FASTQ files
process bam_to_fastq {
    label "process_single"
    container "${params.container__bedtools}"

    input:
        tuple val(sampleid), path(bam_file) // paired-end BAM, must be sorted by name

    output:
        tuple val(sampleid), path("${sampleid}_R1.fastq"), emit: fastq_r1
        tuple val(sampleid), path("${sampleid}_R2.fastq"), emit: fastq_r2

    shell:
    '''
    bedtools bamtofastq -i !{bam_file} -fq !{sampleid}_R1.fastq -fq2 !{sampleid}_R2.fastq
    '''
}

