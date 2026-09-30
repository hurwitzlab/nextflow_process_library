#!/usr/bin/env nextflow

// Call variants against a reference genome from paired-end reads
process snippy_from_reads {
    label "process_medium"
    label "publish_final"
    container "${params.container__snippy}"

    input:
        tuple val(sampleid), path(r1), path(r2)
        path(ref_gbk)

    output:
        tuple val(sampleid), path("snippy_out/snps.vcf"), emit: variant_calls
        tuple val(sampleid), path("snippy_out"),          emit: results_dir

    shell:
    '''
    snippy \
        --cpus !{task.cpus} \
        --outdir snippy_out \
        --r1 !{r1} \
        --r2 !{r2} \
        --reference !{ref_gbk}
    '''
}

// Call variants against a reference genome from assembled contigs
process snippy_from_contigs {
    label "process_medium"
    label "publish_final"
    container "${params.container__snippy}"

    input:
        tuple val(sampleid), path(contigs)
        path(ref_gbk)

    output:
        tuple val(sampleid), path("snippy_out/snps.vcf"), emit: variant_calls
        tuple val(sampleid), path("snippy_out"),          emit: results_dir

    shell:
    '''
    snippy \
        --cpus !{task.cpus} \
        --outdir snippy_out \
        --ctgs !{contigs} \
        --reference !{ref_gbk}
    '''
}
