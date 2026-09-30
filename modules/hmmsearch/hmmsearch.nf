#!/usr/bin/env nextflow

// Search a protein catalog against a Pfam HMM database with hmmsearch
 process hmmsearch {
    label "process_high"
    container "${params.container__hmmer}"
    publishDir "${params.hmmsearch_outdir}", mode: 'copy'

    input:
        path(protein_catalog)
        path(pfam_db)

    output:
        path("catalog_pfam_hmmout.txt"), emit: domain_hits

    shell:
    '''
    hmmsearch \
    --cpu !{task.cpus} \
    -E !{params.hmmsearch_evalue} \
    --tblout catalog_pfam_hmmout.txt \
    -o catalog_pfam_hmmlog.txt \
    !{pfam_db} \
    !{protein_catalog}
    '''
}
