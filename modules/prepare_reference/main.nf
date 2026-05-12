process PREPARE_REFERENCE {
    tag "${species}_${release}"

    conda "${moduleDir}/environment.yml"

    input:
    val species
    val release

    output:
    path "genomic_positions.txt", emit: gene_order

    script:
    """
    # Download GTF using gget
    gget ref -w gtf -r ${release} -d -q ${species}

    # Locate the downloaded GTF and filter for gene names
    GTF_FILE=\$(ls *.gtf.gz)
    gunzip -c \$GTF_FILE | grep 'gene_name' > assembly.gtf

    # Download the InferCNV parsing script
    curl -o gtf_to_position_file.py https://raw.githubusercontent.com/broadinstitute/infercnv/refs/heads/master/scripts/gtf_to_position_file.py

    # Generate genomic positions
    python gtf_to_position_file.py --attribute_name gene_name assembly.gtf genomic_positions.tmp

    # Remove duplicate gene names (first word)
    awk '!seen[\$1]++' genomic_positions.tmp > genomic_positions.txt
    """
}