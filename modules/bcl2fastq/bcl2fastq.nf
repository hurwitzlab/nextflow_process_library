#!/usr/bin/env nextflow

// Demultiplex raw sequencing reads from a run folder into per-sample FASTQs with bcl2fastq
process demux {
    label "process_high"
    container "${params.container__bcl2fastq}"
    // NOTE: no sampleid in scope -- demux runs once per sequencing run, not
    // per sample (that's the whole point of this process; not a convention
    // gap). Left as a plain string; the Closure pattern needs sampleid.
    publishDir "${params.bcl2fastq_outdir}", mode: 'copy'

    input:
        path(runfolder)

    output:
        path("output"), emit: demuxed_reads

    shell:
    '''
    mkdir output
    bcl2fastq --runfolder-dir !{runfolder} --output-dir output --interop-dir InterOp/
    '''
}

// Demultiplex raw sequencing reads from a run folder using an explicit sample sheet with bcl2fastq
process demux_samplesheet {
    label "process_high"
    container "${params.container__bcl2fastq}"
    // NOTE: no sampleid in scope -- see demux above.
    publishDir "${params.bcl2fastq_outdir}", mode: 'copy'

    input:
        path(runfolder)
        path(samplesheet)

    output:
        path("output"), emit: demuxed_reads

    shell:
    '''
    mkdir output
    bcl2fastq --runfolder-dir !{runfolder} --sample-sheet !{samplesheet} --output-dir output --interop-dir InterOp/
    '''
}
