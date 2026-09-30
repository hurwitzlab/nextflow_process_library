#!/usr/bin/env nextflow

// Annotate a sample's predicted proteins with InterProScan
process interproscan {
    label "process_high"
    label "publish_final"
    container "${params.container__interproscan}"

    input:
        tuple val(sampleid), path(proteins)

    output:
        tuple val(sampleid), path("${proteins}.gff3"), emit: functional_annotation_gff3
        tuple val(sampleid), path("${proteins}.tsv"), emit: functional_annotation_tsv

    shell:
    '''
    /interproscan-5.61-93.0/interproscan.sh --input !{proteins} \
                      --formats tsv,gff3 \
                      --goterms \
                      --disable-precalc \
                      --cpu !{task.cpus}
    '''
}
