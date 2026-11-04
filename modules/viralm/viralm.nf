#!/usr/bin/env nextflow

// Classify sequence fragments as viral/non-viral with ViraLM (DNABERT-2 based)
// viralm_db is the ViraLM model directory (not bundled in the image)
 process viralm {
    label "process_medium"
    label "publish_final"
    container "${params.container__viralm}"
    containerOptions '--nv'

    input:
        tuple val(sampleid), path(contigs)
        path(viralm_db)

    output:
        tuple val(sampleid), path("${sampleid}"), emit: classification

    shell:
    '''
    viralm \
    --input !{contigs} \
    --output !{sampleid} \
    --database !{viralm_db} \
    --len !{params.viralm_minlen} \
    --threshold !{params.viralm_threshold} \
    --threads !{task.cpus} \
    --force
    '''
}
