#!/usr/bin/env nextflow

// Build a diamond protein database from a reference fasta
process diamond_makedb {
    label "process_low"
    container "${params.container__diamond}"

    input:
       path(protein_reference)
    output:
       path("out.dmnd"), emit: diamond_database

    shell:
    '''
    diamond makedb \
        --threads !{task.cpus} \
        --db out \
        --in !{protein_reference}
    '''
}

// Search a sample's protein sequences against a diamond database with blastp
process diamond_blastp {
    label "process_high"
    label "publish_final"
    container "${params.container__diamond}"

    // Diamond is dual-indexed search. The software should be smart enough to avoid running out of
    // memory by chunking, but bigger DB and/or bigger query means provisioning more resources
    // would speed this greatly.
    // TODO detect file sizes and alter resource provision?

    input:
       tuple val(sampleid), path(query_proteins)
       path(diamond_database) // .dmnd database to search
    output:
        tuple val(sampleid), path("${sampleid}.tsv"), emit: blastp_hits

    shell:
    '''
    diamond blastp \
        --threads !{task.cpus} \
        --sensitive \
        --db !{diamond_database} \
        --query !{query_proteins} \
        --out !{sampleid}.tsv
    '''
}

// Search a sample's nucleic acid gene calls against a diamond database with blastx
process diamond_blastx {
    label "process_high"
    label "publish_final"
    container "${params.container__diamond}"

    // Diamond is dual-indexed search. The software should be smart enough to avoid running out of
    // memory by chunking, but bigger DB and/or bigger query means provisioning more resources
    // would speed this greatly.
    // TODO detect file sizes and alter resource provision?

    input:
       tuple val(sampleid), path(query_genes) // ffn (genic nucleic acid) file to query
       path(diamond_database) // .dmnd database to search
    output:
        tuple val(sampleid), path("${sampleid}.tsv"), emit: blastx_hits

    shell:
    '''
    diamond blastx \
        --threads !{task.cpus} \
        --db !{diamond_database} \
        --query !{query_genes} \
        --out !{sampleid}.tsv
    '''
}

// Smoke-test that the diamond container/binary runs correctly
process diamond_test {
    label "process_single"
    container "${params.container__diamond}"

    shell:
    '''
    diamond test
    '''
}

// Compare a reference and a query protein set with diamond blastp, producing XML output
process diamond_similarity_search {
    label "process_high"
    container "${params.container__diamond}"
    publishDir "${params.diamond_outdir}", mode: 'copy'

    input:
        path(reference)
        path(query_proteins)

    output:
        path("results.xml"), emit: similarity_results

    shell:
    '''
    diamond blastp \
        --threads !{task.cpus} \
        --very-sensitive \
        -d !{reference} \
        -q !{query_proteins} \
        -o results.xml \
        --outfmt xml \
        --masking 0
    '''
}
