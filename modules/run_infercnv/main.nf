process RUN_INFERCNV {
    tag { sample_id }
    publishDir { "${params.outdir}/${sample_id}_infercnv" }, mode: 'copy'

    conda "${moduleDir}/environment.yml"
    // Container assigned in nextflow.config's withName block.

    input:
    tuple val(sample_id), path(h5ad), path(annotations)
    path gene_order
    val cutoff

    output:
    tuple val(sample_id), path("infercnv_out"), emit: infercnv_dir

    script:
    """
    # Keep basilisk's env inside the task dir rather than \$HOME, which is
    # quota-limited and not always mounted on compute nodes.
    export BASILISK_EXTERNAL_DIR="\${PWD}/.basilisk"
    run_infercnv.R \\
        --h5ad ${h5ad} \\
        --annotations ${annotations} \\
        --gene_order ${gene_order} \\
        --cutoff ${cutoff} \\
        --threads ${task.cpus} \\
        --out_dir infercnv_out
    """

    stub:
    """
    mkdir -p infercnv_out
    printf 'gene\\tcell\\n' > infercnv_out/infercnv.observations.txt
    touch infercnv_out/infercnv.png
    """
}
