#!/usr/bin/env nextflow

// Convert a sample's paired-end FASTQ reads to an unmapped BAM with Picard
process fastq_to_sam {
    label "process_single"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(r1), path(r2)

    output:
        tuple val(sampleid), path("${sampleid}.unmapped.bam"), emit: unmapped_bam

    shell:
    '''
    java -jar /picard.jar FastqToSam F1=!{r1} F2=!{r2} O=!{sampleid}.unmapped.bam SM=!{sampleid} RG=!{sampleid}
    '''
}

// Estimate a sample's library complexity from its unmapped reads with Picard
process estimate_library_complexity {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(unmapped_bam)

    output:
        tuple val(sampleid), path("${sampleid}.complexity.txt"), emit: library_complexity

    shell:
    '''
    java -jar /picard.jar EstimateLibraryComplexity INPUT=!{unmapped_bam} OUTPUT=!{sampleid}.complexity.txt
    '''
}

// Mark duplicate reads (using mate cigar) in a sample's mapped BAM with Picard
process mark_duplicates {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(mapped_bam), path(mapped_bam_index)

    output:
        tuple val(sampleid), path("${sampleid}.markdup.bam"), emit: dupmarked_bam
        tuple val(sampleid), path("${sampleid}.markdup_metrics.txt"), emit: duplicate_metrics

    shell:
    '''
    java -Xmx!{Math.round(task.memory.toGiga() * 0.83)}g -jar /picard.jar MarkDuplicatesWithMateCigar \
                                         INPUT=!{mapped_bam} \
                                         OUTPUT=!{sampleid}.markdup.bam \
                                         M=!{sampleid}.markdup_metrics.txt \
                                         MINIMUM_DISTANCE=600 \
                                         MAX_RECORDS_IN_RAM=500000
    '''
}

// Collect insert size metrics for a sample's mapped BAM with Picard
process collect_insert_size_metrics {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(mapped_bam), path(mapped_bam_index)

    output:
        tuple val(sampleid), path("${sampleid}.insert_size_metrics.txt"), emit: insert_size_metrics
        tuple val(sampleid), path("${sampleid}.insert_size_histogram.pdf"), emit: insert_size_histogram

    shell:
    '''
    touch !{sampleid}.insert_size_metrics.txt
    touch !{sampleid}.insert_size_histogram.pdf

    java -jar /picard.jar CollectInsertSizeMetrics INPUT=!{mapped_bam} OUTPUT=!{sampleid}.insert_size_metrics.txt H=!{sampleid}.insert_size_histogram.pdf M=.5
    '''
}

// Collect GC bias metrics for a sample's mapped BAM against its reference with Picard
process collect_gc_bias_metrics {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(mapped_bam), path(mapped_bam_index)
        path(reference)

    output:
        tuple val(sampleid), path("${sampleid}.gc_bias_summary_metrics.txt"), emit: gc_summary_metrics
        tuple val(sampleid), path("${sampleid}.gc_bias_metrics.txt"), emit: gc_bias_metrics
        tuple val(sampleid), path("${sampleid}.gc_bias_metrics.pdf"), emit: gc_bias_chart

    shell:
    '''
    java -jar /picard.jar CollectGcBiasMetrics INPUT=!{mapped_bam} R=!{reference} OUTPUT=!{sampleid}.gc_bias_metrics.txt CHART=!{sampleid}.gc_bias_metrics.pdf S=!{sampleid}.gc_bias_summary_metrics.txt
    '''
}

// Collect alignment summary metrics for a sample's mapped BAM against its reference with Picard
process collect_alignment_summary_metrics {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(mapped_bam), path(mapped_bam_index)
        path(reference)

    output:
        tuple val(sampleid), path("${sampleid}.alignment_summary_metrics.txt"), emit: alignment_summary_metrics

    shell:
    '''
    java -jar /picard.jar CollectAlignmentSummaryMetrics INPUT=!{mapped_bam} R=!{reference} OUTPUT=!{sampleid}.alignment_summary_metrics.txt
    '''
}

// Collect quality yield metrics for a sample's mapped BAM with Picard
process collect_quality_yield_metrics {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(mapped_bam), path(mapped_bam_index)

    output:
        tuple val(sampleid), path("${sampleid}.quality_yield_metrics.txt"), emit: quality_yield_metrics

    shell:
    '''
    java -jar /picard.jar CollectQualityYieldMetrics INPUT=!{mapped_bam} OUTPUT=!{sampleid}.quality_yield_metrics.txt
    '''
}

// Collect base distribution by cycle for a sample's mapped BAM with Picard
process collect_base_distribution_by_cycle {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(mapped_bam), path(mapped_bam_index)

    output:
        tuple val(sampleid), path("${sampleid}.base_dist_by_cycle.txt"), emit: base_distribution_metrics
        tuple val(sampleid), path("${sampleid}.base_dist_by_cycle.pdf"), emit: base_distribution_chart

    shell:
    '''
    touch !{sampleid}.base_dist_by_cycle.txt
    touch !{sampleid}.base_dist_by_cycle.pdf

    java -jar /picard.jar CollectBaseDistributionByCycle INPUT=!{mapped_bam} OUTPUT=!{sampleid}.base_dist_by_cycle.txt CHART=!{sampleid}.base_dist_by_cycle.pdf
    '''
}

// Collect whole-genome sequencing metrics for a sample's mapped BAM against its reference with Picard
process collect_wgs_metrics {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(mapped_bam), path(mapped_bam_index)
        path(reference)

    output:
        tuple val(sampleid), path("${sampleid}.wgs_metrics.txt"), emit: wgs_metrics

    shell:
    '''
    java -jar /picard.jar CollectWgsMetrics INPUT=!{mapped_bam} R=!{reference} OUTPUT=!{sampleid}.wgs_metrics.txt
    '''
}

// Collect variant calling metrics for a sample's VCF against a known dbSNP VCF with Picard
process collect_variant_calling_metrics {
    label "process_single"
    label "publish_final"
    container "${params.container__picard}"

    input:
        tuple val(sampleid), path(variant_calls)
        path(dbsnp_vcf)

    output:
        tuple val(sampleid), path("${sampleid}.variant_calling_metrics.txt"), emit: variant_calling_metrics

    shell:
    '''
    java -jar /picard.jar CollectVariantCallingMetrics INPUT=!{variant_calls} DBSNP=!{dbsnp_vcf} OUTPUT=!{sampleid}.variant_calling_metrics.txt
    '''
}
