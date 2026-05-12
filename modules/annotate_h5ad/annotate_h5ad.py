#!/usr/bin/env python3
import argparse
import os
import scanpy as sc
import pandas as pd
import numpy as np


def main():
    parser = argparse.ArgumentParser(description="Inject InferCNV metrics and sample identity into h5ad.")
    parser.add_argument("--h5ad", required=True)
    parser.add_argument("--sample_id", required=True)
    parser.add_argument("--infercnv_dir", required=True)
    parser.add_argument("--out_h5ad", required=True)
    args = parser.parse_args()

    adata = sc.read_h5ad(args.h5ad)
    adata.obs['sample'] = args.sample_id

    # The default modified expression matrix output by InferCNV 
    # Values are ratios relative to the baseline (1.0 is neutral)
    obs_file = os.path.join(args.infercnv_dir, "infercnv.observations.txt")

    if os.path.exists(obs_file):
        # Read the matrix (InferCNV outputs Genes x Cells)
        cnv_df = pd.read_csv(obs_file, sep=" ", index_col=0)

        # Align cells
        common_cells = adata.obs_names.intersection(cnv_df.columns)
        cnv_df = cnv_df[common_cells]

        # Calculate Diversity Index (proxy for CIN)
        # Using Mean Squared Deviation (MSD) from the neutral diploid state of 1.0. 
        # A higher variance from 1.0 indicates higher chromosomal instability.
        cin_score = ((cnv_df - 1.0) ** 2).mean(axis=0)

        # Inject into adata.obs
        adata.obs['cnv_diversity_index'] = 0.0
        adata.obs.loc[common_cells, 'cnv_diversity_index'] = cin_score.values

    else:
        print(f"Warning: {obs_file} not found. Skipping CIN calculation.")
        adata.obs['cnv_diversity_index'] = np.nan

    adata.write_h5ad(args.out_h5ad)


if __name__ == "__main__":
    main()