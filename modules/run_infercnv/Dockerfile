# R/Bioconductor stack for RUN_INFERCNV.
#
# A custom image rather than a public biocontainer because no stock biocontainer
# carries infercnv AND zellkonverter together, and RUN_INFERCNV needs both
# (zellkonverter reads the .h5ad, infercnv does the inference).
#
# Keep the packages in step with modules/run_infercnv/environment.yml, which is
# the conda fallback for the same process.
FROM bioconductor/bioconductor_docker:RELEASE_3_20

# Provision basilisk environments directly inside the R system library at build
# time so RUN_INFERCNV never runs installConda() or touches lock files at
# runtime inside a read-only Singularity image or offline compute node.
ENV BASILISK_USE_SYSTEM_DIR=1

RUN Rscript -e 'BiocManager::install(c("infercnv", "zellkonverter", "SummarizedExperiment"), ask=FALSE, update=FALSE)' \
 && Rscript -e 'install.packages(c("optparse"), repos="https://cran.r-project.org")'

# Ensure the system-dir basilisk env is initialized and readable by any user.
RUN Rscript -e 'library(zellkonverter); basilisk::basiliskStart(zellkonverter::zellkonverterAnnDataEnv()) -> p; basilisk::basiliskStop(p)'

# Fail the build rather than a run if a library is missing.
RUN Rscript -e 'library(infercnv); library(zellkonverter); library(SummarizedExperiment); library(optparse); library(Matrix); cat("All packages OK\n")'
