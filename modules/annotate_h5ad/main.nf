process ANNOTATE_H5AD {
    tag { sample_id }

    conda "${moduleDir}/environment.yml"
    // Container assigned in nextflow.config's withName block.

    input:
    tuple val(sample_id), path(h5ad), path(infercnv_dir)

    output:
    tuple val(sample_id), path("${sample_id}_annotated.h5ad"), emit: h5ad

    script:
    // numba (pulled in by scanpy) JIT-caches next to its package by default,
    // and matplotlib wants ~/.config. Neither is writable inside a read-only
    // Singularity image or with a read-only $HOME, which makes the import die
    // with "cannot cache function ... no locator available". Point both at the
    // task work dir, which is always writable.
    """
    export NUMBA_CACHE_DIR="\$PWD/.numba_cache"
    export MPLCONFIGDIR="\$PWD/.mplconfig"

    annotate_h5ad.py \\
        --h5ad ${h5ad} \\
        --sample_id ${sample_id} \\
        --infercnv_dir ${infercnv_dir} \\
        --out_h5ad ${sample_id}_annotated.h5ad
    """

    stub:
    """
    touch ${sample_id}_annotated.h5ad
    """
}
