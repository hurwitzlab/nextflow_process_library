#!/usr/bin/env nextflow


// Infer viral sequences from contigs using vibrant
// -m is explicit: images built before 2026-11-05 don't set VIBRANT_DATA_PATH, so its default is "None/files/"
// vibrant_db is VIBRANT's HMM "databases" dir, e.g. the BRC install
// /gpfs_backup/bioinfo_data/databases/vibrant_db/v1.2.1/databases/
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
    -m /opt/conda/envs/vibrant/share/vibrant-1.2.1/db/files/ \
    -folder .
    '''
}