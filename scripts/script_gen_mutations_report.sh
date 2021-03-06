#!/bin/bash
source $CMM_LIB_DIR/cmm_functions.sh

script_name=$(basename $0)
params="$@"

#define default values
TOTAL_RUN_TIME_DEFAULT="7-00:00:00"
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
-P {patient list}   specify vcf columns to exported (default:all)
-S {config}         specify statistical option to be shown up in the report. The format of option is [stat1_name1,[stat1_file_name],stat1_col_name1[#stat1_col_name1_pos][-stat1_col_name2[..]][:stat2_name,[stat2_file_name][..]][..]] (default:None)
-F {float}          specify frequency ratios for rare mutations (ex: OAF:0.1,MAF:0.2) (default:None)
-Z {zygo codes}     specify custom zygosity codes (ex: WT:.,NA:na) (default: (HOM:"hom", HET:"het", WT:"wt", NA:".", OTH:"oth")
-f {family infos}   specify families information in format [family1_code|family1_patient1_code[|family1_patient2_code[..]][,family2_code|family2_patient1_code[..]][..]]
-E {attributes}     specify extra attributes (ex: share,rare) (default: None)
-K {cell colors}    specify cell colors information (default: None)
-C {color info}     specify color information of region of interest (default: None)
-M {config}         specify header text to be modified, ex 'ALL_PF:OAF' will change one of the header column from 'ALL_PF' to 'OAF' (default: None)
-e {config}         specify exclusion criteria (I: intergenic and intronic, S: synonymous mutation, C: common mutation)(default: None)
-c                  use cached data instead of fresh generated one (default: $CACHED_ENABLE_DEFAULT)
-D                  indicated to enable developer mode (default: DEVELOPER_MODE_DEFAULT)
-A {directory}      specify ANNOVAR root directory (required)
-o {directory}      specify project output directory (required)
-l {directory}      specify slurm log directory (required)
EOF
)

# parse option
while getopts ":p:T:k:t:R:P:S:F:Z:f:E:K:C:M:e:cDA:o:l:" OPTION; do
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
    P)
      col_names="$OPTARG"
      ;;
    S)
      stat_config="$OPTARG"
      ;;
    F)
      frequency_ratios="$OPTARG"
      ;;
    Z)
      custom_zygo_codes="$OPTARG"
      ;;
    f)
      families_infos="$OPTARG"
      ;;
    E)
      extra_attributes="$OPTARG"
      ;;
    K)
      cell_colors="$OPTARG"
      ;;
    C)
      color_regions_info="$OPTARG"
      ;;
    M)
      modify_header_config="$OPTARG"
      ;;
    e)
      exclusion_criteria="$OPTARG"
      ;;
    c)
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

time_stamp=$( date )
running_time=$(date +"%Y%m%d%H%M%S")
running_log_file="$project_log_dir/$running_key"_"$running_time".log

# -------------------- define basic functions --------------------

## -------------------- parsing exclusion creterias --------------------
#if [ ! -z "$exclusion_criteria_param" ]
#then
#    IFS=',' read -ra exclusion_criteria <<< "$exclusion_cretirias_param"
#fi

