#!/usr/bin/env nextflow

// Downsample and normalize a sample's paired-end reads by k-mer depth with BBNorm
process downsample_paired_end {
    label "process_high"
    label "publish_intermediate"
    container "${params.container__bbnorm}"

    input:
        tuple val(sampleid), path(r1), path(r2)

    output:
        tuple val(sampleid), path("${sampleid}.r1_sub.fq.gz"), emit: r1_normalized
        tuple val(sampleid), path("${sampleid}.r2_sub.fq.gz"), emit: r2_normalized

    shell:
    '''
    # target is the aimed normalization depth
    bbnorm.sh in=!{r1} in2=!{r2} out=!{sampleid}.r1_sub.fq.gz out2=!{sampleid}.r2_sub.fq.gz target=!{params.bbnorm_target} -Xmx!{Math.round(task.memory.toGiga() * 0.83)}g
    '''
}
