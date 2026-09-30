#!/usr/bin/env nextflow

// Profile taxonomic composition of paired reads with metaphlan
 process metaphlan {
    label "process_high"
    label "publish_final"
    container "${params.container__metaphlan}"

    input:
        tuple val(sampleid), path(clean_r1), path(clean_r2)
        path(metaphlan_db)

    output:
        tuple val(sampleid), path("${sampleid}_profiled.txt"), path("${sampleid}_profiled_abundance.txt"), emit: profiles

    shell:
    '''
    metaphlan \
    !{clean_r1},!{clean_r2} \
    --bowtie2out !{sampleid}_bowtie.bz2 \
    --nproc !{task.cpus} \
    --add_viruses \
    --input_type fastq \
    -o !{sampleid}_profiled.txt \
    --bowtie2db !{metaphlan_db}

    metaphlan \
    !{sampleid}_bowtie.bz2 \
    --nproc !{task.cpus} \
    --add_viruses \
    --input_type bowtie2out \
    -o !{sampleid}_profiled_abundance.txt \
    --bowtie2db !{metaphlan_db} \
    -t rel_ab_w_read_stats
    '''
}
