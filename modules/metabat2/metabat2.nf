#!/usr/bin/env nextflow

// Bin contigs by tetranucleotide frequency and coverage using MetaBAT2
process metabat2_bin {
    label "process_medium"
    label "publish_final"
    container "${params.container__metabat2}"

    input:
        tuple val(sampleid), path(contigs, stageAs: "assembly.fasta"), path(bam)

    output:
        tuple val(sampleid), path("fasta_bins"), emit: fasta_bins
        tuple val(sampleid), path("bin_names.json"), emit: bin_manifest

    shell:
    '''
    runMetaBat.sh !{contigs} !{bam}
    mv `ls -1 | grep assembly.fasta.metabat` fasta_bins
    python -c 'import os, json; print(json.dumps({x: value for x, value in enumerate(os.listdir("fasta_bins"))}))' > bin_names.json
    '''
}
