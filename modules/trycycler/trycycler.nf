#!/usr/bin/env nextflow

// Assemble a long-read sample into a consensus contig by clustering, reconciling, and polishing multiple independent assemblies
process trycycler_long_read_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__trycycler}"

    input:
        tuple val(sampleid), path(reads)

    output:
        tuple val(sampleid), path("trycycler/cluster_001/7_final_consensus.fasta"), emit: consensus_contig
        tuple val(sampleid), path("trycycler/cluster_001/4_reads.fastq"), emit: partitioned_reads
        tuple val(sampleid), path("trycycler/cluster_001"), emit: assembly_results

    shell:
    def genome_size = params.expected_phage_genome_size != "" ? "--genome_size ${params.expected_phage_genome_size}" : ''
    '''
    # Trycycler subsample tries to make maximally-independent read subsets of an appropriate depth for the genome.
    trycycler subsample !{genome_size} --reads !{reads} --out_dir read_subsets

    mkdir assemblies

    # The goal of trycycler is to have multiple assemblies (12 is nice) which are reasonably independent of each other
    # To achieve this independence, it uses different assemblers on different subsets (12 subsets) of reads
    # Three assembly algorithms (flye, miniasm, raven) run on 12 different subset of reads to generates 12 assemblies
    subset=($(seq -w 1 12))
    for ((i=0;i< ${#subset[@]} ;i+=3)); do
        flye --nano-raw read_subsets/sample_${subset[i]}.fastq --threads !{task.cpus} --out-dir assembly_${subset[i]} && \
        cp assembly_${subset[i]}/assembly.fasta assemblies/assembly_${subset[i]}.fasta && \
        rm -r assembly_${subset[i]}

        miniasm_and_minipolish.sh read_subsets/sample_${subset[i+1]}.fastq !{task.cpus} > assembly_${subset[i+1]}.gfa && \
        any2fasta assembly_${subset[i+1]}.gfa > assemblies/assembly_${subset[i+1]}.fasta && \
        rm assembly_${subset[i+1]}.gfa

        raven --threads !{task.cpus} read_subsets/sample_${subset[i+2]}.fastq > assemblies/assembly_${subset[i+2]}.fasta && \
        rm raven.cereal
    done

    # The goal of this step is to cluster the contigs 12 assemblies into per-replicon groups
    # It also serves to exclude any spurious, incomplete or badly misassembled contigs
    trycycler cluster --assemblies assemblies/*.fasta --reads !{reads} --out_dir trycycler

    # The goal of this step is to perform initial check to make sure the contigs look sufficiently similar to each other
    # and ensure that all contig sequences are on the same strand and then fix any circularisation issue
    trycycler reconcile --reads !{reads} --cluster_dir trycycler/cluster_001

    # This step takes the reconciled contig sequences from previous step and runs a multiple sequence alignment
    trycycler msa --cluster_dir trycycler/cluster_001

    # This step partitions and assigns the related read to the cluster
    trycycler partition --reads !{reads} --cluster_dirs trycycler/cluster_*

    # The final step of Trycycler is to generate a consensus contig sequence for the cluster.
    trycycler consensus --cluster_dir trycycler/cluster_001
    '''
}
