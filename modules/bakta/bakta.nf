#!/usr/bin/env nextflow

// Annotate genome/plasmid sequences with bakta
 process bakta {
    label "process_medium"
    container "${params.container__bakta}"
    // NOTE: this process takes path(seqs), not tuple val(sampleid), path(...)
    // (a separate, pre-existing convention gap -- out of scope here), so it
    // has no `sampleid` in scope for the standard Closure publishDir pattern.
    // Left as a plain string; a human should decide whether to restructure
    // this process's inputs to be per-sample before wiring it to a closure.
    publishDir "${params.bakta_outdir}", mode: 'copy'

    input:
        path(seqs)
        path(bakta_db)

    output:
        path("bakta_out"), emit: annotations

    shell:
    '''
    bakta \
    --db !{bakta_db} \
    -o bakta_out \
    -t !{task.cpus} \
    --force \
    !{seqs} \
    --keep-contig-headers
    '''
}

// Annotate a bacterial genome assembly with Bakta
process annotate_bacterial {
    label "process_medium"
    label "publish_final"
    container "${params.container__bakta}"

    input:
        tuple val(sampleid), path(contigs)
        path(bakta_db)

    output:
        tuple val(sampleid), path("${sampleid}.tsv"), emit: annotation_table
        tuple val(sampleid), path("${sampleid}.gff3"), emit: annotation_gff3
        tuple val(sampleid), path("${sampleid}.gbff"), emit: annotation_genbank
        tuple val(sampleid), path("${sampleid}.embl"), emit: annotation_embl
        tuple val(sampleid), path("${sampleid}.fna"), emit: annotated_contigs
        tuple val(sampleid), path("${sampleid}.ffn"), emit: annotated_genes
        tuple val(sampleid), path("${sampleid}.faa"), emit: annotated_proteins
        tuple val(sampleid), path("${sampleid}.hypotheticals.tsv"), emit: hypothetical_proteins_table
        tuple val(sampleid), path("${sampleid}.hypotheticals.faa"), emit: hypothetical_proteins
        tuple val(sampleid), path("${sampleid}.txt"), emit: summary
        tuple val(sampleid), path("${sampleid}.png"), emit: summary_plot_png
        tuple val(sampleid), path("${sampleid}.svg"), emit: summary_plot_svg
        tuple val(sampleid), path("${sampleid}.json"), emit: annotation_json

    shell:
    '''
    file_handler !{bakta_db}

    bakta !{contigs} \
          --db !{bakta_db} \
          --prefix !{sampleid} \
          --threads !{task.cpus}
    '''
}
