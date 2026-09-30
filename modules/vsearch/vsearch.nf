#!/usr/bin/env nextflow

// Find unique amplicon sequences
process count_unique_amplicons {
    label "process_low"
    container "${params.container__vsearch}"

    input:
        tuple val(sampleid), path(trimmed_reads)

    output:
        tuple val(sampleid), path("uniques.fasta"), emit: unique_amplicons

    shell:
    '''
    vsearch --derep_fulllength !{trimmed_reads} \
      --sizeout \
      --relabel Uniq \
      --output uniques.fasta
    '''
}

// Collapse amplicon sequences into single amplicons by denoising
process denoise_amplicons {
    label "process_low"
    container "${params.container__vsearch}"

    input:
        tuple val(sampleid), path(unique_amplicons)

    output:
        tuple val(sampleid), path("zotus.fasta"), emit: zotus
        tuple val(sampleid), path("vsearch.log"), emit: log

    shell:
    '''
    vsearch --cluster_unoise !{unique_amplicons} \
      --threads !{task.cpus} \
      --centroids zotus.fasta \
      --log vsearch.log
    '''
}

// Detect chimeras de novo
process detect_chimeras_de_novo {
    label "process_low"
    container "${params.container__vsearch}"

    input:
        tuple val(sampleid), path(zotus)

    output:
        tuple val(sampleid), path("nonchimeras.fasta"), emit: nonchimeras
        tuple val(sampleid), path("chimeras.fasta"), emit: chimeras

    shell:
    '''
    vsearch --uchime3_denovo !{zotus} \
      --threads !{task.cpus} \
      --nonchimeras nonchimeras.fasta \
      --chimeras chimeras.fasta
    '''
}

// Count reads assigned to each denoised zOTU
process count_denoised_amplicons {
    label "process_low"
    label "publish_final"
    container "${params.container__vsearch}"

    input:
        tuple val(sampleid), path(trimmed_reads), path(zotus)
        val(maxdiffs_int) // Max number of differences allowed between read and zOTU for a match

    output:
        tuple val(sampleid), path("zotu_counts.txt"), emit: zotu_counts
        tuple val(sampleid), path("zotu_assignments.txt"), emit: zotu_assignments

    shell:
    '''
    vsearch --usearch_global !{trimmed_reads} \
      --db !{zotus} \
      --id 0.9 \
      --maxdiffs !{maxdiffs_int} \
      --minseqlength 10 \
      --notrunclabels \
      --threads !{task.cpus} \
      --quiet \
      --otutabout zotu_counts.txt \
      --blast6out zotu_blastout.txt
    cut -f 1,2 zotu_blastout.txt > zotu_assignments.txt
    '''
}

// Detects chimeras in trimmed reads
// This aggregates `count_unique_amplicons` `denoise_amplicons` `detect_chimeras_de_novo`
// into a single process, because the intermediates are not very useful
// because they have been renamed, and include the size of the cluster in the name.
process detect_chimeras_from_reads {
    label "process_low"
    label "publish_final"
    container "${params.container__vsearch}"

    input:
        tuple val(sampleid), path(trimmed_reads)

    output:
        tuple val(sampleid), path("uniques.fasta"), emit: unique_amplicons
        tuple val(sampleid), path("centroids.fasta"), emit: centroids
        tuple val(sampleid), path("nonchimeras.fasta"), emit: nonchimeras
        tuple val(sampleid), path("chimeras.fasta"), emit: chimeras

    shell:
    '''
    # This function cleans fasta entry names to remove semi colons and anything after them
    # vsearch has poorly documented behavior of removing everything after a semi colon
    # I think the expected behavior is to drop ;size=[0-9]+ but it seems to drop everything
    # even if the semicolon is in the read. So, we drop everything after semi colons so we can join.
    function fasta_remove_semicolons() {
        awk '/^>/ {sub(/;.+/, "", $0)} {print}' "$1"
    }

    # Counts unique sequences
    # renamed, prefixed with Uniq and a number
    # name also includes a size, which is required for chimera detection
    vsearch --derep_fulllength !{trimmed_reads} \
      --sizeout \
      --relabel Uniq \
      --output uniques.fasta

    # cluster the unique sequences
    vsearch --cluster_unoise uniques.fasta \
      --threads !{task.cpus} \
      --centroids centroids.fasta \
      --log vsearch.log

    # detect chimeras de novo
    vsearch --uchime3_denovo centroids.fasta \
      --threads !{task.cpus} \
      --relabel_keep \
      --nonchimeras nonchimeras_with_counts.fasta \
      --chimeras chimeras_with_counts.fasta

    # rename the chimeras and non-chimeras without the count in the fasta entry name
    # vsearch has poorly documented behavior, when you match against these as ZOTUs, of dropping the size,
    # which makes joining in count_denoised_amplicons impossible.
    fasta_remove_semicolons nonchimeras_with_counts.fasta > nonchimeras.fasta
    fasta_remove_semicolons chimeras_with_counts.fasta > chimeras.fasta
    '''
}

