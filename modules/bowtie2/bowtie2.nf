#!/usr/bin/env nextflow

// Build a bowtie2 index and align reads to it, retaining unmapped (non-host) reads

// Build a bowtie2 index from a reference genome
 process bowtie2_build {
    label "process_single"
    container "${params.container__bowtie2}"

    input:
        path(reference_genome)

    output:
        path("host_index*"), emit: indexed_reference

    shell:
    '''
    bowtie2-build \
    --large-index \
    --threads !{task.cpus} \
    !{reference_genome} \
    host_index
    '''
}

// Align paired reads to a host reference and keep the unmapped (host-free) reads
 process bowtie2_align {
    label "process_medium"
    label "publish_intermediate"
    container "${params.container__bowtie2}"

    input:
        tuple val(sampleid), path(raw_r1), path(raw_r2), path(indexed_reference)

    output:
        tuple val(sampleid), path("${sampleid}_unmapped_R1.fastq"), path("${sampleid}_unmapped_R2.fastq"), emit: host_free_reads

    shell:
    '''
    bowtie2 \
    -x host_index \
    -1 !{raw_r1} \
    -2 !{raw_r2} \
    -S !{sampleid}_mapped.sam \
    -p !{task.cpus}

    samtools view -bS !{sampleid}_mapped.sam > !{sampleid}_mapped.bam
    samtools sort !{sampleid}_mapped.bam -o !{sampleid}_sorted.bam
    samtools view -b -f 4 !{sampleid}_sorted.bam > !{sampleid}_unmapped.bam
    samtools fastq -1 !{sampleid}_unmapped_R1.fastq -2 !{sampleid}_unmapped_R2.fastq -0 /dev/null -s !{sampleid}_unpaired.fastq !{sampleid}_unmapped.bam
    '''
}
