#!/usr/bin/env nextflow

// Predict virus lifestyle (e.g. lytic, temperate) from a set of predicted proteins
process lifestyle {
    label "process_single"
    label "publish_final"
    container "${params.container__phacts}"

    input:
        tuple val(sampleid), path(proteins)

    output:
        tuple val(sampleid), path("lifestyle.txt"), emit: lifestyle_prediction

    shell:
    '''
    phacts.pl --file !{proteins} -c /PHACTS/classes_lifestyle > lifestyle.txt
    '''
}
