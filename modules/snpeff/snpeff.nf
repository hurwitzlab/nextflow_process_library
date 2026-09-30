#!/usr/bin/env nextflow

// Build a snpEff genome database from a genome/gff and annotate variants against it
process annotate_variants_no_index {
    label "process_single"
    container "${params.container__snpeff}"

    input:
        tuple val(sampleid), path(vcf, stageAs: "variants.vcf.gz")
        path(genome, stageAs: "reference/genome/sequences.fa")
        path(gff, stageAs: "reference/genome/genes.gff")
        path(snpeff_config, stageAs: "snpEff.config")

    output:
        tuple val(sampleid), path("variants.ann.vcf.gz"),     emit: annotated_variants
        tuple val(sampleid), path("variants.ann.vcf.gz.tbi"), emit: annotated_variants_index
        tuple val(sampleid), path("variants.stats.csv"),      emit: annotation_stats

    shell:
    '''
    java -jar /snpEff/snpEff.jar build -gff3 -v genome -c snpEff.config -noCheckCds -noCheckProtein
    java -jar /snpEff/snpEff.jar ann genome variants.vcf -csvStats variants.stats.csv > variants.ann.vcf
    bgzip variants.ann.vcf
    tabix variants.ann.vcf.gz
    '''
}

// DEPRECATED: annotate variants against a pre-built snpEff reference database
process annotate_variants {
    label "process_single"
    container "${params.container__snpeff}"

    input:
        val(genome_version)
        tuple val(sampleid), path(vcf, stageAs: "variants.vcf.gz")
        path(snpeff_config, stageAs: "snpEff.config")
        path(reference, stageAs: "genome")

    output:
        tuple val(sampleid), path("variants.ann.vcf"),   emit: annotated_vcf
        tuple val(sampleid), path("variants.stats.csv"), emit: annotation_stats

    shell:
    '''
    mkdir reference
    mv genome reference/!{genome_version}
    java -jar /snpEff/snpEff.jar ann !{genome_version} variants.vcf -csvStats variants.stats.csv > variants.ann.vcf
    '''
}

// Flag called variants that match the engineered strain's expected variant set
process annotate_expected_variants {
    label "process_single"
    label "publish_final"
    container "${params.container__snpeff}"

    input:
        tuple val(sampleid), path(vcf, stageAs: "variants.vcf.gz")
        path(expected_vcf, stageAs: "expected_variants.vcf.gz")

    output:
        tuple val(sampleid), path("annotated.vcf.gz"),     emit: annotated_variants
        tuple val(sampleid), path("annotated.vcf.gz.tbi"), emit: annotated_variants_index

    shell:
    '''
    gunzip variants.vcf.gz
    gunzip expected_variants.vcf.gz

    java -jar /snpEff/SnpSift.jar annotate expected_variants.vcf variants.vcf -exists EXPECTED_VARIANT > annotated.vcf
    bgzip annotated.vcf
    tabix annotated.vcf.gz
    '''
}

// Convert an annotated VCF into a bespoke per-sample TSV/JSON variant report
process variant_report {
    label "process_single"
    label "publish_final"
    container "${params.container__snpeff}"

    input:
        tuple val(sampleid), path(vcf, stageAs: "variants.vcf.gz")
        path(gff, stageAs: "genome.gff")

    output:
        tuple val(sampleid), path("variants.tsv"),  emit: tsv_report
        tuple val(sampleid), path("variants.json"), emit: json_report

    shell:
    '''
    gunzip variants.vcf.gz
    convert_vcf.py --vcf variants.vcf --gff genome.gff --output_tsv variants.tsv --output_json variants.json
    '''
}
