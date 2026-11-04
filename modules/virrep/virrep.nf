#!/usr/bin/env nextflow

// Identify viral sequences from contigs with VirRep
// params.virrep_model: the image bundles one at /opt/VirRep/src/model/VirRep.pth
 process virrep {
    label "process_medium"
    label "publish_final"
    container "${params.container__virrep}"
    containerOptions '--nv'

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}"), emit: viral_inferences

    shell:
    '''
    export TORCH_COMPILE_DISABLE=1
    export TORCHINDUCTOR_DISABLE=1

    virrep \
    -i !{contigs} \
    -o !{sampleid} \
    --provirus-off \
    -l !{params.virrep_minlen} \
    -w !{params.virrep_window} \
    -m !{params.virrep_model}
    '''
}
