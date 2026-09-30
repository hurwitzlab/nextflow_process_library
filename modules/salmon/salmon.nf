#!/usr/bin/env nextflow

// Quantify reads already aligned to a reference transcriptome
process quantify_transcripts_aligned {
    label "process_medium"
    label "publish_final"
    container "${params.container__salmon}"

    input:
        tuple val(sampleid), path(aligned_reads)
        path(transcripts)

    output:
        // https://salmon.readthedocs.io/en/latest/file_formats.html#fileformats
        tuple val(sampleid), path("${sampleid}/quant.sf"), emit: quantifications
        tuple val(sampleid), path("${sampleid}/aux_info/meta_info.json"), emit: meta_info
        tuple val(sampleid), path("${sampleid}/aux_info/ambig_info.tsv"), emit: ambig_info

    shell:
    '''
    salmon quant \
    --threads !{task.cpus} \
    --libtype A \
    --seqBias \
    --gcBias \
    --targets !{transcripts} \
    --alignments !{aligned_reads} \
    --minAssignedFrags 1 \
    --output !{sampleid}
    '''
}

// Quantify unmapped reads directly against a reference transcriptome (mapping-based mode)
// https://salmon.readthedocs.io/en/latest/salmon.html#quantifying-in-mapping-based-mode
// TODO - use decoys when building index, but account for UTRs in genome but missing in CDS used as transcripts
process quantify_transcripts_mapping_mode {
    label "process_medium"
    label "publish_final"
    container "${params.container__salmon}"

    input:
        tuple val(sampleid), path(r1_fq_gz), path(r2_fq_gz)
        path(transcripts)

    output:
        // https://salmon.readthedocs.io/en/latest/file_formats.html#fileformats
        tuple val(sampleid), path("${sampleid}/quant.sf"), emit: quantifications
        tuple val(sampleid), path("${sampleid}/aux_info/meta_info.json"), emit: meta_info
        tuple val(sampleid), path("${sampleid}/aux_info/ambig_info.tsv"), emit: ambig_info

    shell:
    '''
    # build index
    # -t targets, -i output index, -k kmer length
    salmon index \
    --threads !{task.cpus} \
    -t !{transcripts} \
    -i !{sampleid}_transcripts_index \
    -k 31

    # unzip reads to predictable filenames
    gunzip -c !{r1_fq_gz} > r1.fq
    gunzip -c !{r2_fq_gz} > r2.fq

    # quant reads
    # -l library type, -i index (above), -1 r1, -2 r2, --validateMappings for better strategy, --output output
    salmon quant \
    --threads !{task.cpus} \
    -l A \
    --seqBias \
    --gcBias \
    -i !{sampleid}_transcripts_index \
    -1 r1.fq \
    -2 r2.fq \
    --minAssignedFrags 1 \
    --validateMappings \
    --output !{sampleid}
    '''
}
