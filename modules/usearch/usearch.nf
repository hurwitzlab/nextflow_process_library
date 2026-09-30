#!/usr/bin/env nextflow

// Dereplicate reads into unique amplicon sequences with USEARCH
process count_unique_amplicons {
    label "process_single"
    container "${params.container__usearch}"

    input:
        path(trimmed_reads)

    output:
        path "uniques.fasta", emit: unique_amplicons
        path "uniques.txt",   emit: unique_amplicons_table

    shell:
    '''
    usearch -fastx_uniques !{trimmed_reads} -sizeout -relabel Uniq -fastaout uniques.fasta -tabbedout uniques.txt
    '''
}

// Denoise unique amplicon sequences into ZOTUs with USEARCH UNOISE3
process denoise_amplicons {
    label "process_single"
    container "${params.container__usearch}"

    input:
        path(unique_amplicons)

    output:
        path "zotus.fasta",     emit: zotus_fasta
        path "tab_bed_out.txt", emit: zotu_mapping_table
        path "all_zotus.fasta", emit: all_zotus_fasta
        path "unoise.log",      emit: unoise_log

    shell:
    '''
    usearch -unoise3 !{unique_amplicons} -zotus zotus.fasta -tabbedout tab_bed_out.txt -ampout all_zotus.fasta 2> unoise.log
    '''
}

// Map reads to their closest ZOTU and build a raw ZOTU count table
process count_denoised_amplicons {
    label "process_single"
    container "${params.container__usearch}"

    input:
        path(trimmed_reads)
        path(zotus_fasta)

    output:
        path "zotu_counts.txt",      emit: zotu_counts_table
        path "zotu_assignments.txt", emit: zotu_assignments

    shell:
    '''
    usearch -otutab !{trimmed_reads} -zotus !{zotus_fasta} -otutabout zotu_counts.txt -mapout zotu_assignments.txt
    '''
}

// Build a count table from unique amplicon sequences
process create_uniques_count_table {
    label "process_single"
    container "${params.container__usearch}"
    publishDir "${params.usearch_outdir}", mode: 'copy'

    input:
        path(unique_amplicons)

    output:
        path "uniques_counts.tsv",  emit: unique_counts_tsv
        path "uniques_counts.json", emit: unique_counts_json

    shell:
    '''
    create_uniques_count_table.py --fasta !{unique_amplicons} --output_tsv uniques_counts.tsv --output_json uniques_counts.json
    '''
}

// Build a count table from denoised (collapsed) ZOTU sequences
process create_denoised_count_table {
    label "process_single"
    container "${params.container__usearch}"
    publishDir "${params.usearch_outdir}", mode: 'copy'

    input:
        path(zotu_counts_table)
        path(zotus_fasta)

    output:
        path "denoised_counts.tsv",  emit: denoised_counts_tsv
        path "denoised_counts.json", emit: denoised_counts_json

    shell:
    '''
    # FASTA headers from USEARCH/VSEARCH have ';size=XXX' if -sizeout flag is passed but it is stripped from count table which can cause problems
    sed -i 's/;size=.*//' !{zotus_fasta}
    create_collapsed_count_table.py --fasta !{zotus_fasta} --count_table !{zotu_counts_table} --output_tsv denoised_counts.tsv --output_json denoised_counts.json
    '''
}
