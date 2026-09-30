#!/usr/bin/env nextflow

// Classify a sample's genome taxonomy with GTDB-Tk
// https://github.com/Ecogenomics/GTDBTk
// https://ecogenomics.github.io/GTDBTk/
process gtdbtk_classify_genome {
    label "process_high"
    label "publish_final"
    container "${params.container__gtdbtk}"

    input:
        tuple val(sampleid), path(genome, stageAs: "genome.fna")
        val(database)

    output:
        tuple val(sampleid), path("${sampleid}_gtdbtk.summary.tsv"), emit: classification_summary
        tuple val(sampleid), path("${sampleid}_gtdbtk.classify.tree"), emit: classification_tree
        tuple val(sampleid), path("${sampleid}_output/gtdbtk.log"), emit: gtdbtk_log
        tuple val(sampleid), path("${sampleid}_output/identify"), emit: identify_results
        tuple val(sampleid), path("${sampleid}_output/align"), emit: align_results

    shell:
    '''
    file_handler !{database}
    export GTDBTK_DATA_PATH=!{database}

    mkdir genomes
    mv !{genome} genomes/

    # If no marker genes are assigned then the classify folder won't be created.
    # GTDB-tk assumes !{sampleid}_output/classify exists before writing to !{sampleid}_output/classify/gtdbtk.bac120.summary.tsv
    # If the folder doesn't exist the program crashes; pre-making the classify folder prevents this error from occurring
    mkdir -p !{sampleid}_output/classify

    # If !{sampleid}_output/align doesn't exist with a file in the folder align_results will not be output
    # crashing the process
    mkdir -p !{sampleid}_output/align
    touch !{sampleid}_output/align/dummy.txt

    gtdbtk classify_wf \
        --cpus !{task.cpus} \
        --genome_dir genomes \
        --out_dir !{sampleid}_output

    # Count outputs
    num_summaries="$(ls 2>/dev/null -1 !{sampleid}_output/classify/gtdbtk.*.summary.tsv | wc -l)"
    num_trees="$(ls 2>/dev/null -1 !{sampleid}_output/classify/gtdbtk.*.classify.tree | wc -l)"

    # Emit empty files if we have no outputs
    if [[ "$num_summaries" -eq 0 ]]
    then
        touch !{sampleid}_output/classify/gtdbtk.empty.summary.tsv
    fi
    if [[ "$num_trees" -eq 0 ]]
    then
        touch !{sampleid}_output/classify/gtdbtk.empty.classify.tree
    fi

    # Make sure we only have one output
    if [[ "$num_summaries" -gt 1 || "$num_trees" -gt 1 ]]
    then
        echo "More than one output detected"
        exit 1
    fi

    # Outputs are named dynamically dep. on Kingdom (Archaea vs. Bacteria), standardize
    # Keep files in classify otherwise identify_results will not be output
    cp !{sampleid}_output/classify/gtdbtk.*.summary.tsv !{sampleid}_gtdbtk.summary.tsv
    cp !{sampleid}_output/classify/gtdbtk.*.classify.tree !{sampleid}_gtdbtk.classify.tree
    '''
}
