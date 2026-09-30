#!/usr/bin/env nextflow

// Generate a multiple sequence alignment for each fasta file in a directory with MUSCLE
process generate_multiple_sequence_alignment_dir {
    label "process_high"
    container "${params.container__muscle}"
    // No sampleid here (aligns a whole directory of fastas, not per-sample)
    // so the Closure-based publishDir convention doesn't apply -- stays a
    // plain path.
    publishDir "${params.muscle_outdir}", mode: 'copy'

    input:
        path(fasta_archive)

    output:
        path("alignments.tar.gz"), emit: aligned_sequences_archive

    shell:
    '''
    # unzip directory of fastas
    mkdir fastas
    tar -xvzf !{fasta_archive} -C fastas

    # generate alignments into aln
    mkdir aln
    mkdir log
    ls -1 fastas | xargs -I{} -n1 -P !{task.cpus} bash -c 'echo "start {}" && muscle -in "fastas/{}" -out "aln/{}" -maxiters 5 2>&1 > "log/{}" && echo "done {}" || echo "failed {}"'

    # debugging stats
    echo 'produced alignments, tarballing...'
    ls aln | wc -l
    du aln

    # create tarball in context of aln (so only contains files)
    tar -cvzf alignments.tar.gz -C aln .
    '''
}
