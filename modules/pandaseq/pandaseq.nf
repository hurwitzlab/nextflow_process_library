#!/usr/bin/env nextflow

// Merge overlapping paired-end reads into a single assembled read
process merge_fastqs {
    label "process_single"
    container "${params.container__pandaseq}"

    input:
        tuple val(sampleid), path(r1), path(r2)

    output:
        tuple val(sampleid), path("merged.fastq"), emit: merged_reads
        tuple val(sampleid), path("unaligned.fastq"), emit: unaligned_reads
        tuple val(sampleid), path("pandaseq.log"), emit: pandaseq_log

    shell:
    '''
    pandaseq -f !{r1} \
             -r !{r2} \
             -w merged.fastq \
             -u unaligned.fastq \
             -g pandaseq.log -F
    '''
}
