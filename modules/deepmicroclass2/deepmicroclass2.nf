#!/usr/bin/env nextflow

// Classify sequence fragments (virus/plasmid/chromosome/etc) with DeepMicroClass2
// params.deepmicroclass2_model is a model type: 8class (recommended), 300bp or high_precision
 process deepmicroclass2 {
    label "process_high"
    label "publish_final"
    container "${params.container__deepmicroclass2}"
    containerOptions '--nv'

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}"), emit: classification

    shell:
    '''
    deepmicroclass2 \
    --contig !{contigs} \
    --out_dir !{sampleid} \
    --model !{params.deepmicroclass2_model}
    '''
}
