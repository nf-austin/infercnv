process CLUSTER_CELLS {
    tag { sample_id }

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(sample_id), path(h5ad)
    val resolution

    output:
    tuple val(sample_id), path("${sample_id}_clustered.h5ad"), path("${sample_id}_annotations.txt"), emit: h5ad_and_annotations

    script:
    """
    python3 ${moduleDir}/cluster_cells.py \\
        --h5ad ${h5ad} \\
        --resolution ${resolution} \\
        --out_annotations ${sample_id}_annotations.txt \\
        --out_h5ad ${sample_id}_clustered.h5ad
    """
}