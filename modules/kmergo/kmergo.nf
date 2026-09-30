#!/usr/bin/env nextflow

// Find group-specific k-mers and assemble them into contigs from two sets of genomes/metagenomes
process find_group_specific_kmers {
    label "process_high"
    container "${params.container__kmergo}"
    publishDir "${params.kmergo_outdir}", mode: 'copy'

    input:
        path(fasta_dir)
        path(trait_info)
        val(mode)
        val(kmer_length)
        val(min_occurrence)
        val(max_occurrence)
        val(assl)
        val(p_threshold)
        val(assn)
        val(corr)

    output:
        path("contig_result/A_specific.fa.cap.ace"), emit: group_a_ace
        path("contig_result/A_specific.fa.cap.contigs"), emit: group_a_contigs
        path("contig_result/A_specific.fa.cap.contigs.links"), emit: group_a_contig_links
        path("contig_result/A_specific.fa.cap.contigs.qual"), emit: group_a_contig_qual
        path("contig_result/A_specific.fa.cap.info"), emit: group_a_contig_info
        path("contig_result/A_specific.fa.cap.singlets"), emit: group_a_singlets
        path("contig_result/A_specific_kmer.fa"), emit: group_a_specific_kmers
        path("contig_result/B_specific.fa.cap.ace"), emit: group_b_ace
        path("contig_result/B_specific.fa.cap.contigs"), emit: group_b_contigs
        path("contig_result/B_specific.fa.cap.contigs.links"), emit: group_b_contig_links
        path("contig_result/B_specific.fa.cap.contigs.qual"), emit: group_b_contig_qual
        path("contig_result/B_specific.fa.cap.info"), emit: group_b_contig_info
        path("contig_result/B_specific.fa.cap.singlets"), emit: group_b_singlets
        path("contig_result/B_specific_kmer.fa"), emit: group_b_specific_kmers

    shell:
    '''
    /KmerGO_for_linux_x64_cmd/KmerGO_for_cmd \
                   -i !{fasta_dir} \
                   -t !{trait_info} \
                   -m !{mode} \
                   -k !{kmer_length} \
                   -ci !{min_occurrence} \
                   -cs !{max_occurrence} \
                   -n !{task.cpus} \
                   -assl !{assl} \
                   -p !{p_threshold} \
                   -assn !{assn} \
                   -corr !{corr}
    '''
}
