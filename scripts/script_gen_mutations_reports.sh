#!/bin/bash

script_name=$(basename $0)
params=$@

#define default values
TOTAL_RUN_TIME_DEFAULT="7-00:00:00"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {project code}   specify UPPMAX project code (default: no job)
-T {time}           set a limit on the total run time of the job allocation. (defuault: $TOTAL_RUN_TIME_DEFAULT)
-k {name}           specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-t {file}           specify tabix file (required)
-R {region}         specify vcf region of interest (default:all)
-P {patient list}   specify vcf columns to exported (default:all)
-S {config}         specify statistical option to be shown up in the report. The format of option is [stat1_name1,[stat1_file_name],stat1_col_name1[#stat1_col_name1_pos][-stat1_col_name2[..]][:stat2_name,[stat2_file_name][..]][..]] (default:None)
-F {float}          specify frequency ratios for rare mutations (ex: OAF:0.1,MAF:0.2) (default:None)
-Z {zygo codes}     specify custom zygosity codes (ex: WT:.,NA:na) (default: (HOM:"hom", HET:"het", WT:"wt", NA:".", OTH:"oth")
-f {family infos}   specify families information in format [family1_code|family1_patient1_code[|family1_patient2_code[..]][,family2_code|family2_patient1_code[..]][..]]
-E {attributes}     specify extra attributes (ex: share,rare) (default: None)
-C {color info}     specify color information of region of interest (default: None)
-M {config}         specify header text to be modified, ex 'ALL_PF:OAF' will change one of the header column from 'ALL_PF' to 'OAF' (default: None)
-e {config}         specify exclusion criteria (I: intergenic and intronic, S: synonymous mutation, C: common mutation)(default: None)
-D                  indicated to enable developer mode (default: DEVELOPER_MODE_DEFAULT)
-A {directory}      specify ANNOVAR root directory (required)
-o {directory}      specify project output directory (required)
-l {directory}      specify slurm log directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

subproject_params_prefix=""

# parse option
while getopts ":p:T:k:t:R:P:S:F:Z:f:E:C:M:e:cDA:o:l:" OPTION; do
  case "$OPTION" in
    p)
      project_code="$OPTARG"
      subproject_params_prefix+=" -p $OPTARG"
      ;;
    T)
      total_run_time="$OPTARG"
      subproject_params_prefix+=" -T $OPTARG"
      ;;
    k)
      running_key="$OPTARG"
#      subproject_params_prefix+=" -k $OPTARG"
      ;;
    t)
      tabix_file="$OPTARG"
      subproject_params_prefix+=" -t $OPTARG"
      ;;
    R)
#      vcf_region="$OPTARG"
      subproject_params_prefix+=" -R $OPTARG"
      ;;
    P)
#      col_names="$OPTARG"
      subproject_params_prefix+=" -P $OPTARG"
      ;;
    S)
#      stat_config="$OPTARG"
      subproject_params_prefix+=" -S $OPTARG"
      ;;
    F)
#      maf_ratio="$OPTARG"
      subproject_params_prefix+=" -F $OPTARG"
      ;;
    Z)
#      maf_ratio="$OPTARG"
      subproject_params_prefix+=" -Z $OPTARG"
      ;;
    f)
#      families_infos="$OPTARG"
      subproject_params_prefix+=" -f $OPTARG"
      ;;
    E)
#      extra_attributes="$OPTARG"
      subproject_params_prefix+=" -E $OPTARG"
      ;;
    C)
      subproject_params_prefix+=" -C $OPTARG"
      ;;
    M)
      subproject_params_prefix+=" -M $OPTARG"
      ;;
    e)
      subproject_params_prefix+=" -e $OPTARG"
      ;;
    c)
#      :
#      cached_enable="On"
#      subproject_params_prefix+=" -p $OPTARG"
      ;;
    D)
      subproject_params_prefix+=" -D"
      ;;
    A)
      annovar_root_dir="$OPTARG"
      subproject_params_prefix+=" -A $OPTARG"
      ;;
    o)
      project_out_dir="$OPTARG"
