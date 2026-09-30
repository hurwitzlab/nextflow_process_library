#!/usr/bin/env nextflow

// Strain-tracking pipeline with samestr: convert per-sample SAM output from
// metaphlan into SNP profiles, then merge/filter/stats/compare/summarize
// across all samples.

// Convert a per-sample metaphlan SAM file into a SNP profile (npz)
 process samestr_convert {
    label "process_medium"
    container "${params.container__samestr}"

    input:
        tuple val(sampleid), path(metaphlan_sam)
        path(marker_db)

    output:
        tuple val(sampleid), path("${sampleid}.npz"), emit: converted_profile

    shell:
    '''
    samestr convert \
    --input-files !{metaphlan_sam} \
    --marker-dir !{marker_db} \
    --nprocs !{task.cpus} \
    --min-vcov !{params.samestr_minvcov} \
    --output-dir .
    '''
}

// Merge per-sample SNP profiles into per-SGB matrices across all samples
process samestr_merge {
    label "process_medium"
    container "${params.container__samestr}"

    input:
        path(converted_profiles)
        path(marker_db)

    output:
        path("*.npz"), emit: merged_profiles

    shell:
    '''
    samestr merge \
    --input-files !{converted_profiles} \
    --marker-dir !{marker_db} \
    --nprocs !{task.cpus} \
    --output-dir .
    '''
}

// Remove low-quality markers and under-covered samples from merged profiles
process samestr_filter {
    label "process_low"
    container "${params.container__samestr}"

    input:
        path(merged_profiles)
        path(marker_db)

    output:
        path("*.npz"), emit: filtered_profiles

    shell:
    '''
    samestr filter \
    --input-files !{merged_profiles} \
    --marker-dir !{marker_db} \
    --nprocs !{task.cpus} \
    --output-dir .
    '''
}

// Compute alignment statistics for QC reporting
process samestr_stats {
    label "process_low"
    container "${params.container__samestr}"
    // No sampleid here (aggregates stats across all filtered samples, not
    // per-sample) so the Closure-based publishDir convention doesn't apply
    // -- stays a plain path.
    publishDir "${params.samestr_outdir}/stats", mode: 'copy'

    input:
        path(filtered_profiles)
        path(marker_db)

    output:
        path("*"), emit: stats_report

    shell:
    '''
    samestr stats \
    --input-files !{filtered_profiles} \
    --marker-dir !{marker_db} \
    --nprocs !{task.cpus} \
    --output-dir .
    '''
}

// Compute pairwise strain similarity scores between all sample pairs
process samestr_compare {
    label "process_high"
    container "${params.container__samestr}"
    // No sampleid here (computes all-pairs comparisons across every sample,
    // not per-sample) so the Closure-based publishDir convention doesn't
    // apply -- stays a plain path.
    publishDir "${params.samestr_outdir}/compare", mode: 'copy'

    input:
        path(filtered_profiles)
        path(marker_db)

    output:
        path("*"), emit: comparison

    shell:
    '''
    samestr compare \
    --input-files !{filtered_profiles} \
    --marker-dir !{marker_db} \
    --nprocs !{task.cpus} \
    --output-dir .
    '''
}

// Call strain-sharing events from pairwise comparisons
process samestr_summarize {
    label "process_low"
    container "${params.container__samestr}"
    // No sampleid here (summarizes strain-sharing across all sample-pair
    // comparisons, not per-sample) so the Closure-based publishDir
    // convention doesn't apply -- stays a plain path.
    publishDir "${params.samestr_outdir}/summary", mode: 'copy'

    input:
        path(comparison)
        path(tax_profiles)
        path(marker_db)

    output:
        path("*"), emit: summary

    shell:
    '''
    samestr summarize \
    --input-dir !{comparison} \
    --marker-dir !{marker_db} \
    --tax-profiles-dir !{tax_profiles} \
    --output-dir .
    '''
}
