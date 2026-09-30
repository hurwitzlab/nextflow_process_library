#!/usr/bin/env nextflow

// Bin contigs by coverage and sequence composition using MetaDecoder
process metadecoder_bin_contigs {
    label "process_medium"
    label "publish_final"
    container "${params.container__metadecoder}"

    input:
        tuple val(sampleid), path(contigs, stageAs: "assembly.fasta"), path(bam)

    output:
        tuple val(sampleid), path("fasta_bins"), emit: fasta_bins
        tuple val(sampleid), path("bin_names.json"), emit: bin_manifest
        tuple val(sampleid), path("coverage.txt"), emit: coverage
        tuple val(sampleid), path("seed.txt"), emit: seed
        tuple val(sampleid), path("assembly.fasta.2500.metadecoder.dpgmm"), emit: dpgmm
        tuple val(sampleid), path("assembly.fasta.2500.metadecoder.kmers"), emit: kmers

    shell:
    '''
    samtools view -h !{bam} > sample.sam
    metadecoder coverage --sam sample.sam --output coverage.txt --threads !{task.cpus}
    metadecoder seed --fasta !{contigs} --output seed.txt --threads !{task.cpus}

    metadecoder cluster --fasta !{contigs} --coverage coverage.txt --seed seed.txt --output bins

    # Remove sam tmp file because it takes up so much space
    rm sample.sam

    mkdir fasta_bins
    mv bins.*.fasta fasta_bins
    python -c 'import os, json; print(json.dumps({x: value for x, value in enumerate(os.listdir("fasta_bins"))}))' > bin_names.json
    '''
}
