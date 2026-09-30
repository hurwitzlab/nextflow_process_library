#!/usr/bin/env nextflow

// Assess genome assembly completeness against a lineage-specific ortholog set with BUSCO
process busco_assess {
    label "process_high"
    label "publish_final"
    container "${params.container__busco}"

    input:
        tuple val(sampleid), path(contigs)
        path(busco_db)

    output:
        tuple val(sampleid), path("${sampleid}_busco_out/short_summary.specific.bacteria_odb10.${sampleid}_busco_out.json"), emit: json_report
        tuple val(sampleid), path("${sampleid}_busco_out/short_summary.specific.bacteria_odb10.${sampleid}_busco_out.txt"),  emit: txt_report
        tuple val(sampleid), path("${sampleid}_busco_out"), emit: busco_results

    shell:
    '''
    mkdir busco_db
    tar -xvf !{busco_db} -C busco_db

    busco -i !{contigs} \
          -o !{sampleid}_busco_out \
          -m genome \
          -l busco_db/bacteria_odb10 \
          --cpu !{task.cpus}
    '''
}
