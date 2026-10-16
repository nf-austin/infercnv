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
    # Point HOME, XDG caches, basilisk, and conda directories at the writable
    # task work dir rather than the host \$HOME, which is often read-only inside
    # Singularity on compute nodes (causing mamba/conda extraction to fail with
    # "cannot create directory '\$HOME/.conda': Read-only file system").
    export HOME="\$PWD"
    export XDG_CACHE_HOME="\$PWD/.cache"
    export BASILISK_EXTERNAL_DIR="\$PWD/.basilisk"
    export CONDA_ENVS_PATH="\$PWD/.conda/envs"
    export CONDA_PKGS_DIRS="\$PWD/.conda/pkgs"
    export CONDARC="\$PWD/.condarc"

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
