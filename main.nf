#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PREPARE_REFERENCE } from './modules/prepare_reference/main.nf'
include { CLUSTER_CELLS }     from './modules/cluster_cells/main.nf'
include { RUN_INFERCNV }      from './modules/run_infercnv/main.nf'
include { ANNOTATE_H5AD }     from './modules/annotate_h5ad/main.nf'
include { CONCAT_H5ADS }      from './modules/concat_h5ads/main.nf'

workflow {
    Channel.fromPath(params.h5ad_dir)
        | map { file -> tuple(file.baseName.replaceFirst(/_annotated$/, ''), file) }
        | set { ch_samples }

    PREPARE_REFERENCE(params.species, params.release)
    CLUSTER_CELLS(ch_samples, params.resolution)

    RUN_INFERCNV(
        CLUSTER_CELLS.out.h5ad_and_annotations,
        PREPARE_REFERENCE.out.gene_order,
        params.cutoff
    )

    // Re-key clustered h5ad to join with the output directory of InferCNV
    ch_cluster_h5ad = CLUSTER_CELLS.out.h5ad_and_annotations.map { it -> tuple(it[0], it[1]) }
    ch_annotate_in  = ch_cluster_h5ad.join(RUN_INFERCNV.out.infercnv_dir)

    ANNOTATE_H5AD(ch_annotate_in)

    // Collect all resulting annotated h5ad files
    ANNOTATE_H5AD.out.h5ad
        | map { it[1] }
        | collect
        | set { ch_all_h5ads }

    CONCAT_H5ADS(ch_all_h5ads)
}