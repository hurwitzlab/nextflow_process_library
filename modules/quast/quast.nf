#!/usr/bin/env nextflow

// Evaluate an Illumina paired-end assembly against QUAST metrics
process evaluate_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs), path(trimmed_r1), path(trimmed_r2)

    output:
        tuple val(sampleid), path("${sampleid}/quast_results", type: 'dir'), emit: quast_results_dir
        tuple val(sampleid), path("${sampleid}/quast_results/basic_stats", type: 'dir'), emit: basic_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/busco_stats", type: 'dir'), emit: busco_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/icarus_viewers", type: 'dir'), emit: icarus_viewers_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats", type: 'dir'), emit: reads_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats/reads_report.tsv"), emit: reads_stats_report
        tuple val(sampleid), path("${sampleid}/quast_results/report.tsv"), emit: summary_report

    shell:
    '''
    quast.py !{contigs} \
      --pe1 !{trimmed_r1} \
      --pe2 !{trimmed_r2} \
      --output-dir !{sampleid}/quast_results \
      --split-scaffolds \
      --conserved-genes-finding \
      --k-mer-stats \
      --circos \
      --threads !{task.cpus}
    '''
}

// Evaluate an Illumina paired-end assembly against QUAST metrics using a known reference genome
process evaluate_assembly_with_reference {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs), path(trimmed_r1), path(trimmed_r2)
        path(reference)

    output:
        tuple val(sampleid), path("${sampleid}/quast_results", type: 'dir'), emit: quast_results_dir
        tuple val(sampleid), path("${sampleid}/quast_results/basic_stats", type: 'dir'), emit: basic_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/busco_stats", type: 'dir'), emit: busco_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/icarus_viewers", type: 'dir'), emit: icarus_viewers_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats", type: 'dir'), emit: reads_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats/reads_report.tsv"), emit: reads_stats_report
        tuple val(sampleid), path("${sampleid}/quast_results/report.tsv"), emit: summary_report

    shell:
    '''
    quast.py !{contigs} \
      -r !{reference} \
      --pe1 !{trimmed_r1} \
      --pe2 !{trimmed_r2} \
      --output-dir !{sampleid}/quast_results \
      --split-scaffolds \
      --conserved-genes-finding \
      --k-mer-stats \
      --circos \
      --threads !{task.cpus}
    '''
}

// Evaluate a PacBio HiFi long-read assembly against QUAST metrics
process evaluate_long_read_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs), path(long_reads)

    output:
        tuple val(sampleid), path("${sampleid}/quast_results", type: 'dir'), emit: quast_results_dir
        tuple val(sampleid), path("${sampleid}/quast_results/basic_stats", type: 'dir'), emit: basic_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/busco_stats", type: 'dir'), emit: busco_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/icarus_viewers", type: 'dir'), emit: icarus_viewers_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats", type: 'dir'), emit: reads_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats/reads_report.tsv"), emit: reads_stats_report
        tuple val(sampleid), path("${sampleid}/quast_results/report.tsv"), emit: summary_report

    shell:
    '''
    quast.py !{contigs} \
      --pacbio !{long_reads} \
      --output-dir !{sampleid}/quast_results \
      --split-scaffolds \
      --conserved-genes-finding \
      --k-mer-stats \
      --circos \
      --threads !{task.cpus}
    '''
}

// Evaluate an ONT long-read assembly against QUAST metrics
process evaluate_ont_phage_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs), path(long_reads)

    output:
        tuple val(sampleid), path("${sampleid}/quast_results", type: 'dir'), emit: quast_results_dir
        tuple val(sampleid), path("${sampleid}/quast_results/basic_stats", type: 'dir'), emit: basic_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/busco_stats", type: 'dir'), emit: busco_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/icarus_viewers", type: 'dir'), emit: icarus_viewers_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats", type: 'dir'), emit: reads_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats/reads_report.tsv"), emit: reads_stats_report
        tuple val(sampleid), path("${sampleid}/quast_results/report.tsv"), emit: summary_report

    shell:
    '''
    quast.py !{contigs} \
      --nanopore !{long_reads} \
      --output-dir !{sampleid}/quast_results \
      --split-scaffolds \
      --conserved-genes-finding \
      --k-mer-stats \
      --circos \
      --threads !{task.cpus}
    '''
}

