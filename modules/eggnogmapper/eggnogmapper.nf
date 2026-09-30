#!/usr/bin/env nextflow

// Functionally annotate a protein fasta with eggNOG-mapper
 process eggnogmapper {
    label "process_high"
    label "publish_final"
    container "${params.container__eggnogmapper}"

    input:
        tuple val(sampleid), path(protein_fasta)

    output:
        tuple val(sampleid), path("${sampleid}_eggnog.out*"), emit: annotations

    shell:
    '''
    emapper.py \
    -m !{params.eggnogmapper_mode} \
    --itype !{params.eggnogmapper_itype} \
    --no_file_comments \
    --override \
    -i !{protein_fasta} \
    -o !{sampleid}_eggnog.out \
    --cpu !{task.cpus}
    '''
}
