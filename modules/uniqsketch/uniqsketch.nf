#!/usr/bin/env nextflow

// Build a UniqSketch reference index from a directory of stock genomes
process uniqsketch_build_index_stock {
    label "process_high"
    container "${params.container__uniqsketch}"
    publishDir "${params.uniqsketch_outdir}", mode: 'copy'

    input:
        path(genome_dir)

    output:
        path("sketch_uniq.tsv"), emit: uniq_sketch_index
        path("db_uniq_count.tsv"), emit: unique_kmer_counts

    shell:
    '''
    ls -1 !{genome_dir}/* > genome_list.txt
    uniqsketch -t !{task.cpus} -c50 -k81 --stat db_uniq_count.tsv --out sketch_uniq.tsv @genome_list.txt
    '''
}

// Query a sample's paired-end reads against a UniqSketch reference index
process uniqsketch_query_stock_sample {
    label "process_high"
    label "publish_final"
    container "${params.container__uniqsketch}"

    input:
        tuple val(sampleid), path(reads_r1), path(reads_r2)
        path(sketch_index)

    output:
        tuple val(sampleid), path("out_uniqsketch.json"), emit: abundance_profile

    shell:
    '''
    querysketch -t !{task.cpus} --solid -c50 -h5 --r1 !{reads_r1} --r2 !{reads_r2} --out out_uniqsketch.tsv --ref !{sketch_index}

    # transform tsv output to json for better datalake representation
    awk 'NR>1 {printf("{\"reference\":\"%s\",\"abundance\":%f,\"count\":%s}\n", $1, $2, $3)}' out_uniqsketch.tsv > out_uniqsketch.json
    '''
}
