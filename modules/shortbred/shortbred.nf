#!/usr/bin/env nextflow

// Identify antibiotic resistance and virulence factor markers with ShortBRED
process identify_virulence_factors {
    label "process_high"
    label "publish_final"
    container "${params.container__shortbred}"

    input:
        tuple val(sampleid), path(genome)
        path(card_markers)
        path(vf_markers)

    output:
        tuple val(sampleid), path("CARD.tab"),      emit: antibiotic_resistance
        tuple val(sampleid), path("CARD_hits.tab"), emit: antibiotic_resistance_hits
        tuple val(sampleid), path("VF.tab"),        emit: virulence_factors
        tuple val(sampleid), path("VF_hits.tab"),   emit: virulence_factors_hits
        tuple val(sampleid), path("CARD_tmp"),      emit: card_tmp
        tuple val(sampleid), path("VF_tmp"),        emit: vf_tmp

    shell:
    '''
    shortbred_quantify.py --genome !{genome} \
                          --markers !{card_markers} \
                          --results CARD.tab \
                          --SBhits CARD_hits.tab \
                          --tmp CARD_tmp \
                          --maxhits 10000000 \
                          --maxrejects 10000000 \
                          --threads !{task.cpus}

    shortbred_quantify.py --genome !{genome} \
                          --markers !{vf_markers} \
                          --results VF.tab \
                          --SBhits VF_hits.tab \
                          --tmp VF_tmp \
                          --maxhits 10000000 \
                          --maxrejects 10000000 \
                          --threads !{task.cpus}
    '''
}