#      subproject_params_prefix+=" -o $OPTARG"
      ;;
    l)
      slurm_log_dir="$OPTARG"
      subproject_params_prefix+=" -l $OPTARG"
      ;;
    *)
      die "unrecognized option (-$OPTION) from executing: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specify a unique key for this run (-k)"
[ ! -z $tabix_file ] || die "Please specify tabix file (-t)"
[ ! -z $annovar_root_dir ] || die "Please specify a annovar root directory (-A)"
[ ! -z $project_out_dir ] || die "Please specify an output directory (-o)"
[ ! -z $slurm_log_dir ] || die "Please specify a log directory (-l)"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"
[ -d $annovar_root_dir ] || die "$annovar_root_dir is not a valid directory"
[ -d $project_out_dir ] || die "$project_out_dir is not a valid directory"
[ -d $slurm_log_dir ] || die "$slurm_log_dir is not a valid directory"

##setting default values:
: ${total_run_time=$TOTAL_RUN_TIME_DEFAULT}

running_time_key=$(date +"%Y%m%d%H%M%S")

function display_param {
    PARAM_PRINT_FORMAT="##   %-50s%s\n"
    param_name=$1
    param_val=$2

    printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val" 1>&2
}


function display_param {
    PARAM_PRINT_FORMAT="##   %-50s%s\n"
    param_name=$1
    param_val=$2

    printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val" 1>&2
}

## ****************************************  display configuration  ****************************************
## display required configuration
echo "##" 1>&2
echo "## ************************************************** S T A R T <$script_name> **************************************************" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to generate mutations reports" 1>&2
echo "##" 1>&2
echo "## overall configuration" 1>&2
if [ ! -z "$project_code" ]
then
    display_param "project code (-p)" "$project_code"
    display_param "total run time (-T)" "$total_run_time"
fi
display_param "running key prefix (-k)" "$running_key"
display_param "slurm log directory (-l)" "$slurm_log_dir"
display_param "running-time key" "$running_time_key"
display_param "subproject parameters prefix" "$subproject_params_prefix"


# ****************************************  executing  ****************************************
# >>>>>> General functions
function submit_cmd {
    cmd=$1
    job_name=$2

    sbatch_cmd="sbatch"
    sbatch_cmd+=" -A $project_code"
    sbatch_cmd+=" -p core"
    sbatch_cmd+=" -n 1 "
    sbatch_cmd+=" -t $total_run_time"
    sbatch_cmd+=" -J $job_name"
    sbatch_cmd+=" -o $slurm_log_dir/$job_name.$running_time_key.log.out"
    sbatch_cmd+=" $cmd"
    echo "##" 1>&2
    echo "##" 1>&2
    echo "## executing: $sbatch_cmd " 1>&2
    eval "$sbatch_cmd" 1>&2
    queue_txt=( $( squeue --name="$job_name" | grep -v "PARTITION" | tail -1 ) )
    echo ${queue_txt[0]}
}

function get_job_status {
    job_id=$1

    status_txt=( $( sacct -j "$job_id" | grep "$job_id" | head -1 ))
    echo ${status_txt[5]}
}

# >>>>>> Generating mutations reports
report_job_count=0

## submit job to generate mutations reports
job_key="$running_key"_xls
sub_project_out_dir="$project_out_dir/$job_key"
if [ ! -d "$sub_project_out_dir" ]
then
    mkdir "$sub_project_out_dir"
fi
cmd="$SCRIPT_GEN_MUTATIONS_REPORT"
cmd+="$subproject_params_prefix"
cmd+=" -k $job_key"
cmd+=" -o $sub_project_out_dir"
report_job_id[$report_job_count]=`submit_cmd "$cmd" "$job_key"`
report_job_count=$((report_job_count+1))

# ****************************************  executing  ****************************************

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
