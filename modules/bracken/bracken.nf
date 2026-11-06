#!/usr/bin/env nextflow

// Re-estimate species abundance from a kraken2 report with bracken
 process bracken {
    label "process_single"
    label "publish_final"
    container "${params.container__bracken}"

    input:
        tuple val(sampleid), path(kreport)
        path(kraken2_db)

    output:
        tuple val(sampleid), path("${sampleid}.bracken"), emit: abundance_table

    shell:
    '''
    bracken \
    -d !{kraken2_db} \
    -i !{kreport} \
    -o !{sampleid}.bracken \
    -r !{params.bracken_readlen}

    # bracken prints its errors to stdout and exits 0 (e.g. no kmer_distrib for this read length),
    # so fail here with the likely cause rather than as a bare "missing output file"
    if [[ ! -s !{sampleid}.bracken ]]; then
        echo "ERROR: bracken produced no output; it needs !{kraken2_db}/database!{params.bracken_readlen}mers.kmer_distrib (built by bracken-build -l !{params.bracken_readlen})" >&2
        exit 1
    fi
    '''
}
