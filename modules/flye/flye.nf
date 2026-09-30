#!/usr/bin/env nextflow

// Assemble a sample's PacBio HiFi reads with Flye
process flye_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__flye}"

    input:
        tuple val(sampleid), path(reads)

    output:
        tuple val(sampleid), path("${sampleid}_flye_out/assembly.fasta"), emit: assembled_contigs
        tuple val(sampleid), path("${sampleid}_flye_out/assembly_graph.gfa"), emit: assembly_graph
        tuple val(sampleid), path("${sampleid}_flye_out"), emit: assembly_results

    shell:
    '''
    flye --pacbio-hifi !{reads} -o !{sampleid}_flye_out --threads !{task.cpus}
    '''
}

// Assemble a sample's Nanopore metagenomic reads with Flye
process meta_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__flye}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(reads)

    output:
        tuple val(sampleid), path("${sampleid}_flye_out/assembly.fasta"), emit: assembled_contigs
        tuple val(sampleid), path("${sampleid}_flye_out/assembly_graph.gfa"), emit: assembly_graph
        tuple val(sampleid), path("${sampleid}_flye_out"), emit: assembly_results

    shell:
    '''
    flye --nano-raw !{reads} \
         --out-dir !{sampleid}_flye_out \
         --meta \
         --threads !{task.cpus}
    '''
}
