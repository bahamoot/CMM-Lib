#!/bin/bash

script_name=$(basename $0)
params=$@

#define default values
TOTAL_RUN_TIME_DEFAULT="7-00:00:00"
OAF_RATIO_DEFAULT="0.1"
MAF_RATIO_DEFAULT="0.2"
CACHED_ENABLE_DEFAULT="Off"

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
-c {patient list}   specify vcf columns to exported (default:all)
-W {float}          specify OAF criteria for rare mutations (default:OAF_RATIO_DEFAULT)
-F {float}          specify MAF criteria for rare mutations (default:MAF_RATIO_DEFAULT)
-f {family infos}   specify families information in format [family1_code|family1_patient1_code[|family1_patient2_code[..]][,family2_code|family2_patient1_code[..]][..]]
-e                  having a suggesting sheet with only exonic mutations
-m                  having a suggesting sheet with only missense mutations
-d                  having a suggesting sheet with only deleterious mutations
-r                  having a suggesting sheet with only rare mutations (using OAF and MAF criteria)
-C                  use cached data instead of fresh generated one (default: $CACHED_ENABLE_DEFAULT)
-A {directory}      specify ANNOVAR root directory (required)
-o {directory}      specify output directory (required)
-w {directory}      specify working directory (required)
-l {directory}      specify slurm log directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

# parse option
while getopts ":p:T:k:t:R:c:W:F:f:emdrA:o:w:l:" OPTION; do
  case "$OPTION" in
    p)
      project_code="$OPTARG"
      ;;
    T)
      total_run_time="$OPTARG"
      ;;
    k)
      running_key="$OPTARG"
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
    W)
      oaf_ratio="$OPTARG"
      ;;
    F)
      maf_ratio="$OPTARG"
      ;;
    f)
      families_infos="$OPTARG"
      ;;
    e)
      exonic_filtering="On"
      ;;
    m)
      missense_filtering="On"
      ;;
    d)
      deleterious_filtering="On"
      ;;
    r)
      rare_filtering="On"
      ;;
    C)
      cached_enable="On"
      ;;
    A)
      annovar_root_dir="$OPTARG"
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
      die "unrecognized option (-$OPTION) from executing: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specify a unique key for this run (-k)"
[ ! -z $tabix_file ] || die "Please specify tabix file (-t)"
[ ! -z $annovar_root_dir ] || die "Please specify a annovar root directory (-A)"
[ ! -z $out_dir ] || die "Please specify an output directory (-o)"
[ ! -z $working_dir ] || die "Please specify a working directory (-w)"
[ ! -z $log_dir ] || die "Please specify a log directory (-l)"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"
[ -d $annovar_root_dir ] || die "$annovar_root_dir is not a valid directory"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$working_dir is not a valid directory"
[ -d $log_dir ] || die "$log_dir is not a valid directory"

##setting default values:
: ${total_run_time=$TOTAL_RUN_TIME_DEFAULT}
: ${oaf_ratio=$OAF_RATIO_DEFAULT}
: ${maf_ratio=$MAF_RATIO_DEFAULT}

running_time=$(date +"%Y%m%d%H%M%S")

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
display_param "running key (-k)" "$running_key"
display_param "tabix file (-t)" "$tabix_file"
display_param "ANNOVAR root directory (-A)" "$annovar_root_dir"
display_param "output directory (-o)" "$out_dir"
display_param "working directory (-w)" "$working_dir"
display_param "log directory (-l)" "$log_dir"
display_param "running-time key" "$running_time"

## display optional configuration
echo "##" 1>&2
echo "## optional configuration" 1>&2
if [ ! -z "$vcf_region" ]; then
    display_param "vcf region (-R)" "$vcf_region"
else
    display_param "vcf region" "ALL"
fi
if [ ! -z "$col_names" ]; then
    display_param "column names (-c)" "$col_names"
else
    display_param "column names" "ALL"
fi
display_param "oaf ratio (-W)" "$oaf_ratio"
display_param "maf ratio (-F)" "$maf_ratio"

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

# >>>>>> Generating mutations reports
report_job_count=0

## submit job to generate mutations reports
job_key="$running_key"_mut_reps
sub_out_dir="$out_dir/$job_key"
cmd="$SCRIPT_GEN_MUTATIONS_REPORT"
cmd+=" $@"
report_job_id[$report_job_count]=`submit_cmd "$cmd" "$job_key"`
report_job_count=$((report_job_count+1))

# ****************************************  executing  ****************************************

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
