#!/bin/bash

script_name=$(basename $0)

#define default values
PLINK_REGIONS_DEFAULT="All"
PLINK_PHENO_FILE_DEFAULT=""
PVALUE_SIGNIFICANCE_RATIO_DEFAULT="1e-03"
TOTAL_RUN_TIME_DEFAULT="7-00:00:00"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {project code}   specify UPPMAX project code (required)
-t {time}	    set a limit on the total run time of the job allocation. (defuault: $TOTAL_RUN_TIME_DEFAULT)
-k {name}	    specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-b {file}	    specify PLINK binary input file prefix (required)
-W {file}	    specify PLINK haplotype window sizes for association study (comma separated, e.g., -W 1,2) (required)
-R {region}	    specify PLINK region of interest (default: $PLINK_REGIONS_DEFAULT)
-P {file}	    specify PLINK phenotype file (default: None)
-S {number}         specify P-value significant ratio (default: $PVALUE_SIGNIFICANCE_RATIO_DEFAULT)
-o {directory}	    specify output directory (required)
-w {directory}	    specify working directory (required)
-l {directory}	    specify slurm log directory (required)
EOF
)


die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

# parse option
while getopts ":p:t:k:b:W:P:R:S:o:w:l:" OPTION; do
  case "$OPTION" in
    p)
      project_code="$OPTARG"
      ;;
    t)
      total_run_time="$OPTARG"
      ;;
    k)
      running_key="$OPTARG"
      ;;
    b)
      plink_bin_file_prefix="$OPTARG"
      ;;
    W)
      plink_hap_window_sizes="$OPTARG"
      ;;
    P)
      plink_pheno_file="$OPTARG"
      ;;
    R)
      plink_regions="$OPTARG"
      ;;
    S)
      pvalue_significance_ratio="$OPTARG"
      ;;
    o)
      out_dir="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    l)
      log_dir="$OPTARG"
      ;;
    *)
      die "unrecognized option from (-$OPTION) executing: $0 $@"
      ;;
  esac
done

[ ! -z $project_code ] || die "Please specify UPPMAX project code (-p)"
[ ! -z $running_key ] || die "Please specify a unique key for this run (-k)"
[ ! -z $plink_bin_file_prefix ] || die "Please specify PLINK binary input file prefix (-b)"
[ ! -z $plink_hap_window_sizes ] || die "Please specify PLINK haplotype window sizes (-W)"
[ ! -z $out_dir ] || die "Plesae specify output directory (-o)"
[ ! -z $working_dir ] || die "Plesae specify working directory (-w)"
[ ! -z $log_dir ] || die "Plesae specify logging directory (-l)"
[ -f "$plink_bin_file_prefix".bed ] || die "$plink_bin_file_prefix is not a valid file prefix"
[ -f "$plink_bin_file_prefix".bim ] || die "$plink_bin_file_prefix is not a valid file prefix"
[ -f "$plink_bin_file_prefix".fam ] || die "$plink_bin_file_prefix is not a valid file prefix"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$out_dir is not a valid directory"
[ -d $log_dir ] || die "$log_dir is not a valid directory"

#setting default values:
: ${plink_regions=$PLINK_REGIONS_DEFAULT}
: ${plink_pheno_file=$PLINK_PHENO_FILE_DEFAULT}
: ${pvalue_significance_ratio=$PVALUE_SIGNIFICANCE_RATIO_DEFAULT}
: ${total_run_time=$TOTAL_RUN_TIME_DEFAULT}

running_time=$(date +"%Y%m%d%H%M%S")

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
display_param "running key (-k)" "$running_key"
display_param "PLINK input file prefix (-b)" "$plink_bin_file_prefix"
display_param "PLINK haplotype window sizes (-W)" "$plink_hap_window_sizes"
display_param "P-value significance ratio (-S)" "$pvalue_significance_ratio"
display_param "log directory (-l)" "$log_dir"
display_param "working directory (-w)" "$working_dir"
display_param "running-time key" "$running_time"

## display optional configuration
echo "##" 1>&2
echo "## optional configuration" 1>&2
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
if [ ! -z "$plink_pheno_file" ]
then
    display_param "PLINK phenotype file" "$plink_pheno_file"
fi

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
    sbatch_cmd+=" -o $log_dir/$job_name.$running_time.log.out"
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
    job_key="$running_key"_xls_`echo ${splited_plink_regions[$i]} | tr '-' '_' | tr ':' '_'`
    sub_out_dir="$out_dir/$job_key"
    cmd="$SCRIPT_GEN_PLINK_REPORT"
    cmd+=" -p $project_code"
    cmd+=" -t $total_run_time"
    cmd+=" -k $job_key"
    cmd+=" -b $plink_bin_file_prefix"
    cmd+=" -W $plink_hap_window_sizes"
    cmd+=" -S $pvalue_significance_ratio"
    cmd+=" -R ${splited_plink_regions[$i]}"
    cmd+=" -w $working_dir"
    cmd+=" -o $sub_out_dir"
    cmd+=" -l $log_dir"
    if [ ! -d "$sub_out_dir" ]
    then
	mkdir "$sub_out_dir"
    fi
    if [ ! -z "$plink_pheno_file" ]
    then
        cmd+=" -P $plink_pheno_file"
    fi
    report_job_id[$report_job_count]=`submit_cmd "$cmd" "$job_key"`
    report_job_count=$((report_job_count+1))
done

# ****************************************  executing  ****************************************

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
