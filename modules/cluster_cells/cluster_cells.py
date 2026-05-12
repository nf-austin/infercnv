#!/usr/bin/env python3
import argparse
import scanpy as sc

def main():
    parser = argparse.ArgumentParser(description="Cluster cells to build a global expression baseline.")
    parser.add_argument("--h5ad", required=True, help="Input h5ad file")
    parser.add_argument("--resolution", type=float, default=0.5, help="Leiden clustering resolution")
    parser.add_argument("--out_annotations", required=True, help="Output TSV for InferCNV")
    parser.add_argument("--out_h5ad", required=True, help="Output annotated h5ad file")
    args = parser.parse_args()

    adata = sc.read_h5ad(args.h5ad)
    bdata = adata.copy()

    sc.pp.normalize_total(bdata, target_sum=1e4)
    sc.pp.log1p(bdata)
    sc.pp.highly_variable_genes(bdata, n_top_genes=2000)
    sc.pp.pca(bdata)
    sc.pp.neighbors(bdata)
    sc.tl.leiden(bdata, resolution=args.resolution)

    adata.obs['leiden'] = 'cluster_' + bdata.obs['leiden'].astype(str)
    adata.obs[['leiden']].to_csv(args.out_annotations, sep="\t", header=False)
    adata.write_h5ad(args.out_h5ad)

if __name__ == "__main__":
    main()