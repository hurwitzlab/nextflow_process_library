#!/usr/bin/env nextflow

/*
Notes (here instead of process, so hash of script doesn't change)

primer definition:
- Include a caret so the adapter is 5' anchored (must be at the start)
- for merged reads, linked adapters specified by '...'
- for merged reads, use -g (not -a) so both are required

paramaters:
- --minimum-length specifies length of read after trimming
- --overlap (minimum overlap) default is 3, but we want more of the primer to match

TODO:
- should compute length of minimum primer to specify minimum length / overlap

*/

// Trim amplicon primer sequences from merged paired-end reads
process trim_merged_fastq {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__cutadapt}"

    time '30m'

    input:
        tuple val(sampleid), path(merged_reads, stageAs: "merged.fastq.gz")
        val(adapters) // Expect adapters as a string in format "<5' adapter>-<3' adapter>,<5' adapter>-<3' adapter>,..."
                      // 5' and 3' Adapters should be oriented relative to the merged read

    output:
        tuple val(sampleid), path("trimmed.fastq.gz"), emit: trimmed_reads
        tuple val(sampleid), path("untrimmed.fastq.gz"), emit: untrimmed_reads
        tuple val(sampleid), path("cutadapt.log"), emit: log
        tuple val(sampleid), path("stats.json"), emit: stats

    shell:
    '''
    # This is annoying for some reason the last $2 prints a newline, so I need to strip it before setting the adapters
    CUTADAPT_ADAPTERS=$(echo "!{adapters}" | awk  'BEGIN{ RS = "," ; FS = "-"; ORS=" " } {print ("-g ^" $1 "..."$2 "\$") }' | paste -sd "")

    cutadapt ${CUTADAPT_ADAPTERS} \
    --output trimmed.fastq.gz \
    --minimum-length 10 \
    --untrimmed-output untrimmed.fastq.gz \
    --json stats.json \
    --cores !{task.cpus} \
    --no-indels \
    !{merged_reads} \
     > cutadapt.log
    '''
}

// Trim unmerged reads, i.e. trim the forward primer on a single-end reads file
process trim_single_fastq {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__cutadapt}"

    time '30m'

    input:
        tuple val(sampleid), path(reads, stageAs: "reads.fastq")
        val(adapters)

    output:
        tuple val(sampleid), path("trimmed.fastq"), emit: trimmed_reads
        tuple val(sampleid), path("untrimmed.fastq"), emit: untrimmed_reads
        tuple val(sampleid), path("cutadapt.log"), emit: log
        tuple val(sampleid), path("stats.json"), emit: stats

    shell:
    '''
    CUTADAPT_ADAPTERS=$(echo "!{adapters}" | awk  'BEGIN{ RS = "," ; FS = "-"; ORS="\\t" } {print "-g ^" $1 }')

    cutadapt ${CUTADAPT_ADAPTERS} \
    --minimum-length 10 \
    --overlap 8 \
    --output trimmed.fastq \
    --untrimmed-output untrimmed.fastq \
    --json stats.json \
    --revcomp \
    --cores !{task.cpus} \
    !{reads} \
     > cutadapt.log
    '''
}

// Trim paired-end amplicon reads (forward and reverse primers)
process trim_amplicon_reads {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__cutadapt}"

    time '30m'

    input:
        tuple val(sampleid), path(r1, stageAs: "r1.fq.gz"), path(r2, stageAs: "r2.fq.gz")
        val(adapters) // Expect adapters as a string in format "<5' adapter>-<3' adapter>,<5' adapter>-<3' adapter>,..."
                      // 5' and 3' Adapters should be oriented relative to the merged read

    output:
        tuple val(sampleid), path("r1.trimmed.fq.gz"), emit: trimmed_r1
        tuple val(sampleid), path("r2.trimmed.fq.gz"), emit: trimmed_r2
        tuple val(sampleid), path("untrimmed.r1.fq.gz"), emit: untrimmed_r1
        tuple val(sampleid), path("untrimmed.r2.fq.gz"), emit: untrimmed_r2
        tuple val(sampleid), path("cutadapt.log"), emit: log
        tuple val(sampleid), path("stats.json"), emit: stats

    shell:
    '''
    echo "!{adapters}" | awk  'BEGIN{ RS = "," ; FS = "-" } {print $1}' > r1_adapters.txt
    # the tr + rev reverse complements the adapters, head is needed because $2 writes an extra line after the last adapter
    echo "!{adapters}" | awk  'BEGIN{ RS = "," ; FS = "-" } {print $2}' | tr ACGTacgt TGCAtgca | rev | head -n -1 > r2_adapters.txt
    CUTADAPT_ADAPTERS=$(paste r1_adapters.txt r2_adapters.txt | awk  'BEGIN{ORS="\\t" } {print "-g ^" $1 " -G ^" $2}')

    cutadapt ${CUTADAPT_ADAPTERS} \
    --minimum-length 10 \
    --output r1.trimmed.fq.gz \
    --paired-output r2.trimmed.fq.gz \
    --untrimmed-output untrimmed.r1.fq.gz \
    --untrimmed-paired-output untrimmed.r2.fq.gz \
    --json stats.json \
    --cores !{task.cpus} \
    --quality-cutoff 25 \
    --nextseq-trim 25 \
    --pair-adapters \
    --action retain \
    --no-indels \
    !{r1} !{r2}  > cutadapt.log
    '''
}
