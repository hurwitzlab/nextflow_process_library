#!/usr/bin/env nextflow

// Bin contigs into per-species fasta files using paired-end read coverage with MaxBin2
process maxbin2_bin_contigs {
    label "process_single"
    label "publish_final"
    container "${params.container__maxbin2}"

    input:
        tuple val(sampleid), path(contigs), path(r1), path(r2)

    output:
        tuple val(sampleid), path("fasta_bins"), emit: fasta_bins
        tuple val(sampleid), path("bin_names.json"), emit: bin_manifest
        tuple val(sampleid), path("fasta_bins.summary"), emit: summary
        tuple val(sampleid), path("fasta_bins.log"), emit: log_file

    shell:
    '''
    run_MaxBin.pl -contig !{contigs} -reads !{r1} -reads2 !{r2} -out fasta_bins

    mkdir fasta_bins
    mv fasta_bins.*.fasta fasta_bins

    for x in fasta_bins/*; do mv ${x} ${x%.*}.fa; done

    python -c 'import os, json; print(json.dumps({x: value for x, value in enumerate(os.listdir("fasta_bins"))}))' > bin_names.json
    '''
}

// Bin contigs into per-species fasta files using single-end read coverage with MaxBin2
process maxbin2_bin_contigs_single_end {
    label "process_single"
    label "publish_final"
    container "${params.container__maxbin2}"

    input:
        tuple val(sampleid), path(contigs), path(r1)

    output:
        tuple val(sampleid), path("fasta_bins"), emit: fasta_bins
        tuple val(sampleid), path("bin_names.json"), emit: bin_manifest
        tuple val(sampleid), path("fasta_bins.summary"), emit: summary
        tuple val(sampleid), path("fasta_bins.log"), emit: log_file

    shell:
    '''
    run_MaxBin.pl -contig !{contigs} -reads !{r1} -out fasta_bins

    mkdir fasta_bins
    mv fasta_bins.*.fasta fasta_bins

    for x in fasta_bins/*; do mv ${x} ${x%.*}.fa; done

    python -c 'import os, json; print(json.dumps({x: value for x, value in enumerate(os.listdir("fasta_bins"))}))' > bin_names.json
    '''
}
