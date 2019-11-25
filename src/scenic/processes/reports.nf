nextflow.preview.dsl=2

/* general reporting function: 
takes a template ipynb and adata as input,
outputs ipynb named by the value in ${reportTitle}
*/
process GENERATE_REPORT {

  container params.sc.scenic.container
  clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
  publishDir "${params.sc.scenic.scenicoutdir}/${sampleId}/notebooks", mode: 'link', overwrite: true

  input:
    file ipynb
    tuple val(sampleId), file(loom)
    val reportTitle

  output:
    tuple val(sampleId), file("${reportTitle}.ipynb")
  script:
    """
    papermill ${ipynb} \
        ${reportTitle}.ipynb \
        -p FILE $loom
    """
}

process REPORT_TO_HTML {

  container params.sc.scenic.container
  clusterOptions "-l nodes=1:ppn=2 -l pmem=30gb -l walltime=1:00:00 -A ${params.global.qsubaccount}"
  publishDir "${params.sc.scenic.scenicoutdir}/${sampleId}/notebooks", mode: 'link', overwrite: true

  input:
    tuple val(sampleId), file(ipynb)

  output:
    tuple val(sampleId), file("*.html")
  script:
    """
    jupyter nbconvert ${ipynb} --to html
    """
}