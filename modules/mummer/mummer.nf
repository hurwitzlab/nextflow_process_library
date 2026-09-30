#!/usr/bin/env nextflow

// Call expected variants between two genomes by whole-genome alignment with MUMmer (nucmer)
process find_engineered_snvs {
    label "process_single"
    container "${params.container__mummer}"
    // No sampleid here (compares two whole genomes, not per-sample) so the
    // Closure-based publishDir convention (which takes sampleid) doesn't
    // apply -- stays a plain path.
    publishDir "${params.mummer_outdir}", mode: 'copy'

    input:
        path(reference)
        path(comparison_genome)

    output:
        path("result.vcf.gz"), emit: variant_calls
        path("result.vcf.gz.tbi"), emit: variant_calls_index

    shell:
    '''
    nucmer --mum -p test !{reference} !{comparison_genome}
    delta-filter -1 test.delta | delta2vcf > result.vcf
    bgzip result.vcf
    tabix result.vcf.gz
    '''
}
