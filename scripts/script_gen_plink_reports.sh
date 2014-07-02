#!/bin/bash

script_name=$(basename $0)
params="$@"

#define default values
PLINK_REGIONS_DEFAULT="All"
TOTAL_RUN_TIME_DEFAULT="7-00:00:00"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {project code}   specify UPPMAX project code (default: no job)
-T {time}           set a limit on the total run time of the job allocation. (defuault: $TOTAL_RUN_TIME_DEFAULT)
-k {name}           specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-b {file prefix}    specify PLINK input bfile prefix (required)
-W {window list}    specify PLINK haplotype window sizes for association study (comma separated, e.g., -W 1,2) (required)
-R {region}         specify PLINK region of interest (default: $PLINK_REGION_DEFAULT)
-P {file}           specify PLINK phenotype file (default: None)
-f {file prefix}    specify PLINK families haplotypes database tfile prefix (default: None)
-I {ids}            specify PLINK tfam family ids (comma separated, e.g., -I fam_8,fam_24) (default: None)
-s {information}    specify informaiton of families of interest (default: None)
-S {number}         specify P-value significant ratio (default: $PVALUE_SIGNIFICANCE_RATIO_DEFAULT)
-C {color info}     specify color information of region of interest of specific family (default: None)
-D                  indicated to enable developer mode (default: DEVELOPER_MODE_DEFAULT)
-o {directory}      specify project output directory (required)
-l {directory}	    specify slurm log directory (required)
EOF
)


die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

subproject_params_prefix=""

# parse option
while getopts ":p:T:k:b:W:P:f:I:s:R:S:C:Do:l:" OPTION; do
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
      ;;
    b)
      plink_input_bfile_prefix="$OPTARG"
      subproject_params_prefix+=" -b $OPTARG"
      ;;
    W)
      plink_hap_window_sizes="$OPTARG"
      subproject_params_prefix+=" -W $OPTARG"
      ;;
    P)
      subproject_params_prefix+=" -P $OPTARG"
      ;;
    f)
      subproject_params_prefix+=" -f $OPTARG"
      ;;
    I)
      subproject_params_prefix+=" -I $OPTARG"
      ;;
    s)
      subproject_params_prefix+=" -s $OPTARG"
      ;;
    R)
      plink_regions="$OPTARG"
      subproject_params_prefix+=" -R $OPTARG"
      ;;
    S)
      subproject_params_prefix+=" -S $OPTARG"
      ;;
    C)
      subproject_params_prefix+=" -C $OPTARG"
      ;;
    D)
      subproject_params_prefix+=" -D"
      ;;
    o)
      project_out_dir="$OPTARG"
      ;;
    l)
      slurm_log_dir="$OPTARG"
      subproject_params_prefix+=" -l $OPTARG"
      ;;
    *)
      die "unrecognized option from (-$OPTION) executing: $0 $@"
      ;;
  esac
done

[ ! -z $project_code ] || die "Please specify UPPMAX project code (-p)"
[ ! -z $running_key ] || die "Please specify a unique key for this run (-k)"
[ ! -z $plink_input_bfile_prefix ] || die "Please specify PLINK binary input file prefix (-b)"
[ ! -z $plink_hap_window_sizes ] || die "Please specify PLINK haplotype window sizes (-W)"
[ ! -z $project_out_dir ] || die "Plesae specify output directory (-o)"
[ ! -z $slurm_log_dir ] || die "Plesae specify logging directory (-l)"
[ -f "$plink_input_bfile_prefix".bed ] || die "$plink_input_bfile_prefix is not a valid file prefix"
[ -f "$plink_input_bfile_prefix".bim ] || die "$plink_input_bfile_prefix is not a valid file prefix"
[ -f "$plink_input_bfile_prefix".fam ] || die "$plink_input_bfile_prefix is not a valid file prefix"
[ -d $project_out_dir ] || die "$project_out_dir is not a valid directory"
[ -d $slurm_log_dir ] || die "$slurm_log_dir is not a valid directory"

#setting default values:
: ${plink_regions=$PLINK_REGIONS_DEFAULT}
: ${total_run_time=$TOTAL_RUN_TIME_DEFAULT}

running_time_key=$(date +"%Y%m%d%H%M%S")

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
echo "##   A script to generate plink report" 1>&2
echo "##" 1>&2
echo "## overall configuration" 1>&2
display_param "project code (-p)" "$project_code"
display_param "total run time (-t)" "$total_run_time"
display_param "running key prefix (-k)" "$running_key"
display_param "slurm log directory (-l)" "$slurm_log_dir"
display_param "running-time key" "$running_time_key"
if [ "$plink_regions" = "All" ]
then
    display_param "PLINK region" "$plink_regions"
else
    IFS='|' read -ra splited_plink_regions <<< "$plink_regions"
    echo "##   PLINK region (-R)" 1>&2
    for (( i=0; i<$((${#splited_plink_regions[@]})); i++ ))
    do
	display_param "  plink region $((i+1))" "${splited_plink_regions[$i]}"
    done
fi
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

# >>>>>> Generating PLINK report
report_job_count=0

## submit job to generate PLINK report
for (( i=0; i<$((${#splited_plink_regions[@]})); i++ ))
do
    job_key="$running_key"_`echo ${splited_plink_regions[$i]} | tr '-' '_' | tr ':' '_'`
    sub_project_out_dir="$project_out_dir/$job_key"
    cmd="$SCRIPT_GEN_PLINK_REPORT"
    cmd+="$subproject_params_prefix"
    cmd+=" -k $job_key"
    if [ ! -d "$sub_project_out_dir" ]
    then
        mkdir "$sub_project_out_dir"
    fi
    cmd+=" -R ${splited_plink_regions[$i]}"
    cmd+=" -o $sub_project_out_dir"
    report_job_id[$report_job_count]=`submit_cmd "$cmd" "$job_key"`
    report_job_count=$((report_job_count+1))
done

# ****************************************  executing  ****************************************

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
