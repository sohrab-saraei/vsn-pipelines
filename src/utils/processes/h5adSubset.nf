nextflow.preview.dsl=2

import java.nio.file.Paths

binDir = !params.containsKey("test") ? "${workflow.projectDir}/src/utils/bin" : Paths.get(workflow.scriptFile.getParent().getParent().toString(), "utils/bin")

include {
    isParamNull
} from './utils.nf' params(params)

process SC__PREPARE_OBS_FILTER {

    container params.sc.scanpy.container
    publishDir "${params.global.outdir}/data/intermediate", mode: 'link', overwrite: true
    clusterOptions "-l nodes=1:ppn=2 -l walltime=1:00:00 -A ${params.global.qsubaccount}"

    input:
        tuple \
            val(sampleId), \
            path(f), \
            val(filterConfig)
        // Expects tool name [string || null]
        val(tool)

    output:
        tuple \
            val(sampleId), \
            path(f), \
            path("${sampleId}.${toolTag}SC__PREPARE_OBS_FILTER.${filterConfig.id}.txt")

    script:
        def sampleParams = params.parseConfig(
            sampleId,
            params.global,
            isParamNull(tool) ? params.sc.cell_filter : params.sc[tool].cell_filter
        )
		processParams = sampleParams.local
        toolTag = isParamNull(tool) ? '' : tool.toUpperCase() + '.'

        input = processParams.method == 'internal' ? f : filterConfig.cellMetaDataFilePath
        valuesToKeepFromFilterColumnAsArguments = filterConfig.valuesToKeepFromFilterColumn.collect({ '--value-to-keep-from-filter-column' + ' ' + it }).join(' ')
        """
        ${binDir}/sc_h5ad_prepare_obs_filter.py \
            ${processParams.containsKey('method') ? '--method ' + processParams.method : ''} \
            --sample-id ${sampleId} \
            --filter-column-name ${filterConfig.filterColumnName} \
            ${valuesToKeepFromFilterColumnAsArguments} \
            ${filterConfig.containsKey('indexColumnName') ? '--index-column-name ' + filterConfig.indexColumnName : ''} \
            ${filterConfig.containsKey('sampleColumnName') ? '--sample-column-name ' + filterConfig.sampleColumnName : ''} \
            $input \
            "${sampleId}.${toolTag}SC__PREPARE_OBS_FILTER.${filterConfig.id}.txt"
        """

}

process SC__APPLY_OBS_FILTER {

    container params.sc.scanpy.container
    publishDir "${params.global.outdir}/data/intermediate", mode: 'link', overwrite: true
    clusterOptions "-l nodes=1:ppn=2 -l walltime=1:00:00 -A ${params.global.qsubaccount}"

    input:
        tuple \
            val(sampleId), \
            path(f), \
            path(filters)
        // Expects tool name [string || null]
        val(tool)

    output:
        tuple \
            val(sampleId), \
            path("${sampleId}.${toolTag}SC__APPLY_OBS_FILTER.${processParams.off}")

    script:
        def sampleParams = params.parseConfig(
            sampleId,
            params.global,
            isParamNull(tool) ? params.sc.cell_filter : params.sc[tool].cell_filter
        )
		processParams = sampleParams.local
        toolTag = isParamNull(tool) ? '' : tool.toUpperCase() + '.'

        filtersAsArguments = filters.collect({ '--filter-file-path' + ' ' + it }).join(' ')
        """
        ${binDir}/sc_h5ad_apply_obs_filter.py \
            $f \
            --output "${sampleId}.${toolTag}SC__APPLY_OBS_FILTER.${processParams.off}" \
            $filtersAsArguments
        """

}
