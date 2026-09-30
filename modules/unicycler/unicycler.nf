#!/usr/bin/env nextflow

// Assemble a short-read sample into contigs with Unicycler
process unicycler_short_read_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__unicycler}"

    input:
        tuple val(sampleid), path(reads_r1), path(reads_r2), path(single_reads)

    output:
        tuple val(sampleid), path("Unicycler_out/assembly.fasta"), emit: assembled_contigs
        tuple val(sampleid), path("Unicycler_out/assembly.gfa"), emit: assembly_graph
        tuple val(sampleid), path("Unicycler_out/spades_assembly/scaffolds.fasta"), emit: spades_scaffolds
        tuple val(sampleid), path("Unicycler_out"), emit: assembly_results

    shell:
    '''
    # --keep 3: keeps all temp files and save all graphs that will be used for contamination detection
    unicycler -1 !{reads_r1} -2 !{reads_r2} -s !{single_reads} -o Unicycler_out --threads !{task.cpus} --keep 3
    '''
}

// Assemble a long-read sample into contigs with Unicycler
process unicycler_long_read_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__unicycler}"

    input:
        tuple val(sampleid), path(long_reads)

    output:
        tuple val(sampleid), path("Unicycler_out/assembly.fasta"), emit: assembled_contigs
        tuple val(sampleid), path("Unicycler_out/assembly.gfa"), emit: assembly_graph
        tuple val(sampleid), path("Unicycler_out"), emit: assembly_results

    shell:
    '''
    unicycler -l !{long_reads} -o Unicycler_out --threads !{task.cpus}
    '''
}

// Hybrid-assemble a sample's short and long reads into contigs with Unicycler
process unicycler_hybrid_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__unicycler}"

    input:
        tuple val(sampleid), path(reads_r1), path(reads_r2), path(long_reads)

    output:
        tuple val(sampleid), path("Unicycler_out/assembly.fasta"), emit: assembled_contigs
        tuple val(sampleid), path("Unicycler_out/assembly.gfa"), emit: assembly_graph
        tuple val(sampleid), path("Unicycler_out"), emit: assembly_results

    shell:
    '''
    unicycler -1 !{reads_r1} -2 !{reads_r2} -l !{long_reads} -o Unicycler_out --threads !{task.cpus}
    '''
}

// Hybrid-assemble a sample's short (paired + unpaired) and long reads into contigs with Unicycler
process unicycler_hybrid_assembly_bacterial {
    label "process_high"
    label "publish_final"
    container "${params.container__unicycler}"

    input:
        tuple val(sampleid), path(reads_r1), path(reads_r2), path(single_reads), path(long_reads)

    output:
        tuple val(sampleid), path("Unicycler_out/assembly.fasta"), emit: assembled_contigs
        tuple val(sampleid), path("Unicycler_out/assembly.gfa"), emit: assembly_graph
        tuple val(sampleid), path("Unicycler_out"), emit: assembly_results

    shell:
    '''
    unicycler -1 !{reads_r1} -2 !{reads_r2} -s !{single_reads} -l !{long_reads} -o Unicycler_out --threads !{task.cpus}
    '''
}
