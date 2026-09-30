#!/usr/bin/env nextflow

// Predict prokaryotic hosts for viral sequences with iphop
 process iphop {
    label "process_high"
    container "${params.container__iphop}"
    publishDir "${params.iphop_outdir}", mode: 'copy'

    input:
        path(viral_seqs)
        path(iphop_db)

    output:
        path("predictions"), emit: host_predictions

    shell:
    '''
    iphop predict \
    --fa_file !{viral_seqs} \
    --db_dir !{iphop_db} \
    --out_dir predictions
    '''
}
