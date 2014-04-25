#!/bin/bash 

script_name=$(basename $0)

#define default values
VCF_REGION_DEFAULT=""
COL_NAMES_DEFAULT=""
MUTATED_ONLY_DEFAULT="no"
OAF_OUT_DEFAULT=""
GT_VCF_GT_OUT_DEFAULT=""
MT_VCF_GT_OUT_DEFAULT=""
SA_OUT_DEFAULT=""

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
-H {directory}     specify hbvdb root directory (required)
-A {directory}     specify annovar root directory (required)
-w {directory}     specify working directory (required)
-l {directory}     specify slurm log directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts ":p:N:t:R:c:O:G:M:S:H:A:w:l:" OPTION; do
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
      gt_vcf_gt_out_file="$OPTARG"
      ;;
    M)
      mt_vcf_gt_out_file="$OPTARG"
      ;;
    S)
      sa_out_file="$OPTARG"
      ;;
    H)
      hbvdb_tools_root_dir="$OPTARG"
      ;;
    A)
      annovar_root_dir="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    l)
      log_dir="$OPTARG"
      ;;
    *)
      die "unrecognized option from executing: $0 $@"
      ;;
  esac
done

[ ! -z $project_code ] || die "Please specfify UPPMAX project code (-p)"
[ ! -z $dataset_name ] || die "Please specfify a name of this dataset (-N)"
[ ! -z $tabix_file ] || die "Please specify tabix file (-t)"
[ ! -z $hbvdb_tools_root_dir ] || die "Please specify a hbvdb root directory (-H)"
[ ! -z $annovar_root_dir ] || die "Please specify a annovar root directory (-A)"
[ ! -z $working_dir ] || die "Please specify a working directory (-w)"
[ ! -z $log_dir ] || die "Please specify a log directory (-l)"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"
[ -d $hbvdb_tools_root_dir ] || die "$hbvdb_tools_root_dir is not a valid directory"
[ -d $annovar_root_dir ] || die "$annovar_root_dir is not a valid directory"
[ -d $working_dir ] || die "$working_dir is not a valid directory"
[ -d $log_dir ] || die "$log_dir is not a valid directory"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_names=$COL_NAMES_DEFAULT}
: ${mutated_only=$MUTATED_ONLY_DEFAULT}
: ${oaf_out_file=$OAF_OUT_DEFAULT}
: ${gt_vcf_gt_out_file=$GT_VCF_GT_OUT_DEFAULT}
: ${mt_vcf_gt_out_file=$MT_VCF_GT_OUT_DEFAULT}
: ${sa_out_file=$SA_OUT_DEFAULT}

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
echo "##" 1>&2
echo "## ************************************************** S T A R T <$script_name> **************************************************" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to submit scripts to run in UPPMAX system. These other scripts will generate default data useful for analysis given a vcf file" 1>&2
echo "##" 1>&2
echo "##" 1>&2
## display required configuration
echo "## overall configuration" 1>&2
display_param "project code (-p)" "$project_code"
display_param "dataset name (-N)" "$dataset_name"
display_param "tabix file (-v)" "$tabix_file"
display_param "running-time key" "$running_time"
display_param "working directory (-w)" "$working_dir"

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
    hbvdb_out="$working_dir/$dataset_name"
    display_param "HBVDB" "$hbvdb_out"
    display_param "oaf output file (-O)" "$oaf_out_file"
fi
if [ ! -z "$gt_vcf_gt_out_file" ]; then
    display_param "genotyped vcf gt output file (-G)" "$gt_vcf_gt_out_file"
fi
if [ ! -z "$mt_vcf_gt_out_file" ]; then
    display_param "mutated vcf gt output file (-M)" "$mt_vcf_gt_out_file"
fi
if [ ! -z "$sa_out_file" ]; then
    display_param "summarize annovar output file (-S)" "$sa_out_file"
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
    batch_cmd+=" -o $log_dir/$job_name.$running_time.log.out"
    batch_cmd+=" $cmd"
    echo "##" 1>&2
    echo "##" 1>&2
    echo "## executing: $batch_cmd " 1>&2
    eval $batch_cmd
}

if [ ! -z "$oaf_out_file" ]; then
    ## generating oaf-related data
    cmd="$SCRIPT_GEN_OAF $hbvdb_tools_root_dir $tabix_file $hbvdb_out $working_dir $oaf_out_file"
    running_key="$dataset_name"_oaf
    submit_cmd "$cmd" "$running_key"
fi
if [ ! -z "$gt_vcf_gt_out_file" ]; then
    ## generating genotyped vcf gt data
    running_key="$dataset_name"_gt_vcf_gt
    cmd="$SCRIPT_GEN_VCF_GT -k $running_key -t $tabix_file -o $gt_vcf_gt_out_file"
    if [ ! -z "$col_names" ]; then
	cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
	cmd+=" -R $vcf_region"
    fi
    submit_cmd "$cmd" "$running_key"
fi
if [ ! -z "$mt_vcf_gt_out_file" ]; then
    ## generating mutated vcf gt data
    running_key="$dataset_name"_mt_vcf_gt
    cmd="$SCRIPT_GEN_VCF_GT -k $running_key -t $tabix_file -o $mt_vcf_gt_out_file -M"
    if [ ! -z "$col_names" ]; then
	cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
	cmd+=" -R $vcf_region"
    fi
    submit_cmd "$cmd" "$running_key"
fi
if [ ! -z "$sa_out_file" ]; then
    ## generating summarize annovar database file
    running_key="$dataset_name"_sa
    cmd="$SCRIPT_GEN_SA -A $annovar_root_dir -k $running_key -t $tabix_file -o $sa_out_file -w $working_dir"
    if [ ! -z "$col_names" ]; then
	cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
	cmd+=" -R $vcf_region"
    fi
    submit_cmd "$cmd" "$running_key"
fi

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
