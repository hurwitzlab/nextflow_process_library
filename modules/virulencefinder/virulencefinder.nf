#!/usr/bin/env nextflow

// Identify virulence factors in a sample's contigs using VirulenceFinder
process virulencefinder {
    label "process_single"
    label "publish_final"
    container "${params.container__virulencefinder}"

    input:
        tuple val(sampleid), path(contigs)
        path(virulence_db_archive)

    output:
        tuple val(sampleid), path("virulencefinder.json"), emit: virulence_factors

    shell:
    '''
    mkdir database
    tar -xvf !{virulence_db_archive} -C database

    virulencefinder.py -i !{contigs} -p database -tmp /tmp -q
    mv data.json virulencefinder.json
    '''
}
