#!/usr/bin/env nextflow

// Call expected variants between a parent genome and an engineered derivative using minimap2/paftools
process find_engineered_snvs {
    label "process_single"
    container "${params.container__minimap2}"
    // No sampleid here (compares two whole genomes, not per-sample) so the
    // Closure-based publishDir convention (which takes sampleid) doesn't
    // apply -- stays a plain path.
    publishDir "${params.minimap2_outdir}", mode: 'copy'

    input:
        path(parent_genome)
        path(engineered_genome)

    output:
        path("expected_variants.vcf.gz"), emit: variant_calls
        path("expected_variants.vcf.gz.tbi"), emit: variant_calls_index

    shell:
    '''
    minimap2 --cs -cx asm5 !{parent_genome} !{engineered_genome} > asm.paf
    sort -k6,6 -k8,8n asm.paf > asm.srt.paf
    paftools.js call -f !{parent_genome} -s expected_variants asm.srt.paf | bgzip > expected_variants.vcf.gz
    tabix expected_variants.vcf.gz
    '''
}

// Align a sample's reads to a reference genome with minimap2 (ONT preset)
process align {
    label "process_low"
    container "${params.container__minimap2}"

    input:
        path(reference)
        tuple val(sampleid), path(reads)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: aligned_sam

    shell:
    '''
    minimap2 -ax map-ont \
             -t !{task.cpus} \
             !{reference} !{reads} > !{sampleid}.sam
    '''
}

// Align a sample's reads to a prebuilt reference index archive with minimap2 (ONT preset)
process align_to_index {
    label "process_low"
    container "${params.container__minimap2}"

    input:
        path(reference_index_archive)
        tuple val(sampleid), path(reads)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: aligned_sam

    shell:
    '''
    mkdir index
    # Assume index is gzipped and sequenced is called ref.fa
    tar -xvf !{reference_index_archive} -C index
    if [ ! -f index/ref.fa ]; then
        echo "Input reference, must be gzipped, and contain a bwa index"
        exit 1
    fi

    minimap2 -ax map-ont \
             -t !{task.cpus} \
             index/ref.fa !{reads} > !{sampleid}.sam
    '''
}

// Estimate per-read accuracy of a sample's ONT reads against a reference with minimap2 all-vs-all alignment
process ont_read_accuracy {
    label "process_medium"
    label "publish_final"
    container "${params.container__minimap2}"

    input:
        tuple val(sampleid), path(reads)
        path(reference)

    output:
        tuple val(sampleid), path("${sampleid}.read_accuracy.tsv"), emit: read_accuracy_table
        tuple val(sampleid), path("${sampleid}.accuracy.txt"), emit: mean_accuracy

    shell:
    '''
    minimap2 -x ava-ont -t !{task.cpus} !{reference} !{reads} > result.paf

    # calculate each read accuracy based on blast identity
    awk -v OFS='\t' '
    BEGIN {print "name", "length", "identity"}
    {
        read_name = $1;
        read_length = $2;
        read_identity = $10/$11;
        print read_name, read_length, read_identity;
    }
    ' result.paf > !{sampleid}.read_accuracy.tsv

    # calculate average accuracy for ont reads
    awk '
    { if(NR > 1) sum_identity += $3 }
    END { if(NR > 1) print sum_identity/(NR-1)}
    ' !{sampleid}.read_accuracy.tsv > !{sampleid}.accuracy.txt
    '''
}
