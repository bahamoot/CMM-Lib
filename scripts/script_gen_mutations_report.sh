#!/bin/bash

script_name=$(basename $0)
params="$@"

#define default values
TOTAL_RUN_TIME_DEFAULT="7-00:00:00"
OAF_RATIO_DEFAULT="0.1"
MAF_RATIO_DEFAULT="0.2"
CACHED_ENABLE_DEFAULT="Off"
DEVELOPER_MODE_DEFAULT="Off"

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

# parse option
while getopts ":p:T:k:t:R:c:W:F:f:emdrCDA:o:l:" OPTION; do
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
    D)
      dev_mode="On"
      ;;
    A)
      annovar_root_dir="$OPTARG"
      ;;
    o)
      project_dir="$OPTARG"
      ;;
    l)
      slurm_log_dir="$OPTARG"
      ;;
    *)
      die "unrecognized option (-$OPTION) from executing: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specify a unique key for this run (-k)"
[ ! -z $tabix_file ] || die "Please specify tabix file (-t)"
[ ! -z $annovar_root_dir ] || die "Please specify a annovar root directory (-A)"
[ ! -z $project_dir ] || die "Please specify an output directory (-o)"
[ ! -z $slurm_log_dir ] || die "Please specify a log directory (-l)"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"
[ -d $annovar_root_dir ] || die "$annovar_root_dir is not a valid directory"
[ -d $project_dir ] || die "$project_dir is not a valid directory"
[ -d $slurm_log_dir ] || die "$slurm_log_dir is not a valid directory"

##setting default values:
: ${total_run_time=$TOTAL_RUN_TIME_DEFAULT}
: ${oaf_ratio=$OAF_RATIO_DEFAULT}
: ${maf_ratio=$MAF_RATIO_DEFAULT}
: ${cached_enable=$CACHED_ENABLE_DEFAULT}
: ${dev_mode=$DEVELOPER_MODE_DEFAULT}

project_reports_dir="$project_dir/reports"
if [ ! -d "$project_reports_dir" ]; then
    mkdir $project_reports_dir
fi
project_working_dir="$project_dir/tmp"
if [ ! -d "$project_working_dir" ]; then
    mkdir $project_working_dir
fi
project_data_out_dir="$project_dir/data_out"
if [ ! -d "$project_data_out_dir" ]; then
    mkdir $project_data_out_dir
fi
project_log_dir="$project_dir/log"
if [ ! -d "$project_log_dir" ]; then
    mkdir $project_log_dir
fi
summary_xls_out="$project_reports_dir/$running_key"_summary.xlsx

running_time=$(date +"%Y%m%d%H%M%S")
running_log_file="$project_log_dir/$running_key"_"$running_time".log
#if [ ! -d "$working_dir" ]; then
#    mkdir $working_dir
#fi

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

# -------------------- define basic functions --------------------
function write_log {
    echo "$1" >> $running_log_file
}

function msg_to_out {
    message="$1"
    echo -e "$message" 1>&2
    write_log "$message"
}

function info_msg {
    message="$1"

    INFO_MSG_FORMAT="## [INFO] %s"
    formated_msg=`printf "$INFO_MSG_FORMAT" "$message"`
    msg_to_out "$formated_msg"
}

function debug_msg {
    message="$1"

    if [ "$dev_mode" == "On" ]
    then
        DEBUG_MSG_FORMAT="## [DEBUG] %s"
        formated_msg=`printf "$DEBUG_MSG_FORMAT" "$message"`
        msg_to_out "$formated_msg"
    fi
}

function display_param {
    PARAM_PRINT_FORMAT="  %-40s%s"
    param_name=$1
    param_val=$2

    msg=`printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val"`
    info_msg "$msg"
}

