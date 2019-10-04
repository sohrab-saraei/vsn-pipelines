# SingleCellTxBenchmark

A repository of pipelines for single-cell data in Nextflow DSL2.

All the output generated by the pipelines will be located in the directory specified by `params.global.outdir` in `nextflow.config`.

# Dependencies

Make sure you have the following softwares installed,
- nextflow (version 19.09.0-edge)
* A container system, either of:
    * [Docker](https://docs.docker.com/)
    * [Singularity](https://www.sylabs.io/singularity/)


# Repository structure

## Root
The repository root contains a `main.nf` and associated `nextflow.config`.
The root `main.nf` imports and calls sub-workflows defined in the modules.

## Modules
A "module" consists of a folder labeled with the tool name (Scanpy, SCENIC, utils, etc.), with subfolders for
* `bin/` (scripts passed into the container)
* `processes/` (where Nextflow processes are defined)
The root of the modules folder contains workflow files + associated configs (as many as there are workflows):
* `main.nf` + `nextflow.config`
* `workflow1.nf` + `workflow2.config`
* ...

```
src/
├── cellranger
│   ├── main.nf
│   ├── nextflow.config
│   └── processes
│       ├── count.nf
│       └── mkfastq.nf
│
├── channels
│   └── tenx.nf
│
├── scenic
│   ├── bin
│   │   ├── grnboost2_without_dask.py
│   │   └── merge_SCENIC_motif_track_loom.py
│   ├── processes
│   │   ├── aucell.nf
│   │   ├── cistarget.nf
│   │   ├── grnboost2withoutDask.nf
│   │   └── mergeScenicLooms.nf
│   ├── main.nf
│   └── scenic.config
│
└── utils
    ├── bin
    │   ├── h5ad_to_loom.py
    │   ├── sc_file_annotator.py
    │   ├── sc_file_concatenator.py
    │   └── sc_file_converter.py
    ├── utils.config
    └── processes
        ├── files.nf
        ├── h5ad_to_loom.nf
        ├── utils_1.test.nf
        ├── utils_2.test.nf
        └── utils.nf
```

## Workflows

Workflows (chains of nf processes) are defined in the module root folder (e.g. [src/Scanpy/bec_bbknn.nf](https://github.com/aertslab/SingleCellTxBenchmark/blob/module_refactor/src/scanpy/bec_bbknn.nf))
Workflows import multiple processes and define the workflow by name:
```groovy
include SC__CELLRANGER__MKFASTQ from './processes/mkfastq'  params(params)
include SC__CELLRANGER__COUNT   from './processes/count'    params(params)

workflow CELLRANGER {
    main:
        SC__CELLRANGER__MKFASTQ(file(params.sc.cellranger.mkfastq.csv), file(params.sc.cellranger.mkfastq.runFolder))
        SC__CELLRANGER__COUNT(file(params.sc.cellranger.count.transcriptome), SC__CELLRANGER__MKFASTQ.out.flatten())
    emit:
        SC__CELLRANGER__COUNT.out
}

```

### Workflow imports
Entire **sub-workflows** can also be imported in other workflows with one command (inheriting all of the process imports from the workflow definition):
```groovy
include CELLRANGER from '../cellranger/main.nf' params(params)
```

This leads to the ability to easily define **high-level workflows** in the master nf file: `aertslab/SingleCellTxBenchmark/main.nf`:
```groovy
include CELLRANGER from './src/cellranger/main.nf' params(params)
include BEC_BBKNN from './src/scanpy/bec_bbknn.nf' params(params)
include SCENIC from './src/scenic/main.nf' params(params)

workflow {
    CELLRANGER()
    BEC_BBKNN( CELLRANGER.out )
    SCENIC( BEC_BBKNN.out )
}
```


## Parameters structure
Parameters are stored in a separate config file per workflow, plus the main `nextflow.config`. 
These parameters are merged when starting the run using e.g.:
```groovy
includeConfig 'src/scenic/nextflow.config'
```

The parameter structure internally (post-merge) is:
```groovy
params {
    global {
        baseFilePath = "/opt/SingleCellTxBenchmark"
        project_name = "MCF7"
        ...
    }
    sc {
        utils {
            file_converter {
                ...
            }
            file_annotator {
                ...
            }
            file_concatenator {
                ...
            }
        }
        scanpy {
            container = 'docker://dweemx/sctx-scanpy:0.2.0'
            filter {
                ...
            }
            data_transformation {
                ...
            }
            normalization {
                ...
            }
            feature_selection {
                ...
            }
            feature_scaling {
                ...
            }
            dim_reduction {
                pca {
                    dimReductionMethod = 'PCA' 
                    ...
                }
                umap {
                    dimReductionMethod = 'UMAP' 
                    ...
                }
            }
            batch_effect_correct {
                ...
            }
            clustering {
                ...
            }
        }
    }
}

```


# Pipelines

## Running the pipeline directly from GitHub:

```bash
nextflow run aertslab/SingleCellTxBenchmark -profile singularity,bbknn -user <GitHub-user>
```
This picks up `aertslab/SingleCellTxBenchmark/main.nf` and runs the worflow defined there, using the built-in configs, which are merged from each tool used.

### Customizing config files
In order to use a customized config file, the default file can be used as a template:
```bash
wget https://raw.githubusercontent.com/aertslab/SingleCellTxBenchmark/master/nextflow.config
wget https://raw.githubusercontent.com/aertslab/SingleCellTxBenchmark/master/src/scanpy/scanpy.config
# edit the config file parameters, then:
nextflow run aertslab/SingleCellTxBenchmark -profile singularity,bbknn -c nextflow.config,scanpy.config -user <GitHub-user>
```

In most cases, sub-workflows could also be run directly (locally only at this point):
```bash
nextflow run src/scenic/main.nf -profile singularity,scenic
```


## Multiple Datasets

Pipelines to aggregate multiple datasets together.

### bbknn 
Source: https://github.com/Teichlab/bbknn/blob/master/examples/pancreas.ipynb

**How to run on 10xGenomics datasets ?**

```{bash}
OUTPUT_DIRECTORY="out"
PROJECT_NAME="tiny"
```

Let's say the file structure of your data looks like this,

```
/home/data/
└── cellranger
    ├── Sample A
    │   └── outs
    │       ├── filtered_feature_bc_matrix
    │       └── ...
    └── Sample_B
        └── outs
            ├── filtered_feature_bc_matrix
            └── ...
```

Then the command to run the pipeline will be:

Using singularity,
```{bash}
nextflow run \
   src/scanpy/bec_bbknn.nf \
      -profile singularity \
      --tenx_folder /home/data/cellranger/**/filtered_feature_bc_matrix \
      --sample_metadata /home/data/cellranger/metadata.tsv \
      --outdir ${OUTPUT_DIRECTORY} \
      --project_name ${PROJECT_NAME} \
      -with-report report.html \
      -with-trace
```

# Limitations

### Parameters structure:
* Cannot override nested parameters from the command line (`nextflow run aertslab/SingleCellTxBenchmark --outdir output/` works, but `--sc.cellranger.outdir output/` does not.
See also [this GitHub issue](https://github.com/nextflow-io/nextflow/issues/1182).

### Bin folder is not added to the $PATH variable by nextflow.
The current workaround is to use the full path in script calls to module bins: `${workflow.projectDir}/src/scanpy/bin/feature_selection/sc_select_variable_genes.py'.
Alternatives are to add the module bin folders to the nextflow path in `nextflow.config`:
```groovy
env {
    PATH = System.getProperty("user.dir").concat("/src/singlecelltxbenchmark/pipelines/scenic/bin/:${PATH}")
}
```
but this using "user.dir" isn't a proper solution yet.

### How to define multiple workflows in the master main.nf
1. Create named master workflows in `main.nf` and use if/then statements to determine
2. Create a github organization, and have separate repositories for each master workflow

# Development

## Module testing

Modules and processes can be tested independently, you can find an example in `src/utils/main.test.nf`.

The `SC__FILE_CONVERTER` process is tested against the `tiny` dataset available in `data/01.count`.

