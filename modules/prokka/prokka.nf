#!/usr/bin/env nextflow

// Annotate a bacterial genome assembly with Prokka
process annotate_bacterial {
    label "process_medium"
    label "publish_final"
    container "${params.container__prokka}"
    errorStrategy { task.exitStatus == 100 ? 'terminate' : 'retry' }

    input:
        tuple val(sampleid), path(contigs, stageAs: "contigs.fasta")

    output:
        tuple val(sampleid), path("${sampleid}/annotated_genome.faa"), emit: predicted_proteins
        tuple val(sampleid), path("${sampleid}/annotated_genome.fna"), emit: annotated_nucleotide
        tuple val(sampleid), path("${sampleid}/annotated_genome.gbk"), emit: genbank_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.gff"), emit: gff_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.ffn"), emit: gene_nucleotide_sequences
        tuple val(sampleid), path("${sampleid}"), emit: annotation_dir

    shell:
    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "file 'contigs.fasta' contains no suitable sequence entries" output; then
                echo 'no suitable contigs observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    prokka !{contigs} \
        --centre X \
        --compliant \
        --outdir !{sampleid} \
        --prefix annotated_genome \
        --mincontiglen 2000 \
        --cpus !{task.cpus} | tee output
    '''
}

// Annotate a phage genome with Prokka
process annotate_phage {
    label "process_medium"
    label "publish_final"
    container "${params.container__prokka}"
    errorStrategy { task.exitStatus == 100 ? 'terminate' : 'retry' }

    input:
        tuple val(sampleid), path(contigs, stageAs: "contigs.fasta")
        path(pvog_database)

    output:
        tuple val(sampleid), path("${sampleid}/annotated_genome.faa"), emit: predicted_proteins
        tuple val(sampleid), path("${sampleid}/annotated_genome.fna"), emit: annotated_nucleotide
        tuple val(sampleid), path("${sampleid}/annotated_genome.gbk"), emit: genbank_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.gff"), emit: gff_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.ffn"), emit: gene_nucleotide_sequences
        tuple val(sampleid), path("${sampleid}"), emit: annotation_dir

    shell:
    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "file 'contigs.fasta' contains no suitable sequence entries" output; then
                echo 'no suitable contigs observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    tar -xvf !{pvog_database} -C /prokka-1.14.5/db/hmm

    prokka !{contigs} \
        --centre X \
        --compliant \
        --outdir !{sampleid} \
        --prefix annotated_genome \
        --mincontiglen 2000 \
        --kingdom Viruses \
        --gcode 11 \
        --cpus !{task.cpus} | tee output
    '''
}

