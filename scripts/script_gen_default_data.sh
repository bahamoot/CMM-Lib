#!/bin/bash 

#define default values
VCF_REGION_DEFAULT=""
COL_NAMES_DEFAULT=""
MUTATED_ONLY_DEFAULT="no"
OAF_OUT_DEFAULT=""
GENOTYPED_VCF_GT_OUT_DEFAULT=""
MUTATEDED_VCF_GT_OUT_DEFAULT=""
SUMMARIZE_ANNOVAR_OUT_DEFAULT=""

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {project code}  specify UPPMAX project code (required)
-N {dataset name}  specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-t {file}          specify tabix file (required)
-R {region}        specify vcf region of interest (default:all)
-c {patient list}  specify vcf columns to exported (default:all)
-O {out file}      specify oaf output file name (default:no output)
-G {out file}      specify output file name of genotyping db generated from vcf (default:no output)
-M {out file}      specify output file name of mutated GT db generated from vcf (default:no output)
-S {out file}      specify output file name of generating summarize annovar database (default:no output)
-w {dir}           specify working directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts ":p:N:t:R:c:O:G:M:S:w:" OPTION; do
  case "$OPTION" in
    p)
      project_code="$OPTARG"
      ;;
    N)
      dataset_name="$OPTARG"
      ;;
    t)
      tabix_file="$OPTARG"
      ;;
    R)
      vcf_region="$OPTARG"
      ;;
    c)
      col_names="$OPTARG"
      ;;
    O)
      oaf_out_file="$OPTARG"
      ;;
    G)
      genotyped_vcf_gt_out_file="$OPTARG"
      ;;
    M)
      mutated_vcf_gt_out_file="$OPTARG"
      ;;
    S)
      summarize_annovar_out_file="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    *)
      die "unrecognized option from executing: $0 $@"
      ;;
  esac
done

[ ! -z $project_code ] || die "Please specfify UPPMAX project code"
[ ! -z $dataset_name ] || die "Please specfify a name of this dataset"
[ ! -z $tabix_file ] || die "Please specify tabix file"
[ ! -z $working_dir ] || die "Please specify a working directory"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_names=$COL_NAMES_DEFAULT}
: ${mutated_only=$MUTATED_ONLY_DEFAULT}
: ${oaf_out_file=$OAF_OUT_DEFAULT}
: ${genotyped_vcf_gt_out_file=$GENOTYPED_VCF_GT_OUT_DEFAULT}
: ${mutated_vcf_gt_out_file=$MUTATEDED_VCF_GT_OUT_DEFAULT}
: ${summarize_annovar_out_file=$SUMMARIZE_ANNOVAR_OUT_DEFAULT}

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

running_time=$(date +"%Y%m%d%H%M%S")

function display_param {
    PARAM_PRINT_FORMAT="##   %-40s%s\n"
    param_name=$1
    param_val=$2

    printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val" 1>&2
}

## ****************************************  display configuration  ****************************************
## display required configuration
echo "##" 1>&2
echo "## executing: $0 $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to submit scripts to run in UPPMAX system. These other scripts will generate default data useful for analysis given a vcf file" 1>&2
echo "##" 1>&2
echo "##" 1>&2
echo "## overall configuration" 1>&2
display_param "project code (-p)" "$project_code"
display_param "dataset name (-N)" "$dataset_name"
display_param "tabix file (-v)" "$tabix_file"
display_param "running-time key" "$running_time"
display_param "working directory" "$working_dir"

## display optional configuration
echo "##" 1>&2
echo "## optional configuration" 1>&2
if [ ! -z "$col_names" ]; then
    display_param "column names (-c)" "$col_names"
else
    display_param "column names" "ALL"
fi
if [ ! -z "$vcf_region" ]; then
    display_param "vcf region (-R)" "$vcf_region"
else
    display_param "vcf region" "ALL"
fi

## display output configuration
echo "##" 1>&2
echo "## output configuration" 1>&2

if [ ! -z "$oaf_out_file" ]; then
    hbvdb_out=$HBVDB_ROOT_DIR/$dataset_name
    display_param "HBVDB" "$hbvdb_out"
    display_param "oaf output file (-O)" "$oaf_out_file"
fi
if [ ! -z "$genotyped_vcf_gt_out_file" ]; then
    display_param "genotyped vcf gt output file (-G)" "$genotyped_vcf_gt_out_file"
fi
if [ ! -z "$mutated_vcf_gt_out_file" ]; then
    display_param "mutated vcf gt output file (-M)" "$mutated_vcf_gt_out_file"
fi
if [ ! -z "$summarize_annovar_out_file" ]; then
    display_param "summarize annovar output file (-S)" "$summarize_annovar_out_file"
fi

## ****************************************  execute scripts  ****************************************
function submit_cmd {
    cmd=$1
    job_name=$2

    batch_cmd="sbatch"
    batch_cmd+=" -A $project_code"
    batch_cmd+=" -p core"
    batch_cmd+=" -n 1 "
    batch_cmd+=" -t 7-00:00:00"
    batch_cmd+=" -J $job_name"
    batch_cmd+=" -o $CMM_PROJECTS_LOG_DIR/$job_name.$running_time.log.out"
    batch_cmd+=" $cmd"
    echo "##" 1>&2
    echo "##" 1>&2
    echo "## executing: $batch_cmd " 1>&2
    eval $batch_cmd
}

if [ ! -z "$oaf_out_file" ]; then
    ## generating oaf-related data
    cmd="$SCRIPT_GEN_OAF $tabix_file $hbvdb_out $working_dir $oaf_out_file"
    running_key="$dataset_name"_oaf
    submit_cmd "$cmd" "$running_key"
fi
if [ ! -z "$genotyped_vcf_gt_out_file" ]; then
    ## generating genotyped vcf gt data
    running_key="$dataset_name"_gt_vcf_gt
    cmd="$SCRIPT_GEN_VCF_GT -k $running_key -t $tabix_file -o $genotyped_vcf_gt_out_file"
    if [ ! -c "$col_names" ]; then
	cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
	cmd+=" -R $vcf_region"
    fi
    submit_cmd "$cmd" "$running_key"
fi
if [ ! -z "$mutated_vcf_gt_out_file" ]; then
    ## generating mutated vcf gt data
    running_key="$dataset_name"_mt_vcf_gt
    cmd="$SCRIPT_GEN_VCF_GT -k $running_key -t $tabix_file -o $mutated_vcf_gt_out_file -M"
    if [ ! -c "$col_names" ]; then
	cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
	cmd+=" -R $vcf_region"
    fi
    submit_cmd "$cmd" "$running_key"
fi
if [ ! -z "$summarize_annovar_out_file" ]; then
    ## generating summarize annovar database file
    running_key="$dataset_name"_sa
    cmd="$SCRIPT_GEN_SA -k $running_key -t $tabix_file -o $summarize_annovar_out_file -w $working_dir"
    if [ ! -c "$col_names" ]; then
	cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
	cmd+=" -R $vcf_region"
    fi
    submit_cmd "$cmd" "$running_key"
fi
