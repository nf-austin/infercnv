process PREPARE_REFERENCE {
    tag "${species}_${release}"

    conda "${moduleDir}/environment.yml"
    // Container assigned in nextflow.config's withName block.

    input:
    val species
    val release
    path gtf   // pre-staged GTF, or the 'NO_GTF' sentinel to download one

    output:
    path "genomic_positions.txt", emit: gene_order

    script:
    // gtf_to_position_file.py is vendored in bin/ (see its header for the
    // upstream commit) rather than curl'd at runtime, and reached via
    // Nextflow's bin/ PATH injection.
    def use_local_gtf = gtf.name != 'NO_GTF'
    def fetch_gtf = use_local_gtf ? """
    # Pre-staged GTF supplied via --gtf; no network needed.
    cp ${gtf} supplied.gtf.gz 2>/dev/null || cp ${gtf} supplied.gtf
    GTF_FILE=\$(ls supplied.gtf.gz supplied.gtf 2>/dev/null | head -1)
    """ : """
    # Download the Ensembl GTF. Needs outbound network FROM THE COMPUTE NODE,
    # which most clusters do not provide.
    gget ref -w gtf -r ${release} -d -q ${species} || {
        echo "ERROR: could not download the Ensembl GTF for species='${species}' release='${release}'." >&2
        echo "       Compute nodes often have no outbound network. Fetch it once on a login" >&2
        echo "       node and re-run with:  --gtf /path/to/${species}.${release}.gtf.gz" >&2
        echo "       Or skip this step entirely with:  --gene_order /path/to/genomic_positions.txt" >&2
        exit 1; }
    GTF_FILE=\$(ls *.gtf.gz | head -1)
    """
    """
    set -euo pipefail
    ${fetch_gtf}

    if [ -z "\${GTF_FILE:-}" ] || [ ! -s "\${GTF_FILE}" ]; then
        echo "ERROR: no usable GTF found. Supply one with --gtf, or skip this step with --gene_order." >&2
        exit 1
    fi

    # Filter for gene names. Handles both gzipped and plain GTF.
    if [ "\${GTF_FILE##*.}" = "gz" ]; then
        gunzip -c "\${GTF_FILE}" | grep 'gene_name' > assembly.gtf
    else
        grep 'gene_name' "\${GTF_FILE}" > assembly.gtf
    fi

    gtf_to_position_file.py --attribute_name gene_name assembly.gtf genomic_positions.tmp

    # Remove duplicate gene names (first field)
    awk '!seen[\$1]++' genomic_positions.tmp > genomic_positions.txt
    """

    stub:
    """
    printf 'GENE1\\tchr1\\t1\\t2\\n' > genomic_positions.txt
    """
}
