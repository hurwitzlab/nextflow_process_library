#!/usr/bin/env nextflow

// Predict multi-locus sequence type from paired-end reads with stringMLST (deprecated in favor of mlst)
process stringmlst {
    label "process_medium"
    label "publish_final"
    container "${params.container__stringmlst}"

    input:
        tuple val(sampleid), path(r1), path(r2)
        path(database)
        val(database_name)

    output:
        tuple val(sampleid), path("MLST.txt"), emit: mlst_result

    shell:
    '''
    mkdir database
    tar -xvf !{database} -C database
    echo "The tool is deprecated in favor of mlst"
    python3 /stringMLST-0.6.1/stringMLST.py --predict \
              --fastq1 !{r2} \
              --fastq2 !{r1} \
              --paired \
              --prefix database/!{database_name} \
              --output MLST.txt
    '''
}
