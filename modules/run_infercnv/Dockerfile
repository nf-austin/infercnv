# R/Bioconductor stack for RUN_INFERCNV.
#
# A custom image rather than a public biocontainer because no stock biocontainer
# carries infercnv AND zellkonverter together, and RUN_INFERCNV needs both
# (zellkonverter reads the .h5ad, infercnv does the inference).
#
# Keep the packages in step with modules/run_infercnv/environment.yml, which is
# the conda fallback for the same process.
FROM bioconductor/bioconductor_docker:RELEASE_3_20

RUN Rscript -e 'BiocManager::install(c("infercnv", "zellkonverter", "SummarizedExperiment"), ask=FALSE, update=FALSE)' \
 && Rscript -e 'install.packages(c("optparse"), repos="https://cran.r-project.org")'

# Pre-provision basilisk's Python env at build time so RUN_INFERCNV does not
# have to download one per task -- compute nodes usually have no outbound network.
RUN Rscript -e 'library(zellkonverter); basilisk::basiliskStart(zellkonverter::zellkonverterAnnDataEnv()) -> p; basilisk::basiliskStop(p)' || true

# Fail the build rather than a run if a library is missing.
RUN Rscript -e 'library(infercnv); library(zellkonverter); library(SummarizedExperiment); library(optparse); library(Matrix); cat("All packages OK\n")'
