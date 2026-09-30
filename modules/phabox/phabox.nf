#!/usr/bin/env nextflow

// Predict phage lifestyle (virulent/temperate) with phabox2's phatyp task
 process phatyp {
    label "process_high"
    container "${params.container__phabox}"
    // No sampleid here (runs over a whole viral-sequences fasta, not
    // per-sample) so the Closure-based publishDir convention doesn't apply
    // -- stays a plain path.
    publishDir "${params.phabox_outdir}", mode: 'copy'

    input:
        path(viral_seqs)
        path(phabox_db)

    output:
        path("phatyp_out"), emit: lifestyle_predictions

    shell:
    '''
    phabox2 \
    --task phatyp \
    --dbdir !{phabox_db} \
    --contigs !{viral_seqs} \
    --outpth phatyp_out
    '''
}
