#!/usr/bin/env nextflow

// Cluster viral genomes into protein/viral clusters with vConTACT2 from a blast/diamond table + protein info table
process build_viral_ortholog_clusters {
    label "process_high"
    container "${params.container__vcontact2}"
    publishDir "${params.vcontact2_outdir}", mode: 'copy'

    input:
        path(blast_results_tsv)
        path(proteins_fp_tsv)

    output:
        path "out/viral_cluster_overview.csv",    emit: viral_clusters_overview
        path "out/c1.ntw",                        emit: viral_clusters_network
        path "out/genome_by_genome_overview.csv", emit: viruses_clustered
        path "out/vConTACT_pcs.csv",              emit: protein_clusters_overview
        path "out/modules.ntwk",                  emit: protein_clusters_network
        path "out/vConTACT_proteins.csv",         emit: proteins_clustered

    shell:
    '''
    vcontact2 \
        --blast-fp !{blast_results_tsv} \
        --rel-mode 'Diamond' \
        --proteins-fp !{proteins_fp_tsv} \
        --c1-bin /cluster_one-1.0.jar \
        --db None \
        --output-dir out \
        --threads !{task.cpus}
    '''
}

// Build the vConTACT2 protein-info table from a tilde-separated (genome~protein) FAA header
process build_proteins_fp {
    label "process_single"
    container "${params.container__shellbasic}"

    input:
        path(tilde_separated_proteins_faa)

    output:
        path "proteins_fp.tsv", emit: proteins_fp_tsv

    shell:
    '''
    echo -e "protein_id\tcontig_id\tkeywords" > proteins_fp.tsv
    grep '^>' !{tilde_separated_proteins_faa} | \
        sed 's/>//g' | \
        awk '{
            out = $1;
            gsub(/~.*/, "", $1);
            out = out "\t" $1;
            $1 = "";
            print out "\t" $0}' >> \
        proteins_fp.tsv
    '''
}
