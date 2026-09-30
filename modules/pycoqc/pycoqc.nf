#!/usr/bin/env nextflow

// Generate Oxford Nanopore flowcell-level QC metrics with pycoQC
process pycoqc_qc {
    label "process_medium"
    container "${params.container__pycoqc}"
    // No sampleid here (flowcell-level QC, not per-sample) so the
    // Closure-based publishDir convention doesn't apply -- stays a plain
    // path.
    publishDir "${params.pycoqc_outdir}", mode: 'copy'

    input:
        path(sequencing_summary)

    output:
        path "pycoqc_output.html", emit: qc_report_html
        path "pycoqc_output.json", emit: qc_report_json

    shell:
    '''
    pycoQC -f !{sequencing_summary} \
           -o pycoqc_output.html \
           -j pycoqc_output.json
    '''
}
