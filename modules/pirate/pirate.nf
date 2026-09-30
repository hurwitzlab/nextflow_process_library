#!/usr/bin/env nextflow

// Generate a pangenome given multiple input genomes in GFF format (preferably in a format similar
// to prokka). Please be sure that genomes used as inputs are relatively complete and free of
// contamination, and are strains of the same species.
process build_pangenome {
    label "process_high"
    container "${params.container__pirate}"
    // No sampleid here (builds one pangenome across multiple input genomes,
    // not per-sample) so the Closure-based publishDir convention doesn't
    // apply -- stays a plain path.
    publishDir "${params.pirate_outdir}", mode: 'copy'

    input:
        path(gff_dir)
        val(skip_align) // pass any value to skip, or "" to do alignments (adds days to the runtime)

    output:
        path "output/PIRATE.gene_families.ordered.tsv",    emit: gene_families_ordered
        path "output/PIRATE.gene_families.tsv",            emit: gene_families
        path "output/PIRATE.unique_alleles.tsv",           emit: unique_alleles
        path "output/PIRATE.pangenome_summary.txt",        emit: pangenome_summary
        path "output/core_alignment.fasta",                emit: core_alignment
        path "output/pangenome.connected_blocks.tsv",      emit: pangenome_connected_blocks
        path "output/pangenome.gfa",                       emit: pangenome_graph
        path "output/PIRATE.locus_id_translation.csv",     emit: locus_id_translation
        path "output/PIRATE_plots.pdf",                    emit: pangenome_plots
        path "output/feature_sequences.aa.tar.gz",         emit: feature_sequences_aa
        path "output/feature_sequences.nucleotide.tar.gz", emit: feature_sequences_nucleotide
        path "output",                                     emit: pangenome_output_dir, type: 'dir'

    shell:
    '''
    # set a trap so we unstage whatever we have
    check_error() {
        exit_code=$1
        echo 'custom error handler...'
        echo "original exit code: $exit_code"
        exit 0
    }
    trap 'check_error $?' EXIT

    # determine whether to align, based on input val
    if [ -z "!{skip_align}" ]; then
        align_flag="--align"
    else
        align_flag=""
    fi

    PIRATE \
        --threads !{task.cpus} \
        "${align_flag}" \
        --rplots \
        --input !{gff_dir} \
        -k "--diamond --diamond-split" \
        --output output

    # Generate locus_id translation table for compatibility with inputs (PIRATE renames them)
    echo "strain,pirate_locus,prev_locus" > output/PIRATE.locus_id_translation.csv
    for strain in `ls output/modified_gffs | sed 's/.gff//g'`
    do
        cat output/modified_gffs/$strain.gff | \
            awk -F '\t' '$3 == "CDS" {print $9}' | \
            sed "s/^ID=\([^;]*\);.*;prev_locus=\([^;]*\).*/${strain},\1,\2/g" >> \
            output/PIRATE.locus_id_translation.csv
    done

    # if we skipped alignment, create optional alignment outputs as empty file
    if [ -z "!{skip_align}" ]; then
        # create tarballs in context of feature_sequences (so only contains files)
        tar -czvf output/feature_sequences.aa.tar.gz -C output/feature_sequences `ls output/feature_sequences | grep aa.fasta`
        tar -czvf output/feature_sequences.nucleotide.tar.gz -C output/feature_sequences `ls output/feature_sequences | grep nucleotide.fasta`
    else
        touch output/core_alignment.fasta
        touch output/feature_sequences.aa.tar.gz
        touch output/feature_sequences.nucleotide.tar.gz
    fi
    '''
}
