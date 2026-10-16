# Python/scanpy stack for CLUSTER_CELLS, ANNOTATE_H5AD, CONCAT_H5ADS and
# PREPARE_REFERENCE.
#
# Separate from modules/run_infercnv/Dockerfile because InferCNV needs an
# R/Bioconductor base; the two do not share one.
#
# Keep the packages in step with the modules' environment.yml files, which are
# the conda fallback for the same processes.
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gawk \
        gzip \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        'scanpy>=1.11' \
        'anndata>=0.11' \
        leidenalg \
        python-igraph \
        pandas \
        numpy \
        scipy \
        h5py \
        gget

# Fail the build rather than a run if an import or binary is broken.
RUN curl --version >/dev/null \
    && python3 -c 'import scanpy, anndata, pandas, numpy, scipy, h5py, leidenalg, gget; print("All packages OK")'
