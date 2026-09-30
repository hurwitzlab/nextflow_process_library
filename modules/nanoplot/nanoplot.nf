#!/usr/bin/env nextflow

// Generate Oxford Nanopore read QC metrics and plots for a sample with NanoPlot
process nanoplot_qc {
    label "process_low"
    label "publish_final"
    container "${params.container__nanoplot}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(ont_reads)

    output:
        tuple val(sampleid), path("${sampleid}_NanoPlot_out/NanoPlot-report.html"), emit: html_report
        tuple val(sampleid), path("${sampleid}_NanoPlot_out"), emit: report_dir

    shell:
    '''
    NanoPlot --fastq !{ont_reads} \
           -o !{sampleid}_NanoPlot_out \
           -t !{task.cpus}
    '''
}
