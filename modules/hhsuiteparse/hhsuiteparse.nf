#!/usr/bin/env nextflow

// Parse a directory (tarball) of hhblits .hhr result files into a single TSV table
process parse_hhr_dir {
    label "process_low"
    container "${params.container__hhsuiteparse}"

    input:
        path(hhr_tar) // tarball of a directory of hhr files

    output:
        path("hhr.tsv"), emit: hhr_table

    shell:
    '''
    mkdir hhr
    tar -zxvf !{hhr_tar} -C hhr

    parse_hhr.py --hhr_dir hhr --out_tsv hhr.tsv
    '''
}

// Join cluster assignments to parsed hhr results, producing one results file per sample
process join_clusters_to_hhr {
    label "process_low"
    container "${params.container__hhsuiteparse}"
    publishDir "${params.hhsuiteparse_outdir}", mode: 'copy'

    input:
        path(clusters_tsv)
        path(hhr_tsv)

    output:
        path("results", type: 'dir'), emit: per_sample_results

    shell:
    '''
    #!/usr/bin/env python3

    import pandas as pd
    import os

    clusters = pd.read_csv('!{clusters_tsv}', sep='\\t')
    hhr = pd.read_csv('!{hhr_tsv}', sep='\\t')
    out_dir = 'results'

    os.makedirs(out_dir, exist_ok=True)

    # generate a results file for each sample_id, listing all results for each protein
    for (sample_id, sample_clusters) in clusters.groupby('sample_name'):
       # get all hhr results for each ref in the sample
       results = sample_clusters.merge(hhr, how='inner', left_on='ref', right_on='query')
       out_file = os.path.join(out_dir, f"{sample_id}.tsv")
       results.to_csv(out_file, sep='\\t', index=False)
    '''
}
