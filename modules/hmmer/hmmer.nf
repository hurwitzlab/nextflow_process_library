#!/usr/bin/env nextflow

// example databases:
// uniref90  s3://troi-artifacts-datasets/uniref90.fasta.gz
// MGnify    s3://troi-artifacts-datasets/mgnify_clusters_2018_12.fa.gz

// Search a single query sequence or MSA against a protein database with jackhmmer
process jackhmmer_seq {
    label "process_high"
    container "${params.container__hmmer}"

    input:
        tuple val(sampleid), path(query)
        path(db)

    output:
        tuple val(sampleid), path("${sampleid}.alignment.sto"), emit: alignment
        tuple val(sampleid), path("${sampleid}.table.txt"), emit: hit_table
        tuple val(sampleid), path("${sampleid}.jackhmmer.log"), emit: jackhmmer_log

    shell:
    '''
    # TODO - unzip to a ramdisk which can hold the DB in memory
    gzip -dc !{db} > db.fasta

    jackhmmer \
    --cpu !{task.cpus} \
    -N 5 \
    -E 0.0001 \
    -o !{sampleid}.jackhmmer.log \
    -A !{sampleid}.alignment.sto \
    --tblout !{sampleid}.table.txt \
    !{query} \
    db.fasta
    '''
}

// Search a tarball directory of query files against a gzipped protein database with jackhmmer, building an HMM from each hit
process jackhmmer_dir {
    label "process_high"
    container "${params.container__hmmer}"
    publishDir "${params.hmmer_outdir}", mode: 'copy'

    input:
        path(query_tar)
        path(db)

    output:
        path("alignments.tar.gz"), emit: alignments
        path("tables.tar.gz"), emit: hit_tables
        path("hmms.tar.gz"), emit: hmms
        path("jackhmmer_dir.log"), emit: jackhmmer_log

    shell:
    '''
    set -x

    mkdir seqs
    tar -zxf !{query_tar} -C seqs

    # TODO - unzip to a ramdisk which can hold the DB in memory
    gzip -dc !{db} > db.fasta

    mkdir alignments
    mkdir tables
    mkdir hmms

    # The F1/F2/F3 are the expected proportion to pass each of the filtering
    # stages (which get progressively more expensive), reducing these
    # speeds up the pipeline at the expense of sensitivity. They are
    # set very low to allow querying very large databases (e.g. mgnify)
    for seq in seqs/*; do
        out="$(basename ${seq%.*})"
        echo "${seq} -> ${out}" >> jackhmmer_dir.log

        jackhmmer \
        --cpu !{task.cpus} \
        -N 1 \
        -E 0.0001 \
        --incE 0.0001 \
        --F1 0.0005 \
        --F2 0.00005 \
        --F3 0.0000005 \
        -o jackhmmer_dir.log \
        -A "alignments/${out}.sto" \
        --tblout "tables/${out}.txt" \
        "${seq}" \
        "db.fasta"

        hmmbuild "${out}.hmm" "alignments/${out}.sto"
    done

    tar -zcf alignments.tar.gz -C alignments .
    tar -zcf tables.tar.gz -C tables .
    tar -zcf hmms.tar.gz -C hmms .
    '''
}

// Build an HMM profile from a multiple sequence alignment
process hmmbuild {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__hmmer}"

    input:
        tuple val(sampleid), path(alignment)

    output:
        tuple val(sampleid), path("${sampleid}.hmm"), emit: hmm_profile

    shell:
    '''
    hmmbuild !{sampleid}.hmm !{alignment}
    '''
}
