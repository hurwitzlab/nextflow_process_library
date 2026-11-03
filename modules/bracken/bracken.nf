#!/usr/bin/env nextflow

// Re-estimate species abundance from a kraken2 report with bracken
 process bracken {
    label "process_single"
    label "publish_final"
    container "${params.container__bracken}"

    input:
        tuple val(sampleid), path(kreport)
        path(kraken2_db)

    output:
        tuple val(sampleid), path("${sampleid}.bracken"), emit: abundance_table

    shell:
    '''
    bracken \
    -d !{kraken2_db} \
    -i !{kreport} \
    -o !{sampleid}.bracken \
    -r !{params.bracken_readlen}
    '''
}
