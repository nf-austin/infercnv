#!/usr/bin/env nextflow

include { PREPARE_REFERENCE } from './modules/prepare_reference/main.nf'
include { CLUSTER_CELLS }     from './modules/cluster_cells/main.nf'
include { RUN_INFERCNV }      from './modules/run_infercnv/main.nf'
include { ANNOTATE_H5AD }     from './modules/annotate_h5ad/main.nf'
include { CONCAT_H5ADS }      from './modules/concat_h5ads/main.nf'

def helpMessage() {
    log.info """
    nf-austin/infercnv -- CNV inference from single-cell RNA-seq with InferCNV

    Usage, samplesheet (recommended; this is what Seqera Platform launches with):
      nextflow run main.nf -profile docker --input samplesheet.csv --outdir results

      samplesheet.csv columns: sample, h5ad

    Usage, ad-hoc glob:
      nextflow run main.nf -profile docker --h5ad_dir "data/*.h5ad"

    Required (one of):
      --input         Samplesheet CSV.
      --h5ad_dir      Glob matching .h5ad files.

    Common options:
      --outdir        Output directory (default: ${params.outdir}).
      --species       Ensembl species for the gene-order reference (default: ${params.species}).
      --release       Ensembl release (default: ${params.release}).
      --resolution    Leiden clustering resolution (default: ${params.resolution}).
      --cutoff        InferCNV expression cutoff (default: ${params.cutoff}).

    On HPC, avoid the reference download -- compute nodes usually have no outbound
    network:
      --gene_order    Pre-built genomic_positions.txt; skips PREPARE_REFERENCE entirely.
      --gtf           Pre-downloaded Ensembl GTF; skips only the download.

    Add `-profile slurm,singularity --slurm_queue <partition>` and use absolute
    paths. See the README for the HPC notes.
    """.stripIndent()
}

/**
 * Resolve one samplesheet entry to a file.
 *
 * A relative entry is resolved against the samplesheet's OWN directory first,
 * which is what someone editing that sheet expects. Nextflow's default is the
 * launch directory, and on Seqera Platform the launch directory is the work
 * directory -- so a relative path there silently resolves somewhere unrelated.
 * Falls back to launch-dir resolution, and only then reports the entry missing.
 */
def resolveInput(path, sheet_dir, row_num) {
    // Absolute POSIX path, or a remote URI (s3://, gs://, az://): take as-is.
    if (path.startsWith('/') || path ==~ /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/.*/) {
        return file(path, checkIfExists: true)
    }
    def beside_sheet = sheet_dir.resolve(path)
    if (beside_sheet.exists()) {
        return beside_sheet
    }
    def from_launch = file(path)
    if (from_launch.exists()) {
        return from_launch
    }
    error "Samplesheet row ${row_num}: h5ad not found as '${beside_sheet}' (relative to the samplesheet) nor as '${from_launch}' (relative to the launch directory). Use an absolute path."
}

/**
 * Turn samplesheet rows into (sample_id, h5ad) tuples.
 *
 * Validated eagerly over the fully-read row list rather than inside a channel
 * closure: errors raised in a closure are lazy -- they never fire under
 * -preview, and in a real run they surface only once the channel is consumed.
 * A bad samplesheet must fail at launch, before Platform provisions compute.
 */
def buildSamples(rows, sheet_dir) {
    if (!rows) {
        error "Samplesheet is empty: ${params.input}"
    }
    def required = ['sample', 'h5ad']
    def missing = required.findAll { c -> !rows[0].containsKey(c) }
    if (missing) {
        error "Samplesheet is missing column(s): ${missing.join(', ')}. Found: ${rows[0].keySet().join(', ')}"
    }

    def seen = [] as Set
    return rows.withIndex().collect { row, idx ->
        def sample_id = row.sample?.trim()
        if (!sample_id) {
            error "Samplesheet row ${idx + 1} has an empty 'sample' value"
        }
        if (!seen.add(sample_id)) {
            error "Samplesheet has a duplicate sample id: '${sample_id}'. Sample ids become output paths and must be unique."
        }
        def h5ad = row.h5ad?.trim()
        if (!h5ad) {
            error "Samplesheet row ${idx + 1} ('${sample_id}') has an empty 'h5ad' value"
        }
        tuple(sample_id, resolveInput(h5ad, sheet_dir, idx + 1))
    }
}

workflow {
    if (params.help) {
        helpMessage()
        return
    }

    if (params.input && params.h5ad_dir) {
        error "Use either --input (samplesheet) or --h5ad_dir (glob), not both."
    }
    if (!params.input && !params.h5ad_dir) {
        error "No input given. Provide --input samplesheet.csv or --h5ad_dir \"data/*.h5ad\". Run with --help for details."
    }

    if (params.input) {
        def sheet = file(params.input, checkIfExists: true)
        def rows = sheet.splitCsv(header: true, strip: true)
        ch_samples = channel.fromList(buildSamples(rows, sheet.parent))
    }
    else {
        ch_samples = channel.fromPath(params.h5ad_dir, checkIfExists: true)
            .map { f -> tuple(f.baseName.replaceFirst(/_annotated$/, ''), f) }
    }

    log.info """
    P I P E L I N E   nf-austin/infercnv
    ====================================
    input      : ${params.input ?: params.h5ad_dir}
    gene order : ${params.gene_order ?: (params.gtf ? "from --gtf" : "auto-download (${params.species} ${params.release})")}
    resolution : ${params.resolution}
    cutoff     : ${params.cutoff}
    outdir     : ${params.outdir}
    """.stripIndent()

    // A pre-built gene-order file skips PREPARE_REFERENCE entirely -- the
    // recommended path on a cluster, where compute nodes have no egress.
    if (params.gene_order) {
        ch_gene_order = channel.value(file(params.gene_order, checkIfExists: true))
    }
    else {
        // 'NO_GTF' is a sentinel telling the process to download instead. The
        // placeholder file is committed to assets/ so it resolves on any
        // launch directory.
        def gtf_file = params.gtf
            ? file(params.gtf, checkIfExists: true)
            : file("${projectDir}/assets/NO_GTF", checkIfExists: true)
        ch_gene_order = PREPARE_REFERENCE(params.species, params.release, gtf_file).gene_order
    }

    CLUSTER_CELLS(ch_samples, params.resolution)

    RUN_INFERCNV(
        CLUSTER_CELLS.out.h5ad_and_annotations,
        ch_gene_order,
        params.cutoff
    )

    // Re-key the clustered h5ad to join with InferCNV's output directory.
    // The join source must stay CLUSTER_CELLS.out -- ANNOTATE_H5AD needs the
    // *clustered* h5ad, not the raw one from ch_samples.
    ch_cluster_h5ad = CLUSTER_CELLS.out.h5ad_and_annotations.map { id, h5ad, _ann -> tuple(id, h5ad) }
    ch_annotate_in  = ch_cluster_h5ad.join(RUN_INFERCNV.out.infercnv_dir)

    ANNOTATE_H5AD(ch_annotate_in)

    ANNOTATE_H5AD.out.h5ad
        | map { _id, h5ad -> h5ad }
        | collect
        | set { ch_all_h5ads }

    CONCAT_H5ADS(ch_all_h5ads)
}
