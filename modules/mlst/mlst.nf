#!/usr/bin/env nextflow

// Call multi-locus sequence type (MLST) for a sample's assembled genome
process mlst {
    label "process_single"
    label "publish_final"
    container "${params.container__mlst}"

    input:
        tuple val(sampleid), path(genome)

    output:
        tuple val(sampleid), path("${sampleid}.mlst.txt"), emit: mlst_calls

    shell:
    '''
    mlst !{genome} > !{sampleid}.mlst.txt
    '''
}
