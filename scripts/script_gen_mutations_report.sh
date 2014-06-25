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
while getopts ":p:T:k:t:R:c:W:F:emdrCA:o:w:l:" OPTION; do
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
: ${cached_enable=$CACHED_ENABLE_DEFAULT}

summary_xls_out="$out_dir/$running_key"_mutations_summary.xls

running_time=$(date +"%Y%m%d%H%M%S")

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

suggesting_sheet="False"
if [ "$exonic_filtering" = "On" ]; then
    suggesting_sheet="True"
fi
if [ "$missense_filtering" = "On" ]; then
    suggesting_sheet="True"
fi
if [ "$deleterious_filtering" = "On" ]; then
    suggesting_sheet="True"
fi
if [ "$rare_filtering" = "On" ]; then
    suggesting_sheet="True"
fi

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
display_param "use cached data instead of fresh generated one" "$cached_enable"

if [ "$suggesting_sheet" = "True" ]; then
    ## display suggesting-sheet configuration
    echo "##" 1>&2
    echo "## suggesting-sheet configuration" 1>&2
    display_param "filter exonic mutations" "$exonic_filtering"
    display_param "filter missense mutations" "$missense_filtering"
    display_param "filter deleterious mutations" "$deleterious_filtering"
    display_param "filter rare mutations" "$rare_filtering"
fi

# ****************************************  executing  ****************************************
sa_file="$out_dir/$running_key".sa
mt_vcf_gt_file="$out_dir/$running_key".mt.vgt
af_file="$out_dir/$running_key".af
gf_file="$out_dir/$running_key".gf
pf_file="$out_dir/$running_key".pf


