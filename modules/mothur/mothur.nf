#!/usr/bin/env nextflow

// Generate ASVs and taxonomic assignments from paired-end 16S reads with mothur (see container for configurable read-length/region parameters)
process generate_asvs {
    label "process_low"
    label "publish_final"
    container "${params.container__mothur}"

    input:
        tuple val(sampleid), path(r1, stageAs: "r1.fastq.gz"), path(r2, stageAs: "r2.fastq.gz")
        path(alignment_refdb, stageAs: "silva.bacteria.fasta")
        path(taxa_refdb, stageAs: "trainset.pds.tgz")

    output:
        tuple val(sampleid), path("taxonomy.tsv"), emit: taxonomy
        tuple val(sampleid), path("table.tsv"), emit: count_table
        tuple val(sampleid), path("mothur.log"), emit: log_file

    shell:
    '''
    gunzip -f r1.fastq.gz > r1.fastq
    gunzip -f r2.fastq.gz > r2.fastq

    # unzip 16S reference dataset used for taxonomical assignment
    tar -xvf trainset.pds.tgz

    # run our custom shell script, which checks the environment for parameters and emits files at expected locations
    run_mothur.sh 2>&1 > mothur.log
    '''
}
