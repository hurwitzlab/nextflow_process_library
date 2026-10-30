#!/usr/bin/env nextflow


// Index a reference sequence with bwa; emits the reference together with its index files
 process bwa_index {
    label "process_single"
    container "${params.container__bwa}"
                        
    input:
        path(reference_genome)

    output:
        tuple path(reference_genome), path("${reference_genome}.{amb,ann,bwt,pac,sa}"), emit: indexed_sequence

    shell:
    '''
    bwa index !{reference_genome}
    '''
}

// Align paired-end reads to a reference indexed by bwa_index (e.g. reads.combine(bwa_index.out.indexed_sequence))
process bwa_mem {
    label "process_high"
    container "${params.container__bwa}"

    input:
        tuple val(sampleid), path(clean_r1), path(clean_r2), path(reference_genome), path(index_files)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    bwa mem -t !{task.cpus} !{reference_genome} !{clean_r1} !{clean_r2} > !{sampleid}.sam
    '''
}

// Align paired-end reads to a reference genome with bwa mem (indexing the reference first)
process bwa_align_paired_end {
    label "process_high"
    container "${params.container__bwa}"

    input:
        path(reference_genome)
        tuple val(sampleid), path(reads_r1), path(reads_r2)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    bwa index !{reference_genome}
    bwa mem -t !{task.cpus} !{reference_genome} !{reads_r1} !{reads_r2} > !{sampleid}.sam
    '''
}

// Align single-end reads to a reference genome with bwa mem (indexing the reference first)
process bwa_align_single_end {
    label "process_high"
    container "${params.container__bwa}"

    input:
        path(reference_genome)
        tuple val(sampleid), path(reads_r1)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    bwa index !{reference_genome}
    bwa mem -t !{task.cpus} !{reference_genome} !{reads_r1} > !{sampleid}.sam
    '''
}

// Align paired-end reads to a pre-built bwa index (packaged as a tarball)
process bwa_align_to_index {
    label "process_high"
    container "${params.container__bwa}"

    input:
        path(bwa_index_tarball)
        tuple val(sampleid), path(reads_r1), path(reads_r2)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    mkdir index
    # Assume index is gzipped and the sequence inside is called ref.fa
    tar -xvf !{bwa_index_tarball} -C index
    if [ ! -f index/ref.fa ]; then
        echo "Input reference, must be gzipped, and contain a bwa index"
        exit 1
    fi

    bwa mem -t !{task.cpus} index/ref.fa !{reads_r1} !{reads_r2} > !{sampleid}.sam
    '''
}
