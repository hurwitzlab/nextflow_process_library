#!/usr/bin/env nextflow

// Assess genome assembly completeness against a lineage-specific ortholog set with BUSCO
// lineage is one unpacked BUSCO lineage dataset directory, e.g. the BRC install
// /gpfs_backup/bioinfo_data/databases/busco_db/odb12.2_20260527/lineages/bacteria_odb12.2
// --offline and --opt-out-run-stats keep BUSCO from contacting its servers (compute nodes have no internet)
// -l ./<lineage>: BUSCO only treats -l as a local directory when it contains a "/"; the bare staged
// name is read as a dataset name and looked up under busco_downloads/lineages/ instead
process busco_assess {
    label "process_high"
    label "publish_final"
    container "${params.container__busco}"

    input:
        tuple val(sampleid), path(contigs)
        path(lineage)

    output:
        tuple val(sampleid), path("${sampleid}_busco_out/short_summary.specific.${lineage.name}.${sampleid}_busco_out.json"), emit: json_report
        tuple val(sampleid), path("${sampleid}_busco_out/short_summary.specific.${lineage.name}.${sampleid}_busco_out.txt"),  emit: txt_report
        tuple val(sampleid), path("${sampleid}_busco_out"), emit: busco_results

    shell:
    '''
    busco -i !{contigs} \
          -o !{sampleid}_busco_out \
          -m genome \
          -l ./!{lineage} \
          --offline \
          --opt-out-run-stats \
          --cpu !{task.cpus}
    '''
}
