#!/usr/bin/env nextflow

// Remove duplicate sequences from a protein FASTA using SeqKit
process deduplicate_sequences {
    label "process_medium"
    container "${params.container__seqkit}"

    input:
        path(query_faa)

    output:
        path "query_dedup.faa", emit: deduplicated_sequences

    shell:
    '''
    seqkit rmdup -j !{task.cpus} --by-seq !{query_faa} | seqkit seq -j !{task.cpus} --only-id > query_dedup.faa
    '''
}
