nextflow.preview.dsl=2

// include getBaseName from '../../utils/files.nf'

process SC__SCENIC__AUCELL {
    cache 'deep'
    container params.container

    input:
    file exprMat
    file regulons
    val type

    output:
    file "auc_${type}.loom"
    // file params.output

    """
    pyscenic aucell \
        $exprMat \
        $regulons \
        -o "auc_${type}.loom" \
        --cell_id_attribute ${params.cell_id_attribute} \
        --gene_attribute ${params.gene_attribute} \
        --num_workers ${params.numWorkers}
    """
}