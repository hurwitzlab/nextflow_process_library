#!/usr/bin/env nextflow

// Merge overlapping paired-end reads for a sample with BBMerge
process merge_fastqs {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__bbmerge}"

    input:
        tuple val(sampleid), path(r1), path(r2)
        val(adapters) // Expect adapters as a string in format "<5' adapter>-<3' adapter>,<5' adapter>-<3' adapter>,..."
                      // 5' and 3' Adapters should be oriented relative to the merged read

    output:
        tuple val(sampleid), path("${sampleid}.merged.fq.gz"), emit: merged_reads
        tuple val(sampleid), path("${sampleid}.unaligned.r1.fq.gz"), emit: unmerged_r1
        tuple val(sampleid), path("${sampleid}.unaligned.r2.fq.gz"), emit: unmerged_r2
        tuple val(sampleid), path("${sampleid}.adapters.fq"), emit: detected_adapters
        tuple val(sampleid), path("${sampleid}.log.txt"), emit: log

    shell:
    '''
    # Make r1 and r2 adapters fastas for bbmerge
    echo !{adapters} | awk 'BEGIN { RS = "," ; FS = "-"} {print ">adapter_1_" NR; print $1}' > adapter_r1.fa
    echo !{adapters} | awk 'BEGIN { RS = "," ; FS = "-"} {print ">adapter_2_" NR; print $2}' > adapter_r2.fa

    bbmerge.sh in1=!{r1} \
               in2=!{r2} \
               adapter1=adapter_r1.fa \
               adapter2=adapter_r2.fa \
               out=!{sampleid}.merged.fq.gz \
               outu1=!{sampleid}.unaligned.r1.fq.gz \
               outu2=!{sampleid}.unaligned.r2.fq.gz \
               outadapter=!{sampleid}.adapters.fq \
               veryloose 2> !{sampleid}.log.txt
    '''
}
