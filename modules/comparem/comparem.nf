#!/usr/bin/env nextflow

// Identify the best-matching reference genome for a sample's genome by average amino acid identity (AAI) with CompareM
process identify_reference_genome {
    label "process_low"
    label "publish_final"
    container "${params.container__comparem}"

    input:
        tuple val(sampleid), path(query_genome)
        path(comparem_db)

    output:
        tuple val(sampleid), path("classify/classify/aai/aai_summary.tsv"), emit: aai_summary
        tuple val(sampleid), path("good_references.tsv"), emit: good_references
        tuple val(sampleid), path("reference.txt"), emit: best_reference

    shell:
    '''
    mkdir database phage_genome
    tar -xvf !{comparem_db} -C database
    cp !{query_genome} phage_genome/

    comparem classify_wf phage_genome/ database/ classify -c !{task.cpus}

    # manually curate aai_summary for good references
    # add our own columns: "Sample Coverage", and "OFxAAI" (used for sort criteria)
    # and use an internal pipe redirect to sort the references by OFxAAI
    awk -F'\t' '{
        if ($1 ~ /^#Genome/) { print $0 FS "Sample Coverage" FS "OFxAAI";
        next;
    }
    if ($5=="0") {next;}
    COV_SAMPLE=($5/$2*100);
    COV_REF=($8);
    MEAN_AAI=$6;
    if (COV_SAMPLE < 20) {next;}
    if (COV_REF < 50) {next;}
    if (MEAN_AAI < 60) {next;}
    print $0 FS COV_SAMPLE FS (COV_SAMPLE*MEAN_AAI/100) | "sort -k10 -nr"
    }' classify/classify/aai/aai_summary.tsv > good_references.tsv

    # if our heuristics provide 1 or more references, use the best, otherwise use compareM as default
    if [[ $(wc -l <good_references.tsv) -ge 2 ]]; then
        head -n2 good_references.tsv | tail -n1 | cut -f3 > reference.txt
    else
        tail -n1 classify/classify/classify.tsv | cut -f2 > reference.txt
    fi
    '''
}

// Rank candidate reference genomes against a set of query genomes by average amino acid identity (AAI) with CompareM
// Expects faa genomes and references, to avoid an issue when comparem calls prodigal and no proteins are found.
process find_candidate_references {
    label "process_high"
    container "${params.container__comparem}"
    // NOTE: no sampleid in scope -- this ranks references across a whole
    // directory of query genomes at once, not per sample.
    publishDir "${params.comparem_outdir}", mode: 'copy'

    input:
        path(query_genomes_dir)
        path(candidate_references_dir)

    output:
        path("classify/classify/aai/aai_summary.tsv"), emit: candidate_aai_summary
        path("good_references.tsv"), emit: ranked_candidate_references

    shell:
    '''
    comparem classify_wf !{query_genomes_dir}/ !{candidate_references_dir}/ classify -c !{task.cpus} --file_ext '' --proteins

    # manually curate aai_summary for good references
    # add our own columns: "Sample Coverage", and "OFxAAI" (used for sort criteria)
    # and use an internal pipe redirect to sort the references by OFxAAI
    awk -F'\t' '{
    if ($1 ~ /^#Genome/) { print $0 FS "Sample Coverage" FS "OFxAAI";
        next;
    }
    if ($5=="0") {next;}
    COV_SAMPLE=($5/$2*100);
    COV_REF=($8);
    MEAN_AAI=$6;
    if (COV_SAMPLE < 5) {next;}
    if (COV_REF < 20) {next;}
    if (MEAN_AAI < 50) {next;}
    print $0 FS COV_SAMPLE FS (COV_SAMPLE*MEAN_AAI/100) | "sort -k1,1 -k10nr"
    }' classify/classify/aai/aai_summary.tsv > good_references.tsv
    '''
}
