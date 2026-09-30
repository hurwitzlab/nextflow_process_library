#!/usr/bin/env nextflow

// Trim paired-end reads by quality with Sickle
process trim_paired_end {
    label "process_single"
    container "${params.container__sickle}"

    input:
        tuple val(sampleid), path(r1), path(r2)

    output:
        tuple val(sampleid), path("R1.trimmed.fq"),   emit: r1_trimmed
        tuple val(sampleid), path("R2.trimmed.fq"),   emit: r2_trimmed
        tuple val(sampleid), path("single_reads.fq"), emit: singles
        tuple val(sampleid), path("sickle.log"),      emit: trim_log

    shell:
    '''
    # Use short names only, otherwise this code segfaults
    # not sure if -t sanger is the correct choice, requires further testing
    sickle pe -f !{r1} -r !{r2} -t sanger -o R1.trimmed.fq -p R2.trimmed.fq -s single_reads.fq &> sickle.log
    '''
}