// Evaluate a hybrid PacBio/ONT + Illumina assembly against QUAST metrics
process evaluate_hybrid_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        val(long_read_platform) // PacBio (pacbio) or Oxford Nanopore (nanopore)
        tuple val(sampleid), path(contigs), path(trimmed_r1), path(trimmed_r2), path(long_reads)

    output:
        tuple val(sampleid), path("${sampleid}/quast_results", type: 'dir'), emit: quast_results_dir
        tuple val(sampleid), path("${sampleid}/quast_results/basic_stats", type: 'dir'), emit: basic_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/busco_stats", type: 'dir'), emit: busco_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/icarus_viewers", type: 'dir'), emit: icarus_viewers_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats", type: 'dir'), emit: reads_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/reads_stats/reads_report.tsv"), emit: reads_stats_report
        tuple val(sampleid), path("${sampleid}/quast_results/report.tsv"), emit: summary_report

    shell:
    '''
    quast.py !{contigs} \
      --pe1 !{trimmed_r1} \
      --pe2 !{trimmed_r2} \
      --!{long_read_platform} !{long_reads} \
      --output-dir !{sampleid}/quast_results \
      --split-scaffolds \
      --conserved-genes-finding \
      --k-mer-stats \
      --circos \
      --threads !{task.cpus}
    '''
}

// Evaluate an Illumina paired-end metagenome assembly against metaQUAST metrics
process evaluate_illumina_metagenome_assembly_paired_end {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs), path(r1), path(r2)

    output:
        tuple val(sampleid), path("${sampleid}_quast_results.tar.gz"), emit: metagenome_qc_report

    shell:
    '''
    metaquast.py !{contigs} \
                 --pe1 !{r1} \
                 --pe2 !{r2} \
                 --output-dir quast_results/ \
                 --split-scaffolds \
                 --conserved-genes-finding \
                 --max-ref-number 0 \
                 --threads !{task.cpus}
    tar -czf !{sampleid}_quast_results.tar.gz quast_results
    '''
}

// Evaluate an Illumina single-end metagenome assembly against metaQUAST metrics
process evaluate_illumina_metagenome_assembly_single_end {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs), path(r1)

    output:
        tuple val(sampleid), path("${sampleid}_quast_results.tar.gz"), emit: metagenome_qc_report

    shell:
    '''
    metaquast.py !{contigs} \
                 --single !{r1} \
                 --output-dir quast_results/ \
                 --split-scaffolds \
                 --conserved-genes-finding \
                 --max-ref-number 0 \
                 --threads !{task.cpus}
    tar -czf !{sampleid}_quast_results.tar.gz quast_results
    '''
}

// Evaluate an ONT metagenome assembly against metaQUAST metrics
process evaluate_ont_metagenome_assembly {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs), path(r1)

    output:
        tuple val(sampleid), path("${sampleid}_quast_results.tar.gz"), emit: metagenome_qc_report

    shell:
    '''
    metaquast.py !{contigs} \
                 --nanopore !{r1} \
                 --output-dir quast_results/ \
                 --split-scaffolds \
                 --conserved-genes-finding \
                 --max-ref-number 0 \
                 --threads !{task.cpus}
    tar -czf !{sampleid}_quast_results.tar.gz quast_results
    '''
}

// Evaluate a contigs-only assembly against QUAST metrics (no reads available)
process evaluate_contigs {
    label "process_high"
    label "publish_final"
    container "${params.container__quast}"

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}/quast_results", type: 'dir'), emit: quast_results_dir
        tuple val(sampleid), path("${sampleid}/quast_results/basic_stats", type: 'dir'), emit: basic_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/busco_stats", type: 'dir'), emit: busco_stats_dir
        tuple val(sampleid), path("${sampleid}/quast_results/report.tsv"), emit: summary_report

    shell:
    '''
    quast.py !{contigs} \
      --output-dir !{sampleid}/quast_results \
      --split-scaffolds \
      --conserved-genes-finding \
      --k-mer-stats \
      --circos \
      --threads !{task.cpus}
    '''
}
