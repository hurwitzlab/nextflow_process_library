#!/usr/bin/env nextflow

// Split a sample's contigs into per-species bins from mapped read coverage with CONCOCT
process bin_contigs {
    label "process_medium"
    label "publish_final"
    container "${params.container__concoct}"

    input:
        tuple val(sampleid), path(contigs), path(mapped_bam), path(mapped_bam_index)

    output:
        tuple val(sampleid), path("${sampleid}/fasta_bins"), emit: fasta_bins
        tuple val(sampleid), path("${sampleid}/bin_names.json"), emit: bin_names_json
        tuple val(sampleid), path("${sampleid}/coverage_table.tsv"), emit: coverage_table
        tuple val(sampleid), path("${sampleid}/clustering_merged.csv"), emit: clustering_merged
        tuple val(sampleid), path("${sampleid}/args.txt"), emit: concoct_args
        tuple val(sampleid), path("${sampleid}/log.txt"), emit: concoct_log

    shell:
    '''
    MIN_CONTIG_LENGTH=10000
    mkdir !{sampleid}
    # Following CONCOCT basic usage workflow https://concoct.readthedocs.io/en/latest/usage.html
    cut_up_fasta.py !{contigs} \
                    --chunk_size $MIN_CONTIG_LENGTH \
                    --overlap_size 0 \
                    --bedfile contigs_10K.bed \
                    --merge_last \
                    > contigs_10K.fa
    concoct_coverage_table.py contigs_10K.bed !{mapped_bam} > !{sampleid}/coverage_table.tsv
    concoct --composition_file contigs_10K.fa \
            --coverage_file !{sampleid}/coverage_table.tsv \
            --basename !{sampleid}/ \
            --length_threshold $MIN_CONTIG_LENGTH \
            --threads !{task.cpus}
    merge_cutup_clustering.py !{sampleid}/clustering_gt${MIN_CONTIG_LENGTH}.csv > !{sampleid}/clustering_merged.csv
    mkdir !{sampleid}/fasta_bins
    extract_fasta_bins.py !{contigs} !{sampleid}/clustering_merged.csv --output_path !{sampleid}/fasta_bins
    # List bin directory and write it as a JSON file
    python -c 'import os, json; print(json.dumps({x: value for x, value in enumerate(os.listdir("!{sampleid}/fasta_bins"))}))' > !{sampleid}/bin_names.json
    '''
}
