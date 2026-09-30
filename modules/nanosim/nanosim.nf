#!/usr/bin/env nextflow

// Profile a sample's ONT reads against a reference genome to estimate per-read error rates with NanoSim
process nanosim_read_analysis {
    label "process_medium"
    label "publish_final"
    container "${params.container__nanosim}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(ont_reads)
        path(reference)

    output:
        tuple val(sampleid), path("${sampleid}_NanoSim_out/result_error_rate.tsv"), emit: error_rate_table
        tuple val(sampleid), path("${sampleid}_NanoSim_out"), emit: results_dir

    shell:
    '''
    # remove the alignment and leave it for the module after samtools read-header length issue is fixed
    minimap2 --cs -ax map-ont -t !{task.cpus} !{reference} !{ont_reads} > result.sam

    read_analysis.py genome \
            -rg !{reference} \
            -ga result.sam \
            --no_model_fit \
            -t !{task.cpus} \
            -i !{ont_reads} \
            -o !{sampleid}_NanoSim_out/result
    '''
}

// Estimate strain identity and abundance for a sample's ONT metagenomic reads against a reference index with NanoSim/minimap2
process alignment_analysis {
    label "process_high"
    label "publish_final"
    container "${params.container__nanosim}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(ont_reads)
        path(minimap_index)

    output:
        tuple val(sampleid), path("${sampleid}.abundance.tsv"), emit: abundance_table

    shell:
    '''
    # align reads to the universe of bacterial starins
    minimap2 -a \
            --split-prefix tmp \
            -t !{task.cpus} \
            --secondary=no \
            --sam-hit-only \
            !{minimap_index} \
            !{ont_reads} \
            > result.sam

    samtools sort --threads !{task.cpus} -O bam -o result_sorted.bam result.sam
    samtools index -b result_sorted.bam result_sorted.bam.bai

    COLUMNS='sample_id reference_id map_count map_rate abundance'
    echo $COLUMNS | tr ' ' '\t' > !{sampleid}.abundance.tsv

    TOTAL_READS=$(($(zcat !{ont_reads} | wc -l) / 4))

    # use samtools -F 2308 & idxstats to get non-redundant alignment counts for each ref_id
    # awk used to merge the counts of a multi-contig draft genome into a total count stat
    samtools view --threads !{task.cpus} -h -F 2308 result_sorted.bam | \
    samtools idxstats - | \
    awk -v sample=!{sampleid} -v c=${TOTAL_READS} -v OFS='\t' '
    $3>0 {
        ref_id = substr($1, 0, match($1,/_[^_]*$/)-1);
        a[ref_id] += $3;
        s += $3;
    }
    END {for(x in a) print sample, x, a[x], a[x]/c, a[x]/s}
    ' | sort -nrk3 >> !{sampleid}.abundance.tsv
    '''
}
