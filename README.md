# infercnv

A Nextflow DSL2 pipeline for automated CNV detection, CIN scoring, and matrix concatenation in single-cell RNA-seq data.

## Pipeline steps

1. **Prepare Reference** (`gget`) — Downloads the Ensembl GTF for the specified species/release and emits a deduplicated `genomic_positions.txt` for InferCNV.
2. **Cluster Cells** (`Scanpy`) — Normalizes counts, runs Leiden clustering on a working copy, and writes a barcode → cluster annotation file plus a clustered `.h5ad`.
3. **Run InferCNV** (`InferCNV`) — Reads the per-sample h5ad via `zellkonverter`, then runs sub-clustered HMM CNV detection against the global per-cluster baseline (`ref_group_names = NULL`).
4. **Annotate & Score CIN** (`Scanpy` / `Pandas`) — Parses `infercnv.observations.txt`, attaches `sample` to `.obs`, and computes a CNV Diversity Index (mean squared deviation from neutral 1.0) as a CIN proxy.
5. **Concatenate Output** (`AnnData`) — Merges all annotated per-sample h5ads into a single `combined_annotated.h5ad`, with `index_unique="-"` to keep cross-sample barcodes distinct.

## Requirements

- Nextflow >= 24.04.0
- One of: Docker, Singularity, or Conda/Mamba

Per-process software is provisioned from each module's `environment.yml` via Conda. The `docker` and `singularity` profiles also enable Conda so the same envs are used inside containers.

## Usage

```bash
nextflow run nf-austin/infercnv \
    -profile docker \
    --h5ad_dir "data/*.h5ad" \
    --species "human" \
    --release "114"
```

## Parameters

| Parameter      | Default       | Description                                          |
| -------------- |---------------| ---------------------------------------------------- |
| `--h5ad_dir`   | `data/*.h5ad` | Glob pattern matching one h5ad per sample.           |
| `--outdir`     | `results`     | Where published outputs are written.                 |
| `--species`    | `human`       | Species passed to `gget ref`.                        |
| `--release`    | `114`         | Ensembl release used for the GTF download.           |
| `--resolution` | `1.0`         | Leiden clustering resolution.                        |
| `--cutoff`     | `0.1`         | Minimum mean expression cutoff for InferCNV.         |
| `--max_memory` | `128.GB`      | Cap applied via `process.resourceLimits`.            |
| `--max_cpus`   | `32`          | Cap applied via `process.resourceLimits`.            |
| `--max_time`   | `72.h`        | Cap applied via `process.resourceLimits`.            |

## Input expectations

Each input `.h5ad` should contain:

- Raw integer counts in `adata.X`.
- Gene symbols in `adata.var_names` matching the Ensembl GTF `gene_name` attribute (HGNC for human, MGI for mouse).
- Optionally a boolean `adata.obs["passing_qc"]` column — if present, only cells where it is `True` are clustered and passed to InferCNV.

The file basename (without `.h5ad`) becomes the sample ID.

### Pairing with `nf-austin/scrnaseq`

[`nf-austin/scrnaseq`](https://github.com/nf-austin/scrnaseq) emits per-sample `{sample_id}_annotated.h5ad` from its SCANPY_QC step, with raw counts in `.X`, gene-symbol `var_names`, and a `passing_qc` flag on `.obs`. Those files drop directly into this pipeline:

```bash
nextflow run nf-austin/infercnv \
    -profile docker \
    --h5ad_dir "scrnaseq_results/qc/*/*_annotated.h5ad" \
    --species "human" \
    --release "114"
```

## Output structure

```
results/
├── {sample_id}_infercnv/
│   └── infercnv_out/
│       ├── infercnv.observations.txt
│       └── ...
└── combined_annotated.h5ad
```

The combined h5ad carries a `sample` column and a `cnv_diversity_index` column on `.obs`.