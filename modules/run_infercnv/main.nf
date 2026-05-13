process RUN_INFERCNV {
    tag { sample_id }
    publishDir { "${params.outdir}/${sample_id}_infercnv" }, mode: 'copy'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(sample_id), path(h5ad), path(annotations)
    path gene_order
    val cutoff

    output:
    tuple val(sample_id), path("infercnv_out"), emit: infercnv_dir

    script:
    """
    export BASILISK_EXTERNAL_DIR="\${PWD}/.basilisk"
    Rscript ${moduleDir}/run_infercnv.R \\
        --h5ad ${h5ad} \\
        --annotations ${annotations} \\
        --gene_order ${gene_order} \\
        --cutoff ${cutoff} \\
        --out_dir infercnv_out
    """
}