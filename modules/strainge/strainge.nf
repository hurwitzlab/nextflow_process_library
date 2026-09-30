#!/usr/bin/env nextflow

// Estimate strain composition from paired-end reads against a pan-genome database with StrainGST
process strainge_run_straingst_paired_end {
    label "process_high"
    label "publish_final"
    container "${params.container__strainge}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(r1), path(r2)
        path(database)

    output:
        tuple val(sampleid), path("results.tsv"), emit: straingst_results

    shell:
    '''
    straingst kmerize -o !{sampleid}.hdf5 !{r1} !{r2}
    straingst run -o results_tmp.tsv !{database} !{sampleid}.hdf5

    # To make sure the output is a clean table that can go into athena:
    # script below first modifies the abbreviated headers in link below into more informative headers
    # https://github.com/broadinstitute/strainge/blob/master/docs/straingst.md#reference-strain-statistics
    # then extracts the first two lines that contain statistics on the whole sample and then
    # adds them to the third to last lines that are close reference genomes
    # for example header `rapct` denotes Estimated strain relative abundance (relative to the whole sample)
    # and was changed to `strain_relative_abundance` for better readability

    awk '
        BEGIN {print "sample\ttotal_kmers\tdistinct_kmers\tuniq_kmers_present_database\taverage_uniq_kmer_cov\tgenus_relative_abundance\titeration_number\tstrain\ttotal_uniq_ref_kmers\tremaining_uniq_ref_kmers\tremaining_uniq_sample_kmers\tcoverage_ref\tkmer_coverage_present_both\tkmer_coverage_present_ref\tsample_kmers_fraction\tcoverage_distribution_evenness\tspecificity\tstrain_relative_abundance\told_strain_relative_abundance\tweighted_score\tscore"}
        NR==2 {prefix_line = $0} \
        NR>3 {print prefix_line"\t"$0}
        ' results_tmp.tsv > results.tsv
    '''
}

// Estimate strain composition from single-end reads against a pan-genome database with StrainGST
process strainge_run_straingst_single_end {
    label "process_high"
    label "publish_final"
    container "${params.container__strainge}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(r1)
        path(database)

    output:
        tuple val(sampleid), path("results.tsv"), emit: straingst_results

    shell:
    '''
    straingst kmerize -o !{sampleid}.hdf5 !{r1}
    straingst run -o results_tmp.tsv !{database} !{sampleid}.hdf5

    # To make sure the output is a clean table that can go into athena:
    # script below first modifies the abbreviated headers in link below into more informative headers
    # https://github.com/broadinstitute/strainge/blob/master/docs/straingst.md#reference-strain-statistics
    # then extracts the first two lines that contain statistics on the whole sample and then
    # adds them to the third to last lines that are close reference genomes
    # for example header `rapct` denotes Estimated strain relative abundance (relative to the whole sample)
    # and was changed to `strain_relative_abundance` for better readability

    awk '
        BEGIN {print "sample\ttotal_kmers\tdistinct_kmers\tuniq_kmers_present_database\taverage_uniq_kmer_cov\tgenus_relative_abundance\titeration_number\tstrain\ttotal_uniq_ref_kmers\tremaining_uniq_ref_kmers\tremaining_uniq_sample_kmers\tcoverage_ref\tkmer_coverage_present_both\tkmer_coverage_present_ref\tsample_kmers_fraction\tcoverage_distribution_evenness\tspecificity\tstrain_relative_abundance\told_strain_relative_abundance\tweighted_score\tscore"}
        NR==2 {prefix_line = $0} \
        NR>3 {print prefix_line"\t"$0}
        ' results_tmp.tsv > results.tsv
    '''
}