# ****************************************  generating data  ****************************************
function submit_cmd {
    cmd=$1
    job_name=$2
    project_code=$3
    n_cores=$4
    
    sbatch_cmd="sbatch"
    sbatch_cmd+=" -A $project_code"
    sbatch_cmd+=" -p core"
    sbatch_cmd+=" -n $n_cores"
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

function exec_cmd {
    cmd=$1
    job_key=$2
    if [ ! -z "$project_code" ]
    then
        n_cores=1
        running_job_id[$running_job_count]=`submit_cmd "$cmd" "$job_key" "$project_code" "$n_cores"`
        running_job_count=$((running_job_count+1))
    else
        echo "## executing: $cmd " 1>&2
        eval "$cmd"
    fi
}

if [ "$cached_enable" == "Off" ]
then
    echo "## freshly generating data " 1>&2
    ## generating summarize annovar database file
    job_key="$running_key"_sa
    cmd="$SCRIPT_GEN_SA -A $annovar_root_dir -k $running_key -t $tabix_file -o $sa_file -w $working_dir"
    if [ ! -z "$col_names" ]; then
        cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
        cmd+=" -R $vcf_region"
    fi
    exec_cmd "$cmd" "$job_key"
    
    ## generating mutated vcf gt data
    job_key="$running_key"_mt_vcf_gt
    cmd="$SCRIPT_GEN_VCF_GT -k $running_key -t $tabix_file -o $mt_vcf_gt_file -M"
    if [ ! -z "$col_names" ]; then
        cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
        cmd+=" -R $vcf_region"
    fi
    exec_cmd "$cmd" "$job_key"
    
    ## generating mutated vcf gt data
    job_key="$running_key"_cal_mut_stat
    cmd="$SCRIPT_CAL_MUTATIONS_STAT -k $running_key -t $tabix_file -o $out_dir -w $working_dir"
    if [ ! -z "$col_names" ]; then
        cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
        cmd+=" -R $vcf_region"
    fi
    exec_cmd "$cmd" "$job_key"
    
    ## checking if all the data are completely generated
    if [ ! -z "$project_code" ]
    then
        PENDING_STATUS="PENDING"
        COMPLETED_STATUS="COMPLETED"
        FAILED_STATUS="FAILED"
        while true;
        do
            all_jobs_done="TRUE"
            for (( i=0; i<$running_job_count; i++ ))
            do
        	job_no=${running_job_id[$i]}
        	job_status=`get_job_status $job_no`
            	if [ "$job_status" != "$COMPLETED_STATUS" ]
            	then
            	   all_jobs_done="FALSE" 
            	fi
            done
            if [ "$all_jobs_done" = "TRUE" ]
            then
        	break
            fi
            sleep 10
        done
    fi
else
    echo "## using cached " 1>&2
fi

# ****************************************  defining functions for main codes  ****************************************
function rearrange_summarize_annovar {
    local sa_in=$1
    COL_SA_KEY=1
    COL_SA_FUNC=2
    COL_SA_GENE=3
    COL_SA_EXONICFUNC=4
    COL_SA_AACHANGE=5
    COL_SA_1000G=9
    COL_SA_DBSNP=10
    COL_SA_PHYLOP=12
    COL_SA_PHYLOPPRED=13
    COL_SA_SIFT=14
    COL_SA_SIFTPRED=15
    COL_SA_POLYPHEN=16
    COL_SA_POLYPHENPRED=17
    COL_SA_LRT=18
    COL_SA_LRTPRED=19
    COL_SA_MT=20
    COL_SA_MTPRED=21
    COL_SA_CHR=23
    COL_SA_STARTPOS=24
    COL_SA_ENDPOS=25
    COL_SA_REF=26
    COL_SA_OBS=27
    
    tmp_rearrange="$working_dir/$running_key"_tmp_rearrange
    rearrange_header_cmd="head -1 $sa_in | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tPhyloP\tPhyloP prediction\tSIFT\tSIFT prediction\tPolyPhen2\tPolyPhen2 prediction\tLRT\tLRT prediction\tMT\tMT prediction\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS}'"
    echo "##" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> rearrange header <<<<<<<<<<<<<<<<<<<<" 1>&2
    echo "## executing: $rearrange_header_cmd" 1>&2
    eval $rearrange_header_cmd
    
    rearrange_content_cmd="grep -v \"Func\" $sa_in | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS, \$$COL_SA_PHYLOP, \$$COL_SA_PHYLOPPRED, \$$COL_SA_SIFT, \$$COL_SA_SIFTPRED, \$$COL_SA_POLYPHEN, \$$COL_SA_POLYPHENPRED, \$$COL_SA_LRT, \$$COL_SA_LRTPRED, \$$COL_SA_MT, \$$COL_SA_MTPRED}' | sort -t$'\t' -k1,1"
    echo "## executing: $rearrange_content_cmd" 1>&2
    eval $rearrange_content_cmd
}

function insert_add_on_data {
    local main_data=$1
    local addon_data=$2
    local inserting_col=$3
    local inserting_header=$4

    local n_main_col=$( grep "^#" $main_data | head -1 | awk -F'\t' '{ printf NF }' )
    local n_addon_col=$( grep "^#" $addon_data | head -1 | awk -F'\t' '{ printf NF }' )
    if [ -z "$inserting_col" ]
    then
        inserting_col=$(( n_main_col+1 ))
    fi
    if [ -z "$inserting_header" ]
    then
        IFS=$'\t' read -ra header_addon_data <<< "$( grep "^#" $addon_data | head -1 )"
        echo "" 1>&2
        inserting_header="${header_addon_data[1]}"
        for (( i=2; i<$((${#header_addon_data[@]})); i++ ))
        do
            inserting_header+="\t${header_addon_data[$i]}"
        done
    fi
    echo "## inserting $(basename $addon_data) at column $inserting_col" 1>&2
    echo "## main data: $main_data" 1>&2
    echo "## addon data: $addon_data" 1>&2
    echo "## inserting column: $inserting_col" 1>&2
#    echo -e "## inserting header: $inserting_header" 1>&2
    echo "## number of addon columns: $n_addon_col" 1>&2

    awk_printf_format_first_clause="%s"
    awk_printf_param_content_clause="\$1"
    join_format_first_clause="1.1"
    for (( i=2; i<$inserting_col; i++ ))
    do
        awk_printf_format_first_clause+="\t%s"
        awk_printf_param_content_clause+=", \$$i"
        join_format_first_clause+=",1.$i"
    done
    echo "## awk printf format first clause: $awk_printf_format_first_clause" 1>&2
    echo "## awk printf param content clause: $awk_printf_param_content_clause" 1>&2
    echo "## awk join format first clause: $join_format_first_clause" 1>&2
    if [ "$inserting_col" -le "$n_main_col" ]
    then
        awk_printf_format_second_clause="%s"
        awk_printf_param_content_clause+=", \$$i"
        join_format_second_clause="1.$inserting_col"
        for (( i=$(( inserting_col+1 )); i<=$n_main_col; i++ ))
        do
            awk_printf_format_second_clause+="\t%s"
            awk_printf_param_content_clause+=", \$$i"
            join_format_second_clause+=",1.$i"
        done
    else
        awk_printf_format_second_clause=""
        awk_printf_param_content_clause+=""
        join_format_second_clause=""
    fi
    echo "## awk printf format second clause: $awk_printf_format_second_clause" 1>&2
    echo "## awk printf param content clause: $awk_printf_param_content_clause" 1>&2
    echo "## awk join format second clause: $join_format_second_clause" 1>&2

    awk_printf_format_clause="$awk_printf_format_first_clause\t$inserting_header"
    if [ ! -z $awk_printf_format_second_clause ]
    then
        awk_printf_format_clause+="\t$awk_printf_format_second_clause"
    fi
#    echo "" 1>&2
#    echo "## awk printf format clause: $awk_printf_format_clause" 1>&2

    inserting_header_cmd="head -1 $main_data | awk -F'\t' '{ printf \"$awk_printf_format_clause\n\", $awk_printf_param_content_clause }'"
    echo "## executing: $inserting_header_cmd" 1>&2
    eval $inserting_header_cmd

    join_format_clause="$join_format_first_clause"
    for (( i=2; i<=$n_addon_col; i++ ))
    do
        join_format_clause+=",2.$i"
    done
    if [ ! -z $join_format_second_clause ]
    then
        join_format_clause+=",$join_format_second_clause"
    fi
#    echo "" 1>&2
#    echo "## join format clause: $join_format_clause" 1>&2
    inserting_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $join_format_clause <( grep -v \"^#\" $main_data ) <( sort -k1,1 $addon_data ) | sort -t$'\t' -k1,1"
    echo "## executing: $inserting_content_cmd" 1>&2
    eval $inserting_content_cmd

}

function remove_oth_from_report {
    raw_report=$1
    sed "s/\toth/\t./Ig" $raw_report
}

function generate_xls_report {
    additional_params=$1

#    # set raw input sheets together with their names
#    sheets_param_value="all,$tmp_join"
#    if [ "$suggesting_sheet" = "True" ]; then
#        sheets_param_value+=":suggested,$tmp_suggesting_sheet"
#    fi
#    python_cmd+=" -s $sheets_param_value"
#    python_cmd+=" -o $summary_xls_out"
#    python_cmd+=" -c $n_col_main,$(( n_col_main+n_col_mt_vcf_gt ))"

    local python_cmd="python $CSVS2XLS"
    # set indexes of column to be hidden
    python_cmd+=" -C \"0,10,13,14,15,16,17,18,19,20,21,22\""
    # set frequencies ratio to be highlighted
    python_cmd+=" -F 5:$oaf_ratio,6:$maf_ratio"
    #python_cmd+=" -F $((COL_OAF_INSERTING-1)):$oaf_ratio,$COL_OAF_INSERTING:$maf_ratio"
    #if [ ! -z "$vcf_region" ]; then
    #    marked_key_range=$( vcf_region_to_key_range "$vcf_region" )
    #    python_cmd+=" -R \"$marked_key_range\""
    #fi
    python_cmd+=" $additional_params"
    echo "##" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> convert csvs to xls <<<<<<<<<<<<<<<<<<<<" 1>&2
    echo "## executing: $python_cmd" 1>&2
    eval $python_cmd
}

# ****************************************  main code  ****************************************
# -------------------- generating master data --------------------
# rearrange summarize annovar
tmp_rearranged_sa="$working_dir/$running_key"_tmp_rearranged_sa
rearrange_summarize_annovar $sa_file > $tmp_rearranged_sa
# insert OAF
tmp_oaf="$working_dir/$running_key"_tmp_oaf
COL_OAF_INSERTING=6
insert_add_on_data $tmp_rearranged_sa $pf_file $COL_OAF_INSERTING "OAF" > $tmp_oaf

tmp_master_data="$working_dir/$running_key"_tmp_master_data
cp $tmp_oaf $tmp_master_data


# -------------------- generating summary report --------------------
echo "##" 1>&2
echo "## >>>>>>>>>>>>>>>>>>>> generating mutations summary report <<<<<<<<<<<<<<<<<<<<" 1>&2
# insert zygosities
tmp_raw_zygo="$working_dir/$running_key"_tmp_raw_zygo
tmp_zygo="$working_dir/$running_key"_tmp_zygo
insert_add_on_data "$tmp_master_data" "$mt_vcf_gt_file" "" "" > "$tmp_raw_zygo"
remove_oth_from_report "$tmp_raw_zygo" > "$tmp_zygo"

# generate muations summary xls file
summary_report_params=" -o $summary_xls_out"
summary_report_params+=" -s all,$tmp_zygo"
generate_xls_report "$summary_report_params"

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
