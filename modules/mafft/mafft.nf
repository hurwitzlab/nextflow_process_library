#!/usr/bin/env nextflow

// Align sequences in a fasta file using MAFFT L-INS-i
process mafft_linsi {
    label "process_low"
    container "${params.container__mafft}"
    publishDir "${params.mafft_outdir}", mode: 'copy'

    input:
        path(in_fasta)

    output:
        path("aligned.fasta"), emit: aligned_fasta

    shell:
    '''
    linsi \
    --thread !{task.cpus} \
    !{in_fasta} > aligned.fasta
    '''
}
