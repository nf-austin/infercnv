#!/usr/bin/env Rscript
library(optparse)
library(infercnv)
library(zellkonverter)
library(SummarizedExperiment)
library(Matrix)

option_list <- list(
    make_option(c("--h5ad"), type="character", default=NULL, help="Input H5AD file"),
    make_option(c("--annotations"), type="character", default=NULL, help="Barcode to cluster annotations"),
    make_option(c("--gene_order"), type="character", default=NULL, help="Genomic position file"),
    make_option(c("--cutoff"), type="double", default=0.1, help="Count cutoff threshold"),
    make_option(c("--threads"), type="integer", default=4L, help="Number of threads"),
    make_option(c("--out_dir"), type="character", default=".", help="Output directory")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

if (is.null(opt$h5ad) || is.null(opt$annotations) || is.null(opt$gene_order)) {
    print_help(opt_parser)
    stop("Missing required arguments.", call.=FALSE)
}

adata <- readH5AD(opt$h5ad)

# zellkonverter names the primary assay based on adata.uns['X_name'] (often
# "X" or "counts") — grab the first assay rather than a hardcoded name.
expression <- as.matrix(assays(adata)[[1]])

infercnv_obj <- CreateInfercnvObject(
    raw_counts_matrix = expression,
    annotations_file  = opt$annotations,
    gene_order_file   = opt$gene_order,
    ref_group_names   = NULL
)

infercnv_obj <- infercnv::run(
    infercnv_obj,
    cutoff            = opt$cutoff,
    out_dir           = opt$out_dir,
    cluster_by_groups = TRUE,
    denoise           = TRUE,
    HMM               = TRUE,
    analysis_mode     = "subclusters",
    no_plot           = FALSE,
    num_threads       = opt$threads
)