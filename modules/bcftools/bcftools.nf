#!/usr/bin/env nextflow

// Add variants that are expected but not called into a VCF file (Mutect2 workflow: fix malformed header, merge with expected variants, keep only the actual sample)
process add_uncalled_variants {
    label "process_single"
    container "${params.container__bcftools}"

    input:
        path(called_variants)        // VCF file of called variants
        path(expected_variants)      // Expected variants
        path(expected_variants_tbi)  // Tabix index for expected_variants

    output:
        path("result.vcf.gz"),     emit: merged_variants
        path("result.vcf.gz.tbi"), emit: merged_variants_tabix

    shell:
    '''
    # Fix Header because Mutect2 output malformed VCF file (https://github.com/broadinstitute/gatk/issues/6857)
    gunzip -c !{called_variants} > variants.vcf
    bcftools head variants.vcf | perl -nle "if (/ID=AS_FilterStatus,/){ s/Number=A/Number=./ } print" > header.txt
    bcftools reheader -h header.txt variants.vcf | bgzip > fixed_header.vcf.gz
    tabix fixed_header.vcf.gz

    # Merge actual and expected_variants
    bcftools merge fixed_header.vcf.gz !{expected_variants} -i - --missing-to-ref > all_variants.vcf

    # Subset to just first sample (assume sample name is "1"), while keeping all variants in both samples
    bcftools view -s 1 all_variants.vcf | bgzip > result.vcf.gz
    tabix result.vcf.gz
    '''
}

// Normalize variants, and split variants on the same line into two different lines
process normalize_variants {
    label "process_single"
    container "${params.container__bcftools}"

    input:
        path(variants) // VCF file of called variants
        path(genome)   // Reference genome

    output:
        path("result.vcf.gz"),     emit: normalized_variants
        path("result.vcf.gz.tbi"), emit: normalized_variants_tabix

    shell:
    '''
    bcftools norm !{variants} \
                  --fasta-ref !{genome} \
                  --multiallelics -both \
                  --output result.vcf.gz \
                  --output-type b
    tabix result.vcf.gz
    '''
}

// Apply called variants to a reference genome to produce an edited consensus FASTA
process add_variants_to_fasta {
    label "process_single"
    container "${params.container__bcftools}"
    // NOTE: no sampleid in scope -- this whole file uses bare path(...)
    // inputs, not the per-sample tuple convention (pre-existing, file-wide,
    // out of scope here). Left as a plain string; the standard Closure
    // publishDir pattern needs sampleid to close over.
    publishDir "${params.bcftools_outdir}", mode: 'copy'

    input:
        path(variants)     // VCF file of called variants
        path(variants_tbi) // Tabix index for variants
        path(genome)        // Reference genome

    output:
        path("edited_genome.fasta"), emit: edited_genome

    shell:
    '''
    bcftools consensus -f !{genome} !{variants} > edited_genome.fasta
    '''
}

// Filter variants below a given allele-frequency (VAF) cutoff
process filter_variants {
    label "process_single"
    container "${params.container__bcftools}"

    input:
        path(variants) // VCF file of called variants
        val(vaf)       // float between 0 and 1 to exclude variants below

    output:
        path("result.vcf.gz"),     emit: filtered_variants
        path("result.vcf.gz.tbi"), emit: filtered_variants_tabix

    shell:
    '''
    bcftools view !{variants} \
             --output result.vcf.gz \
             --exclude "AF<!{vaf}" \
             --output-type b
    tabix result.vcf.gz
    '''
}

// Set genotype to the most common allele
process set_genotype {
    label "process_single"
    container "${params.container__bcftools}"

    input:
        path(variants) // VCF file of called variants

    output:
        path("result.vcf.gz"),     emit: regenotyped_variants
        path("result.vcf.gz.tbi"), emit: regenotyped_variants_tabix

    shell:
    '''
    bcftools +setGT !{variants} -- -t a -n X > result.vcf
    bgzip result.vcf
    tabix result.vcf.gz
    '''
}

// Concatenate two VCF files (e.g. edit variants + CRISPR variants) into one final call set
process concat_vcfs {
    label "process_single"
    container "${params.container__bcftools}"
    // NOTE: no sampleid in scope -- see add_variants_to_fasta above.
    publishDir "${params.bcftools_outdir}", mode: 'copy'

    input:
        path(edit_variants)    // VCF file of first variant set
        path(crispr_variants)  // VCF file of second variant set

    output:
        path("final_variants.vcf.gz"),     emit: final_variants
        path("final_variants.vcf.gz.tbi"), emit: final_variants_tabix

    shell:
    '''
    tabix !{edit_variants}
    tabix !{crispr_variants}
    bcftools concat -a -o final_variants.vcf.gz !{edit_variants} !{crispr_variants}
    tabix final_variants.vcf.gz
    '''
}
