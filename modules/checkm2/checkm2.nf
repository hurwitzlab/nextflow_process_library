#!/usr/bin/env nextflow

// Assess completeness and contamination of a sample's genome bins with CheckM2
process checkm2 {
    label "process_medium"
    label "publish_final"
    container "${params.container__checkm2}"

    input:
        tuple val(sampleid), path(genome_bins)

    output:
        tuple val(sampleid), path("${sampleid}/quality_report.tsv"), emit: quality_report

    shell:
    '''
    checkm2 predict -t !{task.cpus} -x fa --output-directory !{sampleid} --input !{genome_bins}/
    '''
}
