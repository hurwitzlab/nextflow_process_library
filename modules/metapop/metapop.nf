#!/usr/bin/env nextflow

// Run with: assuming some upstream channel emits (sampleid, bam) tuples
//   bam_ch
//     .map { sampleid, bam -> bam }
//     .collect()
//     .set { all_bams }
//   metapop_micro(all_bams, votu_fasta)
//
// Each process runs once across all sample BAMs together. MetaPop reads every
// file in the reference directory as FASTA, so pass only the reference
// FASTA(s). params.metapop_ref_sample is a BAM filename minus .bam.
// https://github.com/metaGmetapop/metapop

// Filter reads by percent identity/length and contigs by breadth/depth of coverage with MetaPop (preprocessing only)
process metapop_preprocess {
    label "process_high"
    container "${params.container__metapop}"
    publishDir "${params.metapop_preprocess_outdir}", mode: 'copy'

    input:
        path(bam_files, stageAs: "input_bams/*")
        path(reference, stageAs: "reference/*")

    output:
        path("metapop_out/MetaPop/02.Filtered_Samples"), emit: filtered_samples
        path("metapop_out/MetaPop/03.Breadth_and_Depth"), emit: breadth_and_depth
        path("metapop_out/MetaPop"), emit: metapop_results

    shell:
    '''
    # Fail early on truncated BAMs from failed mapping jobs
    samtools quickcheck -v input_bams/*.bam

    metapop \
    --input_samples input_bams \
    --reference reference \
    --output metapop_out \
    --preprocess_only \
    --threads !{task.cpus} \
    --id_min !{params.metapop_id_min} \
    --min_len !{params.metapop_min_len} \
    --min_cov !{params.metapop_min_cov} \
    --min_dep !{params.metapop_min_dep}
    '''
}

// Estimate within-population (micro) diversity of contigs with MetaPop (preprocessing + microdiversity, no macrodiversity)
process metapop_micro {
    label "process_high"
    container "${params.container__metapop}"
    publishDir "${params.metapop_micro_outdir}", mode: 'copy'

    input:
        path(bam_files, stageAs: "input_bams/*")
        path(reference, stageAs: "reference/*")

    output:
        path("metapop_out/MetaPop/03.Breadth_and_Depth"), emit: breadth_and_depth
        path("metapop_out/MetaPop/10.Microdiversity"), emit: microdiversity
        path("metapop_out/MetaPop"), emit: metapop_results

    shell:
    '''
    # Fail early on truncated BAMs from failed mapping jobs
    samtools quickcheck -v input_bams/*.bam

    metapop \
    --input_samples input_bams \
    --reference reference \
    --output metapop_out \
    --no_macro \
    --threads !{task.cpus} \
    --id_min !{params.metapop_id_min} \
    --min_len !{params.metapop_min_len} \
    --min_cov !{params.metapop_min_cov} \
    --min_dep !{params.metapop_min_dep} \
    !{params.metapop_ref_sample ? "--ref_sample " + params.metapop_ref_sample : ""}
    '''
}

// Estimate within-population (micro) and between-sample (macro) diversity of contigs with MetaPop (full run: preprocessing + microdiversity + macrodiversity)
process metapop_micro_macro {
    label "process_high"
    container "${params.container__metapop}"
    publishDir "${params.metapop_micro_macro_outdir}", mode: 'copy'

    input:
        path(bam_files, stageAs: "input_bams/*")
        path(reference, stageAs: "reference/*")

    output:
        path("metapop_out/MetaPop/03.Breadth_and_Depth"), emit: breadth_and_depth
        path("metapop_out/MetaPop/10.Microdiversity"), emit: microdiversity
        path("metapop_out/MetaPop/11.Macrodiversity"), emit: macrodiversity
        path("metapop_out/MetaPop"), emit: metapop_results

    shell:
    '''
    # Fail early on truncated BAMs from failed mapping jobs
    samtools quickcheck -v input_bams/*.bam

    metapop \
    --input_samples input_bams \
    --reference reference \
    --output metapop_out \
    --threads !{task.cpus} \
    --id_min !{params.metapop_id_min} \
    --min_len !{params.metapop_min_len} \
    --min_cov !{params.metapop_min_cov} \
    --min_dep !{params.metapop_min_dep} \
    !{params.metapop_ref_sample ? "--ref_sample " + params.metapop_ref_sample : ""}
    '''
}