# -------------------- parsing families information --------------------
if [ ! -z "$families_infos" ]
then
    IFS=',' read -ra families_infos_array <<< "$families_infos"
    number_of_families=$((${#families_infos_array[@]}))
fi
# -------------------- parsing exclusion creteria --------------------
if [ ! -z "$stat_config" ]
then
    IFS=':' read -ra stat_config_array <<< "$stat_config"
fi

cd $CMM_LIB_DIR
revision_no=`git rev-list HEAD | wc -l`
revision_code=`git rev-parse HEAD`
cd - > /dev/null

## ****************************************  display configuration  ****************************************
## display required configuration
new_section_txt "S T A R T <$script_name>"
info_msg
info_msg "description"
info_msg "  A script to generate mutations reports"
info_msg
info_msg "version and script configuration"
display_param "revision no" "$revision_no"
display_param "revision code" "$revision_code"
display_param "script path" "$CMM_LIB_DIR"
display_param "parameters" "$params"
display_param "time stamp" "$time_stamp"
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

if [ ! -z "$stat_config" ]
then
    ## display statistical configuration
    info_msg
    info_msg "statistal configuration"
    for (( stat_idx=0; stat_idx<$((${#stat_config_array[@]})); stat_idx++ ))
    do
        display_param "  stat configuration #$(( stat_idx+1 )) " "${stat_config_array[$stat_idx]}"
    done
fi

## display optional configuration
info_msg
info_msg "optional configuration"
if [ ! -z "$vcf_region" ]; then
    display_param "vcf region (-R)" "$vcf_region"
else
    display_param "vcf region" "ALL"
fi
if [ ! -z "$col_names" ]; then
    display_param "column names (-P)" "$col_names"
else
    display_param "column names (-P)" "ALL"
fi
if [ ! -z "$frequency_ratios" ]
then
    display_param "frequency ratios (-F)" ""
    IFS=',' read -ra frequency_ratio <<< "$frequency_ratios"
    for (( ratio_idx=0; ratio_idx<$((${#frequency_ratio[@]})); ratio_idx++ ))
    do
        IFS=':' read -ra ratio_split <<< "${frequency_ratio[$ratio_idx]}"
        display_param "  ${ratio_split[0]}" "${ratio_split[1]}"
    done
fi
if [ ! -z "$extra_attributes" ]
then
    display_param "extras attributes (-E)" ""
    IFS=',' read -ra attribs <<< "$extra_attributes"
    for (( attrib_idx=0; attrib_idx<$((${#attribs[@]})); attrib_idx++ ))
    do
        display_param "  extra attributes #$(( attrib_idx+1 ))" "${attribs[$attrib_idx]}"
    done
fi
if [ ! -z "$cell_colors" ]
then
    display_param "cell colors (-K)" "$cell_colors"
fi
if [ ! -z "$color_regions_info" ]
then
    display_param "color regions information (-C)" "$color_regions_info"
fi
if [ ! -z "$modify_header_config" ]
then
    display_param "header modification config (-M)" "$modify_header_config"
fi
display_param "exclusion criteria (-e)" "$exclusion_criteria"
#if [ ! -z "$exclusion_criteria" ]
#then
#    for (( exc_idx=0; exc_idx<$((${#exclusion_criteria[@]})); exc_idx++ ))
#    do
#        display_param "header modification config (-M)" "$modify_header_config"
#    done
#fi
display_param "use cache data (-c)" "$cached_enable"
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
    cmd="$SCRIPT_GEN_SA -A $annovar_root_dir -k $running_key -t $tabix_file -o $sa_file -w $project_working_dir -l $running_log_file"
    if [ ! -z "$col_names" ]; then
        cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
        cmd+=" -R $vcf_region"
    fi
    exec_cmd "$cmd" "$job_key"
    
    ## generating mutated vcf gt data
    job_key="$running_key"_mt_vcf_gt
    cmd="$SCRIPT_GEN_VCF_GT -k $running_key -t $tabix_file -o $mt_vcf_gt_file -M -w $project_working_dir -l $running_log_file"
    if [ ! -z "$col_names" ]; then
        cmd+=" -c $col_names"
    fi
    if [ ! -z "$vcf_region" ]; then
        cmd+=" -R $vcf_region"
    fi
    exec_cmd "$cmd" "$job_key"
    
    if [ ! -z "$stat_config" ]
    then
        ## generating mutation statistics
        for (( stat_idx=0; stat_idx<$((${#stat_config_array[@]})); stat_idx++ ))
        do
            IFS=',' read -ra stat_info_array <<< "${stat_config_array[$stat_idx]}"
            stat_name=${stat_info_array[0]}
            stat_src_file=${stat_info_array[1]}
            if [ ${stat_src_file: -3} == ".gz" ]
            then
                patients_list=${stat_info_array[2]}
                job_key="$running_key"_cal_stat_"$stat_name"
                stat_running_key="$running_key"_"$stat_name"
                cmd="$SCRIPT_CAL_MUTATIONS_STAT -k $stat_running_key -t $stat_src_file -o $project_data_out_dir -w $project_working_dir -l $running_log_file"
                if [ ! -z "$patients_list" ]; then
                    cmd+=" -c $patients_list"
                fi
                if [ ! -z "$vcf_region" ]; then
                    cmd+=" -R $vcf_region"
                fi
                exec_cmd "$cmd" "$job_key"
            fi
        done
    fi
    
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

function get_col_idx {
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
    COL_SA_ESP6500=8
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
    rearrange_header_cmd="head -1 $sa_in | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tPhyloP\tPhyloP prediction\tSIFT\tSIFT prediction\tPolyPhen2\tPolyPhen2 prediction\tLRT\tLRT prediction\tMT\tMT prediction\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_ESP6500, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS}'"
    new_sub_section_txt "rearrange header"
    debug_msg "executing: $rearrange_header_cmd"
    eval $rearrange_header_cmd
    
    exclusion_clause=""
    IFS=',' read -ra exc_array <<< "$exclusion_criteria"
    for (( exc_idx=0; exc_idx<$((${#exc_array[@]})); exc_idx++ ))
    do
        if [ "${exc_array[$exc_idx]}" == "C" ]
        then
            exclusion_clause+=" | awk -F'\t' '{ if ((\$$COL_SA_1000G < 0.2) || (\$$COL_SA_1000G > 0.8)) print \$0 }' "
        fi
        if [ "${exc_array[$exc_idx]}" == "I" ]
        then
            exclusion_clause+=" | grep -v \"intergenic\" | grep -v \"intronic\" "
        fi
        if [ "${exc_array[$exc_idx]}" == "S" ]
        then
            exclusion_clause+=" | grep -vP \"\\tsynonymous\" "
        fi
    done

    rearrange_content_cmd="grep -v \"Func\" $sa_in $exclusion_clause | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_ESP6500, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS, \$$COL_SA_PHYLOP, \$$COL_SA_PHYLOPPRED, \$$COL_SA_SIFT, \$$COL_SA_SIFTPRED, \$$COL_SA_POLYPHEN, \$$COL_SA_POLYPHENPRED, \$$COL_SA_LRT, \$$COL_SA_LRTPRED, \$$COL_SA_MT, \$$COL_SA_MTPRED}' | sort -t$'\t' -k1,1"
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
    inserting_content_cmd="join -t $'\t' -1 1 -2 1 -a 1 -o $join_format_clause <( grep -v \"^#\" $main_data ) <( sort -k1,1 $addon_data ) | sort -t$'\t' -k1,1"
    debug_msg "executing: $inserting_content_cmd"
    eval $inserting_content_cmd

}

function remove_oth_from_report {
    raw_report=$1
    sed "s/\toth/\t./Ig" $raw_report
}

function generate_xls_report {
    additional_params=$1

    local python_cmd="python $MUTS2XLS"
    python_cmd+=" -N $n_master_cols"
    # set frequencies ratio to be highlighted
    if [ ! -z "$frequency_ratios" ]
    then
        python_cmd+=" -F $frequency_ratios"
    fi
    if [ ! -z "$extra_attributes" ]
    then
        python_cmd+=" -E $extra_attributes"
    fi
    if [ "$dev_mode" = "On" ]
    then
        python_cmd+=" -D"
    fi
    if [ ! -z "$cell_colors" ]
    then
        python_cmd+=" -K $cell_colors"
    fi
    if [ ! -z "$color_regions_info" ]
    then
        python_cmd+=" -C $color_regions_info"
    fi
    if [ ! -z "$custom_zygo_codes" ]
    then
        python_cmd+=" -Z $custom_zygo_codes"
    fi
    python_cmd+=" -A log,$running_log_file"
    python_cmd+=" -l $running_log_file"
    python_cmd+=" $additional_params"
    new_sub_section_txt "convert csvs to xls"
    debug_msg "executing: $python_cmd"
    eval $python_cmd
}

# ****************************************  main code  ****************************************
# -------------------- generating master data --------------------
# rearrange summarize annovar
tmp_rearranged_sa="$project_working_dir/$running_key"_tmp_rearranged_sa
rearrange_summarize_annovar $sa_file > $tmp_rearranged_sa

tmp_master_data="$project_working_dir/$running_key"_tmp_master_data
cp $tmp_rearranged_sa $tmp_master_data

if [ ! -z "$stat_config" ]
then
    # insert mutation statistics
    tmp_stat_prefix="$project_working_dir/$running_key"_tmp_stat
    tmp_addon_prefix="$project_working_dir/$running_key"_tmp_addon
    for (( stat_idx=0; stat_idx<$((${#stat_config_array[@]})); stat_idx++ ))
    do
        IFS=',' read -ra stat_info_array <<< "${stat_config_array[$stat_idx]}"
        stat_name=${stat_info_array[0]}
        stat_src_file=${stat_info_array[1]}
        cols_list=${stat_info_array[3]}
        if [ ${stat_src_file: -3} == ".gz" ]
        then
            stat_file="$project_data_out_dir/$running_key"_"$stat_name".stat
        else
            stat_file="$stat_src_file"
        fi
        IFS='-' read -ra cols_array <<< "$cols_list"
        for (( col_idx=0; col_idx<$((${#cols_array[@]})); col_idx++ ))
        do
            IFS='#' read -ra col_tmp <<< "${cols_array[$col_idx]}"
            stat_col_name=${col_tmp[0]}
            inserted_col=${col_tmp[1]}
            inserted_col_name="$stat_name"_"$stat_col_name"
            stat_col_idx=`get_col_idx $stat_file $stat_col_name`
            stat_msg="inserting $inserted_col_name"
            if [ ! -z "$inserted_col" ]
            then
                stat_msg+=" at column $inserted_col"
            fi

            stat_msg+=" into $tmp_master_data using data from column $stat_col_name which is at $stat_col_idx column of $stat_file"
            info_msg "$stat_msg"
            tmp_addon_file="$tmp_addon_prefix"_"$inserted_col_name"
            preparing_addon_cmd="cut -f1,$stat_col_idx $stat_file > $tmp_addon_file"
            debug_msg
            debug_msg "executing: $preparing_addon_cmd"
            eval "$preparing_addon_cmd"
            tmp_stat_file="$tmp_stat_prefix"_"$inserted_col_name"
            insert_add_on_data "$tmp_master_data" "$tmp_addon_file" "$inserted_col" "$inserted_col_name" > "$tmp_stat_file"
            cp "$tmp_stat_file" "$tmp_master_data"
        done
    done
fi

if [ ! -z "$modify_header_config" ]
then
    tmp_header_txt=`head -1 "$tmp_master_data"`
    IFS=',' read -ra modify_header_array <<< "$modify_header_config"
    for (( modify_header_idx=0; modify_header_idx<$((${#modify_header_array[@]})); modify_header_idx++ ))
    do
        IFS=':' read -ra replacement_config <<< "${modify_header_array[$modify_header_idx]}"
        substring_to_replace=${replacement_config[0]}
        replacement=${replacement_config[1]}
        info_msg "replacing '$substring_to_replace' in header '$tmp_header_txt' with '$replacement'"
        new_header_txt=${tmp_header_txt//$substring_to_replace/$replacement}
        tmp_header_txt=$new_header_txt
    done
    tmp_modify_header="$project_working_dir/$running_key"_tmp_modify_header
    echo -e "$tmp_header_txt" > "$tmp_modify_header"
    grep -v "^#" "$tmp_master_data" >> "$tmp_modify_header"
    cp "$tmp_modify_header" "$tmp_master_data"
fi

n_master_cols=`head -1 $tmp_master_data | awk -F'\t' '{ print NF }'`
info_msg "done generating mutations master data for furture use in any mutations reports (master file: $tmp_master_data)"


# -------------------- generating summary report --------------------
new_sub_section_txt "generating mutations summary report"
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

        new_sub_section_txt "generating family report for family $family_code ($number_of_members member(s))"
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
            member_zygo_col_idx=$( get_col_idx $mt_vcf_gt_file $raw_member_code )
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
        family_report_params=" -o $family_xls_out -i S"
        family_sheet_params="${displayed_member_codes[1]},${member_mutations_csvs[1]}"
        for (( member_idx=2; member_idx<=$number_of_members; member_idx++ ))
        do
            family_sheet_params+=":${displayed_member_codes[$member_idx]},${member_mutations_csvs[$member_idx]}"
        done
        if [ $number_of_members -gt 1 ]; then
            family_report_params+=" -s shared,$shared_mutations_csv:$family_sheet_params"
        else
            family_report_params+=" -s $family_sheet_params"
        fi
        generate_xls_report "$family_report_params"
    done
fi
new_section_txt "F I N I S H <$script_name>"
