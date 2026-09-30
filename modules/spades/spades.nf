#!/usr/bin/env nextflow

// Assemble paired-end reads into contigs with SPAdes; a low-coverage failure re-raises as exit code 100 to trigger a retry instead of over-provisioning
process assemble {
    label "process_high"
    label "publish_final"
    container "${params.container__spades}"
    errorStrategy { task.exitStatus == 100 ? 'terminate' : 'retry' }

    input:
        tuple val(sampleid), path(r1), path(r2), path(singles)

    output:
        // contigs: contiguous sections of assembly
        tuple val(sampleid), path("SPAdes_out/contigs.fasta"),        emit: contigs
        // scaffolds: concatenations of contigs, potentially with gaps, put together intelligently
        tuple val(sampleid), path("SPAdes_out/scaffolds.fasta"),      emit: scaffolds
        tuple val(sampleid), path("SPAdes_out/scaffolds.paths"),      emit: assembly_path
        tuple val(sampleid), path("SPAdes_out/assembly_graph.fastg"), emit: assembly_graph
        tuple val(sampleid), path("SPAdes_out"),                     emit: results_dir

    shell:
    def maxmem = "${task.memory.toString().replaceAll(/[\sGB]/,'')}"

    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "Verification of expression 'cov_.size() > 10' failed" output; then
                echo 'low coverage observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    spades.py -1 !{r1} \
              -2 !{r2} \
              -s !{singles} \
              -o SPAdes_out \
              --careful \
              --phred-offset 33 \
              --threads !{task.cpus} \
              --memory !{maxmem} \
              2>&1 | tee output
    '''
}

// Assemble paired-end metagenomic reads into contigs with SPAdes in meta mode
process assemble_metagenome {
    label "process_high"
    label "publish_final"
    container "${params.container__spades}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(r1), path(r2), path(singles)

    output:
        // contigs: contiguous sections of assembly
        tuple val(sampleid), path("SPAdes_out/contigs.fasta"),        emit: contigs
        // scaffolds: concatenations of contigs, potentially with gaps, put together intelligently
        tuple val(sampleid), path("SPAdes_out/scaffolds.fasta"),      emit: scaffolds
        tuple val(sampleid), path("SPAdes_out/scaffolds.paths"),      emit: assembly_path
        tuple val(sampleid), path("SPAdes_out/assembly_graph.fastg"), emit: assembly_graph
        tuple val(sampleid), path("SPAdes_out/assembly_graph_with_scaffolds.gfa"), emit: assembly_gfa
        tuple val(sampleid), path("SPAdes_out"),                     emit: results_dir

    shell:
    def maxmem = "${task.memory.toString().replaceAll(/[\sGB]/,'')}"

    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "Verification of expression 'cov_.size() > 10' failed" output; then
                echo 'low coverage observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    spades.py -1 !{r1} \
              -2 !{r2} \
              -s !{singles} \
              -o SPAdes_out \
              --meta \
              --phred-offset 33 \
              --threads !{task.cpus} \
              --memory !{maxmem} \
              2>&1 | tee output
    '''
}

// Assemble single-end reads into contigs with SPAdes
process assemble_metagenome_single_end {
    label "process_high"
    label "publish_final"
    container "${params.container__spades}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(r1)

    output:
        // contigs: contiguous sections of assembly
        tuple val(sampleid), path("SPAdes_out/contigs.fasta"),        emit: contigs
        // scaffolds: concatenations of contigs, potentially with gaps, put together intelligently
        tuple val(sampleid), path("SPAdes_out/scaffolds.fasta"),      emit: scaffolds
        tuple val(sampleid), path("SPAdes_out/scaffolds.paths"),      emit: assembly_path
        tuple val(sampleid), path("SPAdes_out/assembly_graph.fastg"), emit: assembly_graph
        tuple val(sampleid), path("SPAdes_out"),                     emit: results_dir

    shell:
    def maxmem = "${task.memory.toString().replaceAll(/[\sGB]/,'')}"

    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "Verification of expression 'cov_.size() > 10' failed" output; then
                echo 'low coverage observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    spades.py -s !{r1} \
              -o SPAdes_out \
              --phred-offset 33 \
              --threads !{task.cpus} \
              --memory !{maxmem} \
              2>&1 | tee output
    '''
}
