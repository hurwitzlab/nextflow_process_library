#!/usr/bin/env nextflow

// Evaluate bacterial defense mechanisms with defense-finder
process find_defenses {
    label "process_low"
    label "publish_final"
    container "${params.container__defensefinder}"

    input:
        tuple val(sampleid), path(protein_sequences)

    output:
        tuple val(sampleid), path("df_out/defense_finder_hmmer.tsv"), emit: hmmer_hits
        tuple val(sampleid), path("df_out/defense_finder_systems.tsv"), emit: defense_systems
        tuple val(sampleid), path("df_out/defense_finder_genes.tsv"), emit: defense_genes

    shell:
    '''
    defense-finder run !{protein_sequences} \
            -o df_out
    '''
}
