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
- Docker (local) or Singularity/Apptainer (HPC); Conda works as a fallback
- Optional: a SLURM cluster — see [HPC / SLURM](#hpc--slurm)

Per-process software is provisioned from each module's `environment.yml` via Conda. The `docker` and `singularity` profiles resolve software from the container images and disable Conda; `-profile conda` remains a fallback.

## Usage

### Samplesheet (recommended, and what Seqera Platform launches with)

```bash
nextflow run nf-austin/infercnv \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

`samplesheet.csv` has two columns:

```csv
sample,h5ad
tumor01,/data/tumor01/tumor01.h5ad
tumor02,/data/tumor02/tumor02.h5ad
```

`sample` becomes the output subdirectory name and must be unique. Relative paths are resolved
against the samplesheet's own directory first, then the launch directory — but prefer absolute
paths, especially on Seqera Platform, where the launch directory is the work directory.

### Ad-hoc glob

```bash
nextflow run nf-austin/infercnv \
    -profile docker \
    --h5ad_dir "data/*.h5ad" \
    --species "human" \
    --release "114"
```

The sample id is taken from each filename with any trailing `_annotated` stripped. Mutually
exclusive with `--input`.

## Parameters

| Parameter      | Default       | Description                                          |
| -------------- |---------------| ---------------------------------------------------- |
| `--input`      | *(one of these two)* | Samplesheet CSV with `sample` and `h5ad` columns. |
| `--h5ad_dir`   | *(one of these two)* | Glob pattern matching one h5ad per sample.   |
| `--outdir`     | `results`     | Where published outputs are written.                 |
| `--gene_order` | *(none)*      | Pre-built `genomic_positions.txt`; skips `PREPARE_REFERENCE` entirely. **Use this on HPC.** |
| `--gtf`        | *(none)*      | Pre-downloaded Ensembl GTF; skips only the download. |
| `--species`    | `human`       | Species passed to `gget ref`. Unused if `--gene_order`/`--gtf` is given. |
| `--release`    | `114`         | Ensembl release used for the GTF download.           |
| `--resolution` | `1.0`         | Leiden clustering resolution.                        |
| `--cutoff`     | `0.1`         | Minimum mean expression cutoff for InferCNV.         |
| `--infercnv_container`    | `ghcr.io/nf-austin/infercnv:1.2.0`    | R/Bioconductor image for `RUN_INFERCNV`. |
| `--infercnv_py_container` | `ghcr.io/nf-austin/infercnv:1.2.0-py` | Python/scanpy image for the other steps. |
| `--max_memory` | `128.GB`      | Cap applied via `process.resourceLimits`.            |
| `--max_cpus`   | `32`          | Cap applied via `process.resourceLimits`.            |
| `--max_time`   | `72.h`        | Cap applied via `process.resourceLimits`.            |
| `--slurm_queue` | *(cluster default)* | SLURM partition (`sbatch --partition`). Used by `-profile slurm`. |
| `--slurm_account` | *(none)*   | SLURM account to charge (`sbatch --account`).        |
| `--cluster_options` | *(none)* | Raw sbatch options added to every job, e.g. `--qos=long`. |
| `--singularity_cache_dir` | `$NXF_SINGULARITY_CACHEDIR` | Shared directory for pulled images. |
| `--conda_cache_dir` | `$NXF_CONDA_CACHEDIR` | Shared directory for conda environments.   |
| `--singularity_bind` | *(none)* | Extra bind mounts, comma-separated, e.g. `/mnt/gpfs,/scratch`. |

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

## Seqera Platform (Nextflow Tower)

The repo ships everything Platform needs:

- **`nextflow_schema.json`** — renders the launch form. `--input` appears as a file picker wired to
  Data Explorer, options are grouped, and tuning knobs are marked hidden so the default form stays
  short.
- **`assets/schema_input.json`** — the samplesheet contract (`sample`, `h5ad`), so a malformed sheet
  is caught before compute is provisioned.
- **`tower.yml`** — puts the per-sample heatmaps, CNV matrices and the Nextflow execution report in
  the run's **Reports** tab.

To add it: **Pipelines → Add pipeline**, point at this repository, and pick a compute environment.
Use **absolute paths** for `--input`, the h5ads it references, and `--outdir`.

Samplesheet problems — a missing column, a duplicate sample id, an unreadable `h5ad` — are raised at
launch, before Platform provisions any compute.

## HPC / SLURM

The `slurm` profile sets only the executor and queue, so it composes with an engine profile in
either order:

```bash
nextflow run nf-austin/infercnv \
    -profile slurm,singularity \
    --slurm_queue normal \
    --input /mnt/gpfs/project/sheet.csv \
    --gene_order /mnt/gpfs/refs/genomic_positions.txt \
    --outdir /mnt/gpfs/project/results \
    --singularity_cache_dir /mnt/gpfs/shared/singularity
```

- **Pass `--gene_order`.** `PREPARE_REFERENCE` downloads an Ensembl GTF with `gget ref`, and compute
  nodes on most clusters have no outbound network. Build the positions file once on a login node and
  point at it; `--gene_order` skips the process entirely. `--gtf` is the halfway option — it skips
  only the download. Both failure paths name the flag to use.
- **The InferCNV GTF parser is vendored, not downloaded.** `bin/gtf_to_position_file.py` is a copy of
  the upstream script, with the source commit recorded in its header. Earlier versions `curl`ed it
  from `refs/heads/master` on every run — unpinned code from a moving branch, fetched at runtime.
- **Use absolute paths** for `--input`, the h5ads it lists, and `--outdir`.
- **Put `--singularity_cache_dir` on shared storage.** `$HOME` is usually quota-limited and is not
  always mounted on compute nodes.
- **`--singularity_bind` is the escape hatch for symlinked filesystems.** `autoMounts` binds only the
  paths Nextflow resolved itself; if `/data` is a symlink to `/mnt/gpfs/...`, the container sees a
  dangling link and reports a missing file. Bind the real parent: `--singularity_bind /mnt/gpfs`.
- **Seqera Platform already sets the executor** when you launch against a SLURM compute environment,
  so `-profile slurm` is mainly for launching by hand from a login node.

## Container images

Built from the two Dockerfiles in this repo and published to GHCR by `.github/workflows/docker.yml`:

| Tag | Built from | Platforms | Used by |
| --- | --- | --- | --- |
| `ghcr.io/nf-austin/infercnv:<ver>` | `modules/run_infercnv/Dockerfile` | amd64 | `RUN_INFERCNV` |
| `ghcr.io/nf-austin/infercnv:<ver>-py` | `modules/cluster_cells/Dockerfile` | amd64, arm64 | the four Python steps |

Two images because no public biocontainer carries InferCNV *and* zellkonverter together, and the
R/Bioconductor and scanpy stacks do not share a base. The GHCR packages must be **public** for
`nextflow run` to pull them without credentials.

Every module also ships an `environment.yml`, so `-profile conda` remains a working fallback.

## Notes

- `nextflow run . -stub-run --input assets/samplesheet_example.csv` exercises the real channel
  wiring, fan-out and publishing with no containers and no data — useful on a laptop.
- `nextflow lint main.nf nextflow.config modules/*/main.nf` catches config errors that `-preview`
  accepts.
