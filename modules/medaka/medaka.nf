#!/usr/bin/env nextflow

// Polish a draft assembly using nanopore reads with Medaka
process medaka_polish_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__medaka}"

    input:
        tuple val(sampleid), path(reads), path(draft_assembly)

    output:
        tuple val(sampleid), path("${sampleid}/consensus.fasta"), emit: polished_assembly
        tuple val(sampleid), path("${sampleid}"), emit: results

    shell:
    '''
    medaka_consensus -i !{reads} -d !{draft_assembly} -o !{sampleid} -m !{params.medaka_basecall_model} -t !{task.cpus}
    '''
}
