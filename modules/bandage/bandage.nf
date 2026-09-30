#!/usr/bin/env nextflow

// Render a sample's assembly graph to an image with Bandage
process visualize_assembly {
    label "process_single"
    label "publish_final"
    container "${params.container__bandage}"

    input:
        tuple val(sampleid), path(gfa)

    output:
        tuple val(sampleid), path("${sampleid}.svg"), emit: assembly_graph_image

    shell:
    '''
    Bandage image !{gfa} !{sampleid}.svg
    '''
}
