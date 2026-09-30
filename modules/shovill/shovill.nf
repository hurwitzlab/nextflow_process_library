#!/usr/bin/env nextflow

// Assemble paired-end reads into contigs with Shovill
process assemble {
    label "process_high"
    label "publish_final"
    container "${params.container__shovill}"

    input:
        tuple val(sampleid), path(r1), path(r2)

    output:
        tuple val(sampleid), path("out/contigs.fa"),                    emit: contigs
        tuple val(sampleid), path("out/contigs.gfa"),                   emit: assembly_graph
        tuple val(sampleid), path("out/flash.extendedFrags.fastq.gz"),  emit: merged_reads
        tuple val(sampleid), path("out/flash.notCombined_1.fastq.gz"),  emit: unmerged_r1
        tuple val(sampleid), path("out/flash.notCombined_2.fastq.gz"),  emit: unmerged_r2

    shell:
    '''
    shovill --outdir out --R1 !{r1} --R2 !{r2} --keepfiles
    '''
}
