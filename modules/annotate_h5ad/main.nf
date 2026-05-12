process ANNOTATE_H5AD {
    tag { sample_id }

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(sample_id), path(h5ad), path(infercnv_dir)

    output:
    tuple val(sample_id), path("${sample_id}_annotated.h5ad"), emit: h5ad

    script:
    """
    python3 ${moduleDir}/annotate_h5ad.py \\
        --h5ad ${h5ad} \\
        --sample_id ${sample_id} \\
        --infercnv_dir ${infercnv_dir} \\
        --out_h5ad ${sample_id}_annotated.h5ad
    """
}