// Annotate a phage genome with Prokka using a reference protein set
process annotate_phage_with_proteins {
    label "process_medium"
    label "publish_final"
    container "${params.container__prokka}"
    errorStrategy { task.exitStatus == 100 ? 'terminate' : 'retry' }

    input:
        tuple val(sampleid), path(contigs, stageAs: "contigs.fasta")
        path(reference_proteins)
        path(pvog_database)

    output:
        tuple val(sampleid), path("${sampleid}/annotated_genome.faa"), emit: predicted_proteins
        tuple val(sampleid), path("${sampleid}/annotated_genome.fna"), emit: annotated_nucleotide
        tuple val(sampleid), path("${sampleid}/annotated_genome.gbk"), emit: genbank_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.gff"), emit: gff_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.ffn"), emit: gene_nucleotide_sequences
        tuple val(sampleid), path("${sampleid}"), emit: annotation_dir

    shell:
    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "file 'contigs.fasta' contains no suitable sequence entries" output; then
                echo 'no suitable contigs observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    tar -xvf !{pvog_database} -C /prokka-1.14.5/db/hmm

    prokka !{contigs} \
        --proteins !{reference_proteins} \
        --centre X \
        --compliant \
        --outdir !{sampleid} \
        --prefix annotated_genome \
        --mincontiglen 2000 \
        --kingdom Viruses \
        --gcode 11 \
        --cpus !{task.cpus} | tee output
    '''
}

// Annotate a metagenome assembly with Prokka
process annotate_metagenome {
    label "process_medium"
    label "publish_final"
    container "${params.container__prokka}"
    errorStrategy { task.attempt <= 1 ? 'retry' : 'ignore' }

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}/annotated_genome.faa"), emit: predicted_proteins
        tuple val(sampleid), path("${sampleid}/annotated_genome.fna"), emit: annotated_nucleotide
        tuple val(sampleid), path("${sampleid}/annotated_genome.gbk"), emit: genbank_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.gff"), emit: gff_annotation
        tuple val(sampleid), path("${sampleid}/annotated_genome.ffn"), emit: gene_nucleotide_sequences
        tuple val(sampleid), path("${sampleid}"), emit: annotation_dir

    shell:
    '''
    prokka !{contigs} \
        --centre X \
        --compliant \
        --outdir !{sampleid} \
        --prefix annotated_genome \
        --mincontiglen 200 \
        --metagenome \
        --cpus !{task.cpus} | tee output
    '''
}

// Annotate a named phage genome with Prokka using a custom sample/timestamp prefix
process annotate_custom_phage {
    label "process_medium"
    label "publish_final"
    container "${params.container__prokka}"
    errorStrategy { task.exitStatus == 100 ? 'terminate' : 'retry' }

    input:
        tuple val(sampleid), path(contigs, stageAs: "contigs.fasta")
        path(pvog_database)
        val(timestamp) // Timestamp (normally yyyymmdd) sample was created

    output:
        tuple val(sampleid), path("${sampleid}/${sampleid}.${timestamp}.${timestamp}.faa"), emit: predicted_proteins
        tuple val(sampleid), path("${sampleid}/${sampleid}.${timestamp}.${timestamp}.fna"), emit: annotated_nucleotide
        tuple val(sampleid), path("${sampleid}/${sampleid}.${timestamp}.${timestamp}.gbk"), emit: genbank_annotation
        tuple val(sampleid), path("${sampleid}/${sampleid}.${timestamp}.${timestamp}.gff"), emit: gff_annotation
        tuple val(sampleid), path("${sampleid}/${sampleid}.${timestamp}.${timestamp}.ffn"), emit: gene_nucleotide_sequences
        tuple val(sampleid), path("${sampleid}"), emit: annotation_dir

    shell:
    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "file 'contigs.fasta' contains no suitable sequence entries" output; then
                echo 'no suitable contigs observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    tar -xvf !{pvog_database} -C /prokka-1.14.5/db/hmm

    prokka !{contigs} \
        --centre X \
        --compliant \
        --outdir !{sampleid} \
        --prefix !{sampleid}.!{timestamp}.!{timestamp} \
        --mincontiglen 2000 \
        --kingdom Viruses \
        --locustag !{sampleid}.!{timestamp} \
        --gcode 11 \
        --cpus !{task.cpus} | tee output
    '''
}

// Annotate a named phage genome with Prokka
process annotate_named_phage {
    label "process_medium"
    label "publish_final"
    container "${params.container__prokka}"
    errorStrategy { task.exitStatus == 100 ? 'terminate' : 'retry' }

    input:
        tuple val(sampleid), path(contigs, stageAs: "contigs.fasta")
        path(pvog_database)

    output:
        tuple val(sampleid), path("${sampleid}/${sampleid}.faa"), emit: predicted_proteins
        tuple val(sampleid), path("${sampleid}/${sampleid}.fna"), emit: annotated_nucleotide
        tuple val(sampleid), path("${sampleid}/${sampleid}.gbk"), emit: genbank_annotation
        tuple val(sampleid), path("${sampleid}/${sampleid}.gff"), emit: gff_annotation
        tuple val(sampleid), path("${sampleid}/${sampleid}.ffn"), emit: gene_nucleotide_sequences
        tuple val(sampleid), path("${sampleid}"), emit: annotation_dir

    shell:
    '''
    check_error() {
        exit_code=$1

        echo ''
        echo 'custom error checking...'
        echo "original exit code: $exit_code"

        if [ -f output ]; then
            if grep -q "file 'contigs.fasta' contains no suitable sequence entries" output; then
                echo 'no suitable contigs observed!'
                exit 100
            fi
        fi

        exit $exit_code
    }
    trap 'check_error $?' EXIT

    tar -xvf !{pvog_database} -C /prokka-1.14.5/db/hmm

    prokka !{contigs} \
        --centre X \
        --compliant \
        --outdir !{sampleid} \
        --prefix !{sampleid} \
        --mincontiglen 2000 \
        --kingdom Viruses \
        --locustag !{sampleid} \
        --gcode 11 \
        --cpus !{task.cpus} | tee output
    '''
}
