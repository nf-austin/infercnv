process CLUSTER_CELLS {
    tag { sample_id }

    conda "${moduleDir}/environment.yml"
    // Container assigned in nextflow.config's withName block.

    input:
    tuple val(sample_id), path(h5ad)
    val resolution

    output:
    tuple val(sample_id), path("${sample_id}_clustered.h5ad"), path("${sample_id}_annotations.txt"), emit: h5ad_and_annotations

    script:
    // Script lives in bin/ and is called bare: Nextflow puts $projectDir/bin on
    // PATH and bind-mounts it into the container.
    // numba (pulled in by scanpy) JIT-caches next to its package by default,
    // and matplotlib wants ~/.config. Neither is writable inside a read-only
    // Singularity image or with a read-only $HOME, which makes the import die
    // with "cannot cache function ... no locator available". Point both at the
    // task work dir, which is always writable.
    """
    export NUMBA_CACHE_DIR="\$PWD/.numba_cache"
    export MPLCONFIGDIR="\$PWD/.mplconfig"

    cluster_cells.py \\
        --h5ad ${h5ad} \\
        --resolution ${resolution} \\
        --out_annotations ${sample_id}_annotations.txt \\
        --out_h5ad ${sample_id}_clustered.h5ad
    """

    stub:
    """
    touch ${sample_id}_clustered.h5ad
    printf 'cell\\tcluster\\n' > ${sample_id}_annotations.txt
    """
}