// For each read assign it to its closest zOTU
// This is also the primary way to match to expected amplicons
process match_amplicons {
    label "process_low"
    label "publish_final"
    container "${params.container__vsearch}"

    input:
        tuple val(sampleid), path(trimmed_reads)  // query sequences, trimmed reads
        path(expected_amplicons)  // target sequences, expected amplicons (shared reference)
        val(maxdiffs_int) // Max number of differences allowed between read and zOTU for a match
        val(unmatched_cluster_id) // float [0,1], identity threshold for clustering unmatched amplicons

    output:
        tuple val(sampleid), path("match_counts.tsv"), emit: match_counts  // TSV amplicon_name, amplicon_sequence, count
        tuple val(sampleid), path("match_assignments.tsv"), emit: match_assignments  // TSV read_name, amplicon_name
        tuple val(sampleid), path("unmatched_counts.tsv"), emit: unmatched_counts  // TSV amplicon_sequence, count

    shell:
    '''
    set -euxo pipefail

    ### Helpers ###
    # this function converts a fasta file (with breaks) into a TSV in the form name, seq
    # it takes the fasta path as the first argument, and streams out the tsv
    function fasta_to_tsv() {
        awk '{
            if ($1 ~ /^>/) {
                if (seq) {
                    print name "\t" seq;
                    seq = "";
                }
                name = substr($1, 2);
            } else {
                seq = seq $0;
            }
        }
        END {
            if (seq) print name "\t" seq;
        }' "$1" | sed 's/ //g'
    }

    # removes semi colons from read names in a fasta file
    function fasta_remove_semicolons() {
        awk '/^>/ {sub(/;.+/, "", $0)} {print}' "$1"
    }


    ### Setup ###

    # vsearch just picks the first match, and we want to prioritize WT matches
    # and then put the remaining amplicons to match against all ZOTUs.
    # We assume that the first amplicon in expected_amplicons is WT.

    awk '/^>/ {n++} n>1 {exit} {print}' !{expected_amplicons} > wt_targets.fasta
    awk '/^>/ {n++} n>1 {print}' !{expected_amplicons} > non_wt_targets.fasta

    ### WT Matching ###
    # First, we map to the WT zotus, and pass through the remaining queries.

    # this command is nearly the same as below, except we do not include --output_no_hits
    # we only want assignments to WT, and will merge with all assignments for remaining.fasta
    vsearch --usearch_global !{trimmed_reads} \
      --db wt_targets.fasta \
      --id 0.9 \
      --maxdiffs !{maxdiffs_int} \
      --minseqlength 10 \
      --notrunclabels \
      --threads !{task.cpus} \
      --quiet \
      --notmatched remaining.fasta \
      --otutabout wt_zotu_counts.tsv \
      --blast6out wt_zotu_blastout.tsv

    ### Non-WT Matching ###
    # run vsearch the normal way, matching remaining.fasta queries to targets

    vsearch --usearch_global remaining.fasta \
      --db non_wt_targets.fasta \
      --id 0.9 \
      --maxdiffs !{maxdiffs_int} \
      --minseqlength 10 \
      --notrunclabels \
      --threads !{task.cpus} \
      --quiet \
      --output_no_hits \
      --notmatched unmatched.fasta \
      --otutabout zotu_counts.tsv \
      --blast6out zotu_blastout.tsv

    ### Merge WT and non-WT matches ###

    # skip the header of zotu_counts to produce count tsv
    tail -n +2 wt_zotu_counts.tsv >> name_only_match_counts.tsv
    tail -n +2 zotu_counts.tsv >> name_only_match_counts.tsv

    # add amplicon_name to the tsv as the second column
    fasta_to_tsv !{expected_amplicons} > zotus.tsv
    join -1 1 -2 1 -t $'\t' -o 1.1,1.2,2.2 <(sort zotus.tsv) <(sort name_only_match_counts.tsv) > match_counts.tsv

    # just pick the read name and centroid (* for unassigned)
    cut -f 1,2 wt_zotu_blastout.tsv >> match_assignments.tsv
    cut -f 1,2 zotu_blastout.tsv >> match_assignments.tsv

    ### Collapse unmatched reads ###
    # for the unmatched amplicons, cluster the uniques into centroids
    # this will merge substrings into the centroid

    # minimum cluster size is 1, so all sequences will be accounted for
    vsearch --cluster_unoise unmatched.fasta \
      --id !{unmatched_cluster_id} \
      --minsize 1 \
      --minseqlength 10 \
      --threads !{task.cpus} \
      --quiet \
      --centroids unmatched_centroids.fasta \
      --otutabout unmatched_counts_by_read.tsv

    # --otutabout outputs read names without semi colons
    # the centroids should match the input read names, which may have semi colons
    # so, we remove semi-colons the centroids, so they will be joinable
    fasta_remove_semicolons unmatched_centroids.fasta > unmatched_centroids_renamed.fasta
    fasta_to_tsv unmatched_centroids_renamed.fasta > unmatched_centroid_sequences.tsv

    # convert unmatched counts named-by-read to named-by-sequence
    join -1 1 -2 1 -t $'\t' -o 1.2,2.2 <(sort unmatched_centroid_sequences.tsv) <(sort unmatched_counts_by_read.tsv) > unmatched_counts.tsv
    '''
}
