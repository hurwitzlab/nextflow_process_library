#!/usr/bin/env nextflow

// Bin genomes from a sample's assembly and read-mapping BAM using SemiBin
process bin_contigs {
    label "process_medium"
    label "publish_final"
    container "${params.container__semibin}"

    input:
        tuple val(sampleid), path(assembly), path(bam)

    output:
        tuple val(sampleid), path("out_results/output_recluster_bins", type: "dir"), emit: fasta_bins
        tuple val(sampleid), path("bin_names.json"), emit: bin_names_json

    shell:
    '''
    SemiBin single_easy_bin \
        --output out_results \
        --input-fasta !{assembly} \
        --input-bam !{bam} \
        --environment global \
        --threads !{task.cpus}
    python -c 'import os, json; print(json.dumps({x: value for x, value in enumerate(os.listdir("out_results/output_recluster_bins"))}))' > bin_names.json
    '''
}
