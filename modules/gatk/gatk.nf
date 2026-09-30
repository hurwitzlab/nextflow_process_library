#!/usr/bin/env nextflow

// Call somatic variants from a sample's alignments against a reference with Mutect2
process call_somatic_variants {
    label "process_single"
    container "${params.container__gatk}"

    input:
        tuple val(sampleid), path(reads)
        path(reference)
        path(expected_variants)
        path(expected_variants_index)

    output:
        tuple val(sampleid), path("${sampleid}.variants.vcf.gz"), path("${sampleid}.variants.vcf.gz.tbi"), path("${sampleid}.variants.vcf.gz.stats"), emit: variant_calls

    shell:
    '''
    # create dict file
    gatk CreateSequenceDictionary -R !{reference}

    # create fasta index
    samtools faidx !{reference}

    # replace / set read groups to make broad tools happy (they don't matter for variant calls)
    gatk AddOrReplaceReadGroups -I !{reads} -O cleaned.bam -LB lib -PL ILLUMINA -PU run -SM 1

    # index new bam
    samtools index cleaned.bam

    # find variants
    gatk --java-options '-DGATK_STACKTRACE_ON_USER_EXCEPTION=true' Mutect2 -R !{reference} -I cleaned.bam -O !{sampleid}.variants.vcf.gz --alleles !{expected_variants}
    '''
}

// Filter a sample's Mutect2 somatic variant calls
process filter_somatic_variants {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__gatk}"

    input:
        tuple val(sampleid), path(variants), path(variants_index), path(variants_stats)
        path(reference)

    output:
        tuple val(sampleid), path("${sampleid}.variants.filtered.vcf.gz"), path("${sampleid}.variants.filtered.vcf.gz.tbi"), path("${sampleid}.variants.filtered.vcf.gz.filteringStats.tsv"), emit: filtered_variant_calls

    shell:
    '''
    # create dict file
    gatk CreateSequenceDictionary -R !{reference}

    # create fasta index
    samtools faidx !{reference}

    # Filter variants
    gatk --java-options '-DGATK_STACKTRACE_ON_USER_EXCEPTION=true' FilterMutectCalls --variant !{variants} \
                                                                                     --reference !{reference} \
                                                                                     --output !{sampleid}.variants.filtered.vcf.gz \
                                                                                     --microbial-mode
    '''
}

// Annotate a sample's variant calls with read depth from its BAM
process annotate_vcf_with_bam_depth {
    label "process_single"
    label "publish_final"
    container "${params.container__gatk}"

    input:
        tuple val(sampleid), path(variants), path(variants_index), path(reads)

    output:
        tuple val(sampleid), path("${sampleid}.variants.depth.vcf.gz"), path("${sampleid}.variants.depth.vcf.gz.tbi"), emit: depth_annotated_variants

    shell:
    '''
    # replace / set read groups to make broad tools happy (they don't matter for variant calls)
    gatk AddOrReplaceReadGroups -I !{reads} -O cleaned.bam -LB lib -PL ILLUMINA -PU run -SM 1

    # index new bam
    samtools index cleaned.bam

    # Get variant depths
    gatk --java-options '-DGATK_STACKTRACE_ON_USER_EXCEPTION=true' AnnotateVcfWithBamDepth --variant !{variants} \
                                                                                           --input cleaned.bam \
                                                                                           --output !{sampleid}.variants.depth.vcf.gz
    '''
}

// Compare two arbitrary reference genomes and report their differences as a VCF
process compare_references {
    label "process_single"
    container "${params.container__gatk}"
    publishDir "${params.gatk_outdir}", mode: 'copy'

    input:
        path(reference), stageAs: "ref.fasta"
        path(reference_comparison), stageAs: "refcomp.fasta"

    output:
        path "result.tsv", emit: comparison_stats
        path "variants/ref.fasta_refcomp.fasta.vcf.gz", emit: comparison_variants
        path "variants/ref.fasta_refcomp.fasta.vcf.gz.tbi", emit: comparison_variants_index

    shell:
    '''
    gatk CreateSequenceDictionary -R ref.fasta
    gatk CreateSequenceDictionary -R refcomp.fasta
    samtools faidx ref.fasta
    samtools faidx refcomp.fasta
    mkdir variants
    # Get variant depths
    gatk --java-options '-DGATK_STACKTRACE_ON_USER_EXCEPTION=true' CompareReferences --reference ref.fasta \
                                                                                     --references-to-compare refcomp.fasta \
                                                                                     --base-comparison FULL_ALIGNMENT \
                                                                                     --base-comparison-output variants \
                                                                                     --output result.tsv
    if [ ! -f variants/ref.fasta_refcomp.fasta.vcf ]
    then
        bcftools mpileup --no-reference - <<< $'@HD\t' > variants/ref.fasta_refcomp.fasta.vcf
    fi
    bgzip variants/ref.fasta_refcomp.fasta.vcf
    tabix variants/ref.fasta_refcomp.fasta.vcf.gz
    '''
}
