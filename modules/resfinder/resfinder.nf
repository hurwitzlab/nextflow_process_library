#!/usr/bin/env nextflow

// Detect antimicrobial resistance genes in an assembly with ResFinder
process resfinder {
    label "process_single"
    label "publish_final"
    container "${params.container__resfinder}"

    input:
        tuple val(sampleid), path(contigs)
        path(resfinder_db)

    // This tool doesn't quite output valid JSON. I'll need to muge it a bit, or use something else
    output:
        tuple val(sampleid), path("${sampleid}.resfinder.json"), emit: resistance_genes
        tuple val(sampleid), path("${sampleid}.resfinder.log"), emit: log

    shell:
    '''
    mkdir database
    tar -xvf !{resfinder_db} -C database

    resfinder.py --inputfile !{contigs} \
                 --databasePath database \
                 --tmp_dir /tmp \
                 --outputPath . \
                 --json 1> !{sampleid}.resfinder.json 2> !{sampleid}.resfinder.log
    '''
}
