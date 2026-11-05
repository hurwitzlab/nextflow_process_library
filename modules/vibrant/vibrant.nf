#!/usr/bin/env nextflow


// Infer viral sequences from contigs using vibrant
// -m is explicit: images built before 2026-11-05 don't set VIBRANT_DATA_PATH, so its default is "None/files/"
 process vibrant {
    label "process_high"
    label "publish_final"
    container "${params.container__vibrant}"
                        
    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("VIBRANT_${contigs.baseName}/"), emit: viral_inferences

    shell:
    '''
    VIBRANT_run.py \
    -i !{contigs} \
    -f !{params.vibrant_f} \
    -l !{params.vibrant_minlength} \
    -o !{params.vibrant_minorfspercontig} \
    -t !{task.cpus} \
    -m /opt/conda/envs/vibrant/share/vibrant-1.2.1/db/files/ \
    -folder .
    '''
}