# -------------------- parsing families information --------------------
if [ ! -z "$families_infos" ]
then
    IFS=',' read -ra families_infos_array <<< "$families_infos"
    number_of_families=$((${#families_infos_array[@]}))
fi
## ****************************************  display configuration  ****************************************
## display required configuration
info_msg
info_msg "************************************************** S T A R T <$script_name> **************************************************"
info_msg
info_msg "parameters"
info_msg "  $params"
info_msg
info_msg "description"
info_msg "  A script to generate mutations reports"
info_msg
info_msg "overall configuration"
if [ ! -z "$project_code" ]
then
    display_param "project code (-p)" "$project_code"
    display_param "total run time (-T)" "$total_run_time"
fi
display_param "running key (-k)" "$running_key"
display_param "tabix file (-t)" "$tabix_file"
display_param "ANNOVAR root directory (-A)" "$annovar_root_dir"
display_param "project output directory (-o)" "$project_dir"
display_param "  reports directory" "$project_reports_dir"
display_param "  working directory" "$project_working_dir"
display_param "  data output directory" "$project_data_out_dir"
display_param "  log directory" "$project_log_dir"
display_param "slurm log directory (-l)" "$slurm_log_dir"
display_param "running-time key" "$running_time"

## display optional configuration
info_msg
info_msg "optional configuration"
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
display_param "use cache data" "$cached_enable"
if [ "$dev_mode" = "On" ]
then
    display_param "developer mode" "enabled"
fi


## display families informations
if [ ! -z "$families_infos" ]
then
    info_msg
    info_msg "families information (-f)"
    display_param "number of families" "$number_of_families"
    for (( i=0; i<$(($number_of_families)); i++ ))
    do
        display_param "family #$(( i+1 ))" "${families_infos_array[$i]}"
    done
fi

## display suggesting-sheet configuration
if [ "$suggesting_sheet" = "True" ]; then
    info_msg
    info_msg "suggesting-sheet configuration"
    display_param "filter exonic mutations" "$exonic_filtering"
    display_param "filter missense mutations" "$missense_filtering"
    display_param "filter deleterious mutations" "$deleterious_filtering"
    display_param "filter rare mutations" "$rare_filtering"
fi

# ****************************************  executing  ****************************************
sa_file="$project_data_out_dir/$running_key".sa
mt_vcf_gt_file="$project_data_out_dir/$running_key".mt.vgt
af_file="$project_data_out_dir/$running_key".af
gf_file="$project_data_out_dir/$running_key".gf
pf_file="$project_data_out_dir/$running_key".pf


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
    sbatch_cmd+=" -o $slurm_log_dir/$job_name.$running_time.log.out"
    sbatch_cmd+=" $cmd"
    debug_msg
    debug_msg
    debug_msg "executing: $sbatch_cmd "
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
        debug_msg "executing: $cmd"
        eval "$cmd"
    fi
}

if [ "$cached_enable" == "Off" ]
then
    ## generating summarize annovar database file
    job_key="$running_key"_sa
    cmd="$SCRIPT_GEN_SA -A $annovar_root_dir -k $running_key -t $tabix_file -o $sa_file -w $project_working_dir"
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
    cmd="$SCRIPT_CAL_MUTATIONS_STAT -k $running_key -t $tabix_file -o $project_data_out_dir -w $project_working_dir"
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
fi

# ****************************************  defining functions for main codes  ****************************************
function get_common_zygosities {
    zygosities_file=$1
    zygo_col_idxs=$2

    IFS=',' read -ra zygo_col_idx_array <<< "$zygo_col_idxs"
    zygo_filter_cmd=" awk -F'\t' '{ if ((\$${zygo_col_idx_array[0]} != \".\") && (\$${zygo_col_idx_array[0]} != \"oth\")"
    columns_clause="\$1, \$${zygo_col_idx_array[0]}"
    printf_clause="%s\t%s"
    for (( array_idx=1; array_idx<$((${#zygo_col_idx_array[@]})); array_idx++ ))
    do
        zygo_col_idx=${zygo_col_idx_array[$array_idx]}
	    zygo_filter_cmd+=" && (\$$zygo_col_idx != \".\") && (\$$zygo_col_idx != \"oth\")"
	    columns_clause+=", \$$zygo_col_idx"
	    printf_clause+="\t%s"
    done
    zygo_filter_cmd+=") printf \"$printf_clause\n\", $columns_clause }' $zygosities_file"
    debug_msg "executing: $zygo_filter_cmd"
    eval $zygo_filter_cmd
}

function get_member_col_idx {
    head -1 $1 | grep -i $2 | awk -va="$2" 'BEGIN{}
    END{}
    {
        for(i=1;i<=NF;i++){
            IGNORECASE = 1
            if ( tolower($i) == tolower(a))
                {print i }
        }
    }'
}

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
    
    tmp_rearrange="$project_working_dir/$running_key"_tmp_rearrange
    rearrange_header_cmd="head -1 $sa_in | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tPhyloP\tPhyloP prediction\tSIFT\tSIFT prediction\tPolyPhen2\tPolyPhen2 prediction\tLRT\tLRT prediction\tMT\tMT prediction\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS}'"
    info_msg
    info_msg ">>>>>>>>>>>>>>>>>>>> rearrange header <<<<<<<<<<<<<<<<<<<<"
    debug_msg "executing: $rearrange_header_cmd"
    eval $rearrange_header_cmd
    
    rearrange_content_cmd="grep -v \"Func\" $sa_in | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS, \$$COL_SA_PHYLOP, \$$COL_SA_PHYLOPPRED, \$$COL_SA_SIFT, \$$COL_SA_SIFTPRED, \$$COL_SA_POLYPHEN, \$$COL_SA_POLYPHENPRED, \$$COL_SA_LRT, \$$COL_SA_LRTPRED, \$$COL_SA_MT, \$$COL_SA_MTPRED}' | sort -t$'\t' -k1,1"
    debug_msg "executing: $rearrange_content_cmd"
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
        inserting_header="${header_addon_data[1]}"
        for (( i=2; i<$((${#header_addon_data[@]})); i++ ))
        do
            inserting_header+="\t${header_addon_data[$i]}"
        done
    fi
    info_msg "inserting '$inserting_header' ($(( n_addon_col-1 )) column(s)) from $addon_data to $main_data at column $inserting_col"

    awk_printf_format_first_clause="%s"
    awk_printf_param_content_clause="\$1"
    join_format_first_clause="1.1"
    for (( i=2; i<$inserting_col; i++ ))
    do
        awk_printf_format_first_clause+="\t%s"
        awk_printf_param_content_clause+=", \$$i"
        join_format_first_clause+=",1.$i"
    done
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

    awk_printf_format_clause="$awk_printf_format_first_clause\t$inserting_header"
    if [ ! -z $awk_printf_format_second_clause ]
    then
        awk_printf_format_clause+="\t$awk_printf_format_second_clause"
    fi

    inserting_header_cmd="head -1 $main_data | awk -F'\t' '{ printf \"$awk_printf_format_clause\n\", $awk_printf_param_content_clause }'"
    debug_msg "executing: $inserting_header_cmd"
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
    inserting_content_cmd="join -t $'\t' -1 1 -2 1 -o $join_format_clause <( grep -v \"^#\" $main_data ) <( sort -k1,1 $addon_data ) | sort -t$'\t' -k1,1"
    debug_msg "executing: $inserting_content_cmd"
    eval $inserting_content_cmd

}

function remove_oth_from_report {
    raw_report=$1
    sed "s/\toth/\t./Ig" $raw_report
}

function generate_xls_report {
    additional_params=$1

    local python_cmd="python $CSVS2XLS"
    # set indexes of column to be hidden
    # set frequencies ratio to be highlighted
    python_cmd+=" -F 5:$oaf_ratio,6:$maf_ratio"
    if [ "$dev_mode" = "On" ]
    then
        python_cmd+=" -D"
    fi
    python_cmd+=" -l $running_log_file"
    #python_cmd+=" -F $((COL_OAF_INSERTING-1)):$oaf_ratio,$COL_OAF_INSERTING:$maf_ratio"
    #if [ ! -z "$vcf_region" ]; then
    #    marked_key_range=$( vcf_region_to_key_range "$vcf_region" )
    #    python_cmd+=" -R \"$marked_key_range\""
    #fi
    python_cmd+=" $additional_params"
    info_msg
    info_msg ">>>>>>>>>>>>>>>>>>>> convert csvs to xls <<<<<<<<<<<<<<<<<<<<"
    debug_msg "executing: $python_cmd"
    eval $python_cmd
}

# ****************************************  main code  ****************************************
# -------------------- generating master data --------------------
# rearrange summarize annovar
tmp_rearranged_sa="$project_working_dir/$running_key"_tmp_rearranged_sa
rearrange_summarize_annovar $sa_file > $tmp_rearranged_sa
# insert OAF
tmp_oaf="$project_working_dir/$running_key"_tmp_oaf
COL_OAF_INSERTING=6
insert_add_on_data $tmp_rearranged_sa $pf_file $COL_OAF_INSERTING "OAF" > $tmp_oaf

tmp_master_data="$project_working_dir/$running_key"_tmp_master_data
cp $tmp_oaf $tmp_master_data
info_msg "done generating mutations master data for furture use in any mutations reports (master file: $tmp_master_data)"


# -------------------- generating summary report --------------------
info_msg
info_msg ">>>>>>>>>>>>>>>>>>>> generating mutations summary report <<<<<<<<<<<<<<<<<<<<"
# insert zygosities
summary_mutations_csv="$project_working_dir/$running_key"_summary.tab.csv
insert_add_on_data "$tmp_master_data" "$mt_vcf_gt_file" "" "" | remove_oth_from_report > "$summary_mutations_csv"
info_msg "done preparing raw csv sheet to summarize mutations (csv file: $summary_mutations_csv)"

# generate muations summary xls file
summary_report_params=" -o $summary_xls_out"
summary_report_params+=" -s all,$summary_mutations_csv"
#    python_cmd+=" -c $n_col_main,$(( n_col_main+n_col_mt_vcf_gt ))"
generate_xls_report "$summary_report_params"

# -------------------- generating families report --------------------
if [ ! -z "$families_infos" ]
then
    # for each family generate one report 
    for (( family_idx=0; family_idx<$(($number_of_families)); family_idx++ ))
    do
        IFS=':' read -ra family_info_array <<< "${families_infos_array[$family_idx]}"
        family_code=${family_info_array[0]}
        number_of_members=$((((${#family_info_array[@]}))-1))
        family_xls_out="$project_reports_dir/$running_key"_fam"$family_code".xlsx

        info_msg
        info_msg ">>>>>>>>>>>>>>>>>>>> generating family report for family $family_code ($number_of_members member(s)) <<<<<<<<<<<<<<<<<<<<"
        # for each member in the family generate a sheet for a report
        for (( member_idx=1; member_idx<=$number_of_members; member_idx++ ))
        do
            raw_member_code=${family_info_array[$member_idx]}
            displayed_member_code=${raw_member_code#*-}
            displayed_member_codes[$member_idx]=$displayed_member_code
            member_mutations_csv=$project_working_dir/"$running_key"_fam"$family_code"_"$displayed_member_code".tab.csv
            member_mutations_csvs[$member_idx]="$member_mutations_csv"
            tmp_zygosity=$project_working_dir/"$running_key"_fam"$family_code"_"$displayed_member_code"_tmp_zygosity
            # get member column index from the zygosities file
            member_zygo_col_idx=$( get_member_col_idx $mt_vcf_gt_file $raw_member_code )
            member_zygo_col_idxs[$member_idx]=$member_zygo_col_idx
            info_msg "generating zygosities of $displayed_member_code (idx $member_zygo_col_idx) using data from $mt_vcf_gt_file"
            get_common_zygosities "$mt_vcf_gt_file" "$member_zygo_col_idx" > "$tmp_zygosity"
            insert_add_on_data "$tmp_master_data" $tmp_zygosity "" "" | remove_oth_from_report > "$member_mutations_csv"
            info_msg "done preparing raw csv sheet for $displayed_member_code (csv file: $member_mutations_csv)"
        done
        if [ $number_of_members -gt 1 ]; then
            concated_member_zygo_col_idx=$(IFS=, ; echo "${member_zygo_col_idxs[*]}")
            shared_mutations_csv=$project_working_dir/"$running_key"_fam"$family_code"_shared.tab.csv
            tmp_zygosity=$project_working_dir/"$running_key"_fam"$family_code"_shared_tmp_zygosity
            info_msg "generating zygosities of all members (idx $concated_member_zygo_col_idx) using data from $mt_vcf_gt_file"
            get_common_zygosities "$mt_vcf_gt_file" "$concated_member_zygo_col_idx" > "$tmp_zygosity"
            insert_add_on_data "$tmp_master_data" $tmp_zygosity "" "" | remove_oth_from_report > "$shared_mutations_csv"
            info_msg "done preparing raw csv sheet for all members (csv file: $shared_mutations_csv)"
        fi
        ## generate family xls file
        family_report_params=" -o $family_xls_out"
        family_report_params+=" -s ${displayed_member_codes[1]},${member_mutations_csvs[1]}"
        for (( member_idx=2; member_idx<=$number_of_members; member_idx++ ))
        do
            family_report_params+=":${displayed_member_codes[$member_idx]},${member_mutations_csvs[$member_idx]}"
        done
        if [ $number_of_members -gt 1 ]; then
            family_report_params+=":shared,$shared_mutations_csv"
        fi
        generate_xls_report "$family_report_params"
    done
fi
info_msg ""
info_msg "************************************************** F I N I S H <$script_name> **************************************************"
