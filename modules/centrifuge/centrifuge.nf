#!/usr/bin/env nextflow

// Classify reads for taxonomic contamination with centrifuge
process read_contamination {
    label "process_high"
    label "publish_final"
    container "${params.container__centrifuge}"

    input:
        tuple val(sampleid), path(reads_r1), path(reads_r2)

        // In this tar there should be 4 files index.1.cf, index.2.cf, index.3.cf, index.4.cf.
        // They can come from any index, but because this process expects a consistent index name and path,
        // we have settled on "index". Database generation scripts can be found in
        // EgafOneOffs/20210422_centrifuge/generate_databases.sh
        val(centrifuge_db)

    output:
        tuple val(sampleid), path("${sampleid}.reads.txt"),    emit: classified_reads
        tuple val(sampleid), path("${sampleid}.report.txt"),   emit: classification_report
        tuple val(sampleid), path("${sampleid}.kreport.txt"),  emit: kraken_report

    shell:
    '''
    file_handler !{centrifuge_db}

    centrifuge --threads !{task.cpus} -x !{centrifuge_db}/index -1 !{reads_r1} -2 !{reads_r2} --report-file !{sampleid}.report.txt > !{sampleid}.reads.txt
    centrifuge-kreport -x !{centrifuge_db}/index !{sampleid}.reads.txt > !{sampleid}.kreport.txt || true # handle no reads gracefully
    '''
}
