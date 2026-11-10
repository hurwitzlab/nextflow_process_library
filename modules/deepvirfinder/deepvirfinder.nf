#!/usr/bin/env nextflow


// Infer viral sequences using deepvirfinder 
 process deepvirfinder {
    label "process_medium"
    label "publish_final"
    container "${params.container__deepvirfinder}"
                        
    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}"), emit: viral_inferences

    shell:
    '''
    python /opt/DeepVirFinder/dvf.py \
    -m /opt/DeepVirFinder/models \
    -i !{contigs} \
    -o !{sampleid}  \
    -l !{params.viralinference_minlength} \
    -c !{task.cpus}
    '''

 }