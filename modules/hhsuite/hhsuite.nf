#!/usr/bin/env nextflow

// Perform HMM search with hhblits over a directory (tarball) of sequences/MSAs against an hhsuite database
process hhblits {
    label "process_high"
    container "${params.container__hhsuite}"
    publishDir "${params.hhsuite_outdir}", mode: 'copy'

    input:
        path(seqs_tar) // tarball of a directory of files, each a single sequence or a multiple sequence alignment
        path(hhsuite_db) // hhsuite database, as .tar.gz
        val(dbname) // name prefix of database, e.g. pdb or pfam

    output:
        path("hhr.tar.gz"), emit: hhr_results
        path("hhm.tar.gz"), emit: hhm_profiles
        path("a3m.tar.gz"), emit: a3m_alignments
        path("fasta.tar.gz"), emit: fasta_alignments
        path("log"), emit: log
        // ignore tar.log, it should be in the cache

    shell:
    '''
    set -x

    mkdir seqs
    tar -zxvf !{seqs_tar} -C seqs >> tar.log

    mkdir db
    tar -zxvf !{hhsuite_db} -C db >> tar.log

    mkdir hhr
    mkdir hhm
    mkdir a3m
    mkdir fasta

    for seq in seqs/*; do
        out="$(basename ${seq%.*})"
        echo "${seq} -> ${out}" >> log

        hhblits -cpu !{task.cpus} -i "${seq}" -d db/!{dbname} -o "hhr/${out}.hhr" -ohhm "hhm/${out}.hhm" -oa3m "a3m/${out}.a3m" >> log

        # generate fasta MSA
        perl /hhsuite/scripts/reformat.pl a3m fas "a3m/${out}.a3m" "fasta/${out}.fasta"
    done

    tar -czvf hhr.tar.gz -C hhr . >> tar.log
    tar -czvf hhm.tar.gz -C hhm . >> tar.log
    tar -czvf a3m.tar.gz -C a3m . >> tar.log
    tar -czvf fasta.tar.gz -C fasta . >> tar.log
    '''
}

// hhblits a single sequence/MSA against an hhsuite database (spins up a container for just one sequence)
process hhblits_seq {
    label "process_high"
    container "${params.container__hhsuite}"
    publishDir "${params.hhsuite_outdir}", mode: 'copy'

    input:
        path(query_msa) // fasta or multiple sequence alignment
        path(hhsuite_db) // hhsuite database, as .tar.gz
        val(dbname) // name prefix of database, e.g. pdb70 or pfam

    output:
        path("out.hhr"), emit: hhr_result
        path("out.hhm"), emit: hhm_profile
        path("out.a3m"), emit: a3m_alignment
        path("log"), emit: log

    shell:
    '''
    mkdir db
    tar -zxvf !{hhsuite_db} -C db >> tar.log

    hhblits -cpu !{task.cpus} -i !{query_msa} -d db/!{dbname} -o out.hhr -ohhm out.hhm -oa3m out.a3m >> log
    '''
}

// Retrieve HMM records from an ffindexed hhsuite database for a list of record names
process ffindex_get {
    label "process_single"
    container "${params.container__hhsuite}"

    input:
        path(hhsuite_db) // hhsuite database, as .tar.gz
        val(dbname) // name prefix of database, e.g. pdb70 (expecting db/${dbname}_hhm.ffdata to exist)
        path(records_list) // file, one record name per line

    output:
        path("records.tar.gz"), emit: records_archive

    shell:
    '''
    mkdir records

    mkdir db
    tar -zxf !{hhsuite_db} -C db

    while read record; do
        ffindex_get db/!{dbname}_hhm.ffdata db/!{dbname}_hhm.ffindex "${record}" > "records/${record}"
    done < !{records_list}

    tar -czvf records.tar.gz -C records
    '''
}

// Convert between MSA formats that hhsuite knows about (e.g. a3m, a2m, fas, clu)
process reformat_msa {
    label "process_single"
    container "${params.container__hhsuite}"

    input:
        path(alignment)
        val(format_from) // e.g. a3m, a2m, fas, clu
        val(format_to)

    output:
        path("output"), emit: reformatted_msa

    shell:
    '''
    perl /hhsuite/scripts/reformat.pl !{format_from} !{format_to} !{alignment} output
    '''
}

// Download PDB / CIF structures for a given PDB id
// TODO - move to another process, this is not hhsuite specific
process download_pdb_structure {
    label "process_single"
    container "${params.container__hhsuite}"

    input:
        val(pdbid) // PDB ID, e.g. 2XGF

    output:
        path("structure.pdb"), emit: pdb_structure
        path("structure.cif"), emit: cif_structure

    shell:
    '''
    wget -O structure.pdb http://files.rcsb.org/download/!{pdbid}.pdb
    wget -O structure.cif http://files.rcsb.org/download/!{pdbid}.cif
    '''
}

// Generate an HHM (hh-suite version of an HMM) profile from an alignment
process hhmake {
    label "process_single"
    container "${params.container__hhsuite}"

    input:
        path(a3m_alignment, stageAs: "input.a3m") // hhmake expects a recognizable .a3m extension

    output:
        path("out.hhm"), emit: hhm_profile

    shell:
    '''
    hhmake -i !{a3m_alignment} -o out.hhm
    '''
}

// Convert a directory (tarball) of jackhammer alignment outputs into a3m, fasta, and hhm files
process convert_jackhammer {
    label "process_medium"
    container "${params.container__hhsuite}"

    input:
        path(alignments_tar) // tarball of a directory of alignment files, e.g. *.sto
        val(format_from) // e.g. sto

    output:
        path("a3m.tar.gz"), emit: a3m_alignments
        path("fasta.tar.gz"), emit: fasta_alignments
        path("hhm.tar.gz"), emit: hhm_profiles
        path("log"), emit: log

    shell:
    '''
    set -x

    mkdir seqs
    tar -zxf !{alignments_tar} -C seqs

    mkdir a3m
    mkdir fasta
    mkdir hhm

    for seq in seqs/*; do
        out="$(basename ${seq%.*})"
        echo "${seq} -> ${out}" >> log

        # reform msas to a3m
        perl /hhsuite/scripts/reformat.pl !{format_from} a3m "${seq}" "a3m/${out}.a3m"

        # reform msas to fasta
        perl /hhsuite/scripts/reformat.pl !{format_from} fas "${seq}" "fasta/${out}.fasta"

        # generate hhm
        hhmake -i "a3m/${out}.a3m" -o "hhm/${out}.hhm"
    done

    tar -zcf a3m.tar.gz -C a3m .
    tar -zcf fasta.tar.gz -C fasta .
    tar -zcf hhm.tar.gz -C hhm .
    '''
}
