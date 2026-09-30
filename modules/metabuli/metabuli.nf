#!/usr/bin/env nextflow

// Classify contigs taxonomically with metabuli
 process metabuli {
    label "process_high"
    label "publish_final"
    container "${params.container__metabuli}"

    input:
        tuple val(sampleid), path(contigs)
        path(metabuli_db)

    output:
        tuple val(sampleid), path("${sampleid}_report.tsv"), emit: classification

    shell:
    '''
    metabuli classify \
    --seq-mode 1 \
    !{contigs} \
    !{metabuli_db} \
    . \
    !{sampleid} \
    --min-score !{params.metabuli_minscore} \
    --min-sp-score !{params.metabuli_minspscore}
    '''
}
