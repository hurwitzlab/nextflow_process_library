#!/usr/bin/env nextflow


// Infer viral sequences from contigs using vibrant
// vibrant_db is VIBRANT's "databases" dir (HMMs, from download-db.sh); the "files" dir is bundled in the image
 process vibrant {
    label "process_high"
    label "publish_final"
    container "${params.container__vibrant}"
                        
    input:
        tuple val(sampleid), path(contigs)
        path(vibrant_db)

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
    -d !{vibrant_db} \
    -folder .
    '''
}