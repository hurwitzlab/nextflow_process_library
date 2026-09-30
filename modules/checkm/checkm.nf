#!/usr/bin/env nextflow

// Run CheckM lineage workflow for a single sample's assembled contigs
process checkm_lineage {
    label "process_high"
    label "publish_final"
    container "${params.container__checkm}"

    input:
        tuple val(sampleid), path(contigs, stageAs: "bins/contigs.fna") // checkm requires a directory of bin fasta files as input

    output:
        tuple val(sampleid), path("${sampleid}.checkm_results.txt"), emit: quality_assessment

    shell:
    '''
    checkm lineage_wf -t !{task.cpus} -x fna -f !{sampleid}.checkm_results.txt bins checkm
    '''
}

// Run CheckM lineage workflow on a directory of bin fasta files (e.g. bins from a binning algorithm like CONCOCT)
process checkm_lineage_bins {
    label "process_high"
    label "publish_final"
    container "${params.container__checkm}"

    input:
        tuple val(sampleid), path(bins) // directory of per-bin fasta files; can't use stageAs since it only renames files, not directories

    output:
        tuple val(sampleid), path("${sampleid}.checkm_results.txt"), emit: quality_assessment

    shell:
    '''
    checkm lineage_wf -t !{task.cpus} -x fa -f !{sampleid}.checkm_results.txt !{bins} checkm
    '''
}
