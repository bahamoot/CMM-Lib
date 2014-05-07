#!/bin/bash

script_name=$(basename $0)

#define default values
VCF_REGION_DEFAULT="All"
PLINK_PHENO_FILE_DEFAULT=""

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {project code}   specify UPPMAX project code (required)
-k {name}	    specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-R {region}	    specify PLINK region of interest (default:All)
-b {file}	    specify PLINK binary input file prefix (required)
-P {file}	    specify PLINK phenotype file (default:None)
-o {directory}	    specify output directory (required)
-w {directory}	    specify working directory (required)
-l {directory}	    specify slurm log directory (required)
EOF
)

#-O {file}          specify oaf input file name (required)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

# parse option
while getopts ":p:k:b:P:R:o:w:l:" OPTION; do
  case "$OPTION" in
    p)
      project_code="$OPTARG"
      ;;
    k)
      running_key="$OPTARG"
      ;;
    b)
      plink_bin_file_prefix="$OPTARG"
      ;;
    P)
      plink_pheno_file="$OPTARG"
      ;;
    R)
      plink_region="$OPTARG"
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
      die "unrecognized option from executing: $0 $@"
      ;;
  esac
done

[ ! -z $project_code ] || die "Please specify UPPMAX project code (-p)"
[ ! -z $running_key ] || die "Please specify a unique key for this run (-k)"
[ ! -z $plink_bin_file_prefix ] || die "Please specify PLINK binary input file prefix (-b)"
[ ! -z $out_dir ] || die "Plesae specify output directory"
[ ! -z $working_dir ] || die "Plesae specify working directory"
[ ! -z $log_dir ] || die "Plesae specify logging directory"
#[ -f $oaf_in_file ] || die "$oaf_in_file is not a valid file name"
#[ -f $sa_in_file ] || die "$sa_in_file is not a valid file name"
[ -f "$plink_bin_file_prefix".bed ] || die "$plink_bin_file_prefix is not a valid file prefix"
[ -f "$plink_bin_file_prefix".bim ] || die "$plink_bin_file_prefix is not a valid file prefix"
[ -f "$plink_bin_file_prefix".fam ] || die "$plink_bin_file_prefix is not a valid file prefix"
#[ -f "$plink_pheno_file" ] || die "$plink_pheno_file_prefix is not a valid file name"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$out_dir is not a valid directory"
[ -d $log_dir ] || die "$log_dir is not a valid directory"

#setting default values:
: ${plink_region=$VCF_REGION_DEFAULT}
: ${plink_pheno_file=$PLINK_PHENO_FILE_DEFAULT}

out_file_prefix="$out_dir/$running_key"_plink_out

#suggesting_sheet="False"
#if [ "$exonic_filtering" = "On" ]; then
#    suggesting_sheet="True"
#fi
#if [ "$missense_filtering" = "On" ]; then
#    suggesting_sheet="True"
#fi
#if [ "$deleterious_filtering" = "On" ]; then
#    suggesting_sheet="True"
#fi
#if [ "$rare_filtering" = "On" ]; then
#    suggesting_sheet="True"
#fi

running_time=$(date +"%Y%m%d%H%M%S")

function display_param {
    PARAM_PRINT_FORMAT="##   %-40s%s\n"
    param_name=$1
    param_val=$2

    printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val" 1>&2
}

#function plink_region_to_key_range {
#    KEY_FORMAT="%s|%012d,%s|%012d"
#    plink_region=$1
#
#    IFS=':' read -ra tmp_split_region <<< "$plink_region"
#    tmp_chrom=${tmp_split_region[0]}
#    number_re='^[0-9]+$'
#    if ! [[ $tmp_chrom =~ $number_re ]] ; then
#        chrom=$( printf "%s" $tmp_chrom )
#    else
#        chrom=$( printf "%02d" $tmp_chrom )
#    fi
#    IFS='-' read -ra tmp_split_pos <<< "${tmp_split_region[1]}"
#    printf "$KEY_FORMAT" "$chrom" "${tmp_split_pos[0]}" "$chrom" "${tmp_split_pos[1]}"
#}

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
display_param "running key (-k)" "$running_key"
display_param "PLINK input file prefix (-b)" "$plink_bin_file_prefix"
display_param "log directory (-l)" "$log_dir"
display_param "working directory (-w)" "$working_dir"
display_param "output file prefix" "$out_file_prefix"
display_param "running-time key" "$running_time"

## display optional configuration
echo "##" 1>&2
echo "## optional configuration" 1>&2
#display_param "genotyping information (-G)" "$gt_vcf_gt_annotation"
#display_param "mutation information (-M)" "$mt_vcf_gt_annotation"
if [ "$plink_region" = "All" ]
then
    display_param "PLINK region" "$plink_region"
else
    IFS=':' read -ra tmp_split_region <<< "$plink_region"
    plink_chrom="${tmp_split_region[0]}"
    number_re='^[0-9]+$'
    IFS='-' read -ra tmp_split_pos <<< "${tmp_split_region[1]}"
    plink_from_bp="${tmp_split_pos[0]}"
    plink_to_bp="${tmp_split_pos[1]}"

    echo "##   PLINK region (-R)" 1>&2
    display_param "  input region" "$plink_region"
    display_param "  chromosome" "$plink_chrom"
    display_param "  start position" "$plink_from_bp"
    display_param "  end position" "$plink_to_bp"
fi
if [ ! -z "$plink_pheno_file" ]
then
    display_param "PLINK phenotype file" "$plink_pheno_file"
fi

#if [ "$suggesting_sheet" = "True" ]; then
#    ## display suggesting-sheet configuration
#    echo "##" 1>&2
#    echo "## suggesting-sheet configuration" 1>&2
#    display_param "filter exonic mutations" "$exonic_filtering"
#    display_param "filter missense mutations" "$missense_filtering"
#    display_param "filter deleterious mutations" "$deleterious_filtering"
#    display_param "filter rare mutations" "$rare_filtering"
#fi

### display other configuration
#echo "##" 1>&2
#echo "## other configuration" 1>&2
#display_param "oaf ratio (-W)" "$oaf_ratio"
#display_param "maf ratio (-F)" "$maf_ratio"

## ****************************************  executing  ****************************************
plink_cmd="plink --noweb --bfile $plink_bin_file_prefix"
#plink_cmd="plink --noweb --bfile $plink_bin_file_prefix --out $out_dir/test_w_pheno --assoc --pheno $data_dir/my_pheno.txt"
if [ "$plink_region" != "All" ]
then
    plink_cmd+=" --chr $plink_chrom --from-bp $plink_from_bp --to-bp $plink_to_bp"
fi
if [ ! -z "$plink_pheno_file" ]
then
    plink_cmd+=" --pheno $plink_pheno_file"
fi
plink_cmd+=" --out $out_dir/test_w_pheno --assoc"
echo "## executing: $plink_cmd " 1>&2
eval "$plink_cmd"
## >>>>>> General functions
#function submit_cmd {
#    cmd=$1
#    job_name=$2
#
#    sbatch_cmd="sbatch"
#    sbatch_cmd+=" -A $project_code"
#    sbatch_cmd+=" -p core"
#    sbatch_cmd+=" -n 1 "
#    sbatch_cmd+=" -t 7-00:00:00"
#    sbatch_cmd+=" -J $job_name"
#    sbatch_cmd+=" -o $log_dir/$job_name.$running_time.log.out"
#    sbatch_cmd+=" $cmd"
#    echo "##" 1>&2
#    echo "##" 1>&2
#    echo "## executing: $sbatch_cmd " 1>&2
#    eval "$sbatch_cmd" 1>&2
#    queue_txt=( $( squeue --name="$job_name" | grep -v "PARTITION" | tail -1 ) )
#    echo ${queue_txt[0]}
#}
#
#function get_job_status {
#    job_id=$1
#
#    status_txt=( $( sacct -j "$job_id" | grep "$job_id" | head -1 ))
#    echo ${status_txt[5]}
#}
#
## >>>>>> Generating DB
#db_job_count=0
#
### generating summarize annovar database file
#job_key="$running_key"_sa
#sa_file_name="$out_dir/$running_key.sa"
#cmd="$SCRIPT_GEN_SA -A $annovar_root_dir -k $job_key -t $tabix_file -o $sa_file_name -w $working_dir"
#if [ ! -z "$col_names" ]; then
#    cmd+=" -c $col_names"
#fi
#if [ ! -z "$plink_region" ]; then
#    cmd+=" -R $plink_region"
#fi
#db_job_id[$db_job_count]=`submit_cmd "$cmd" "$job_key"`
#db_job_count=$((db_job_count+1))
#
## generating genotyped vcf gt data
#if [ "$gt_vcf_gt_annotation" = "On" ]
#then
#    job_key="$running_key"_gt_vcf_gt
#    gt_vcf_gt_file_name="$running_key".gt.vgt
#    cmd="$SCRIPT_GEN_VCF_GT -k $job_key -t $tabix_file -o $gt_vcf_gt_file_name"
#    if [ ! -z "$col_names" ]; then
#       cmd+=" -c $col_names"
#    fi
#    if [ ! -z "$plink_region" ]; then
#       cmd+=" -R $plink_region"
#    fi
#    db_job_id[$db_job_count]=`submit_cmd "$cmd" "$job_key"`
#    db_job_count=$((db_job_count+1))
#fi
#
## generating mutation vcf gt data
#if [ "$mt_vcf_gt_annotation" = "On" ]
#then
#    job_key="$running_key"_mt_vcf_gt
#    mt_vcf_gt_file_name="$running_key".mt.vgt
#    cmd="$SCRIPT_GEN_VCF_GT -k $job_key -t $tabix_file -o $mt_vcf_gt_file_name -M"
#    if [ ! -z "$col_names" ]; then
#       cmd+=" -c $col_names"
#    fi
#    if [ ! -z "$plink_region" ]; then
#       cmd+=" -R $plink_region"
#    fi
#    db_job_id[$db_job_count]=`submit_cmd "$cmd" "$job_key"`
#    db_job_count=$((db_job_count+1))
#fi
#
#PENDING_STATUS="PENDING"
#COMPLETED_STATUS="COMPLETED"
#FAILED_STATUS="FAILED"
#while true;
#do
#    db_ready="TRUE"
#    for (( i=0; i<$db_job_count; i++ ))
#    do
#	job_no=${db_job_id[$i]}
#	job_status=`get_job_status $job_no`
#	echo -e "job no : $job_no\tstatus: $job_status" 1>&2
#    	if [ "$job_status" != "$COMPLETED_STATUS" ]
#    	then
#    	   db_ready="FALSE" 
#    	fi
#    done
#    if [ "$db_ready" = "TRUE" ]
#    then
#	break
#    fi
#    sleep 3
#done
#
#
#
#
#### ****************************************  executing  ****************************************
##tmp_rearrange="$working_dir/tmp_rearrange"
##tmp_oaf="$working_dir/tmp_oaf"
##tmp_mt_vcf_gt="$working_dir/tmp_mt_vcf_gt"
##tmp_gt_vcf_gt="$working_dir/tmp_gt_vcf_gt"
##tmp_join="$working_dir/tmp_join"
##tmp_suggesting_sheet="$working_dir/tmp_suggesting_sheet"
##
###---------- rearrange summarize annovar --------------
##COL_SA_KEY=1
##COL_SA_FUNC=2
##COL_SA_GENE=3
##COL_SA_EXONICFUNC=4
##COL_SA_AACHANGE=5
##COL_SA_1000G=9
##COL_SA_DBSNP=10
##COL_SA_PHYLOP=12
##COL_SA_PHYLOPPRED=13
##COL_SA_SIFT=14
##COL_SA_SIFTPRED=15
##COL_SA_POLYPHEN=16
##COL_SA_POLYPHENPRED=17
##COL_SA_LRT=18
##COL_SA_LRTPRED=19
##COL_SA_MT=20
##COL_SA_MTPRED=21
##COL_SA_CHR=23
##COL_SA_STARTPOS=24
##COL_SA_ENDPOS=25
##COL_SA_REF=26
##COL_SA_OBS=27
###COL_SA_OAF=29
##
##rearrange_header_cmd="head -1 $sa_in_file | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tPhyloP\tPhyloP prediction\tSIFT\tSIFT prediction\tPolyPhen2\tPolyPhen2 prediction\tLRT\tLRT prediction\tMT\tMT prediction\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS}' > $tmp_rearrange"
##echo "##" 1>&2
##echo "## >>>>>>>>>>>>>>>>>>>> rearrange header <<<<<<<<<<<<<<<<<<<<" 1>&2
##echo "## executing: $rearrange_header_cmd" 1>&2
##eval $rearrange_header_cmd
##
##rearrange_content_cmd="grep -v \"Func\" $sa_in_file | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS, \$$COL_SA_PHYLOP, \$$COL_SA_PHYLOPPRED, \$$COL_SA_SIFT, \$$COL_SA_SIFTPRED, \$$COL_SA_POLYPHEN, \$$COL_SA_POLYPHENPRED, \$$COL_SA_LRT, \$$COL_SA_LRTPRED, \$$COL_SA_MT, \$$COL_SA_MTPRED}' | sort -t$'\t' -k1,1 >> $tmp_rearrange"
##echo "## executing: $rearrange_content_cmd" 1>&2
##eval $rearrange_content_cmd
##
##cp $tmp_rearrange $tmp_join
###---------- rearrange summarize annovar --------------
##
###---------- join oaf --------------
##COL_OAF_INSERTING=6
##
##if [ ! -z "$oaf_in_file" ]; then
##    n_col=$( grep "^#" $tmp_join | head -1 | awk -F'\t' '{ printf NF }' )
##
##    awk_oaf_printf_format_first_clause="%s"
##    awk_oaf_printf_param_content_clause+="\$1"
##    join_oaf_format_first_clause="1.1"
##    for (( i=2; i<$COL_OAF_INSERTING; i++ ))
##    do
##        awk_oaf_printf_format_first_clause+="\t%s"
##	awk_oaf_printf_param_content_clause+=", \$$i"
##	join_oaf_format_first_clause+=",1.$i"
##    done
##    awk_oaf_printf_format_second_clause="%s"
##    awk_oaf_printf_param_content_clause+=", \$$i"
##    join_oaf_format_second_clause="1.$COL_OAF_INSERTING"
##    for (( i=$(( COL_OAF_INSERTING+1 )); i<=$n_col; i++ ))
##    do
##        awk_oaf_printf_format_second_clause+="\t%s"
##	awk_oaf_printf_param_content_clause+=", \$$i"
##	join_oaf_format_second_clause+=",1.$i"
##    done
##    join_oaf_header_cmd="head -1 $tmp_join | awk -F'\t' '{ printf \"$awk_oaf_printf_format_first_clause\tOAF\t$awk_oaf_printf_format_second_clause\n\", $awk_oaf_printf_param_content_clause }' > $tmp_oaf"
##    echo "##" 1>&2
##    echo "## >>>>>>>>>>>>>>>>>>>> join with oaf <<<<<<<<<<<<<<<<<<<<" 1>&2
##    echo "## executing: $join_oaf_header_cmd" 1>&2
##    eval $join_oaf_header_cmd
##    join_oaf_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $join_oaf_format_first_clause,2.2,$join_oaf_format_second_clause <( grep -v \"^#\" $tmp_join ) $oaf_in_file | sort -t$'\t' -k1,1 >> $tmp_oaf"
##    echo "## executing: $join_oaf_content_cmd" 1>&2
##    eval $join_oaf_content_cmd
##
##    cp $tmp_oaf $tmp_join
##fi
##n_col_main=$( head -1 $tmp_join | awk -F'\t' '{ print NF }' )
###---------- join oaf --------------
##
##function summary_general_join {
##    join_master_data=$1
##    join_addon_data=$2
##
##    tmp_summary_general_join="$working_dir/tmp_summary_general_join"
##
##    # generate header
##    IFS=$'\t' read -ra header_addon_data <<< "$( grep "^#" $join_addon_data | head -1 )"
##    summary_general_join_header=$( grep "^#" $join_master_data | head -1 )
##    for (( i=1; i<=$((${#header_addon_data[@]})); i++ ))
##    do
##	summary_general_join_header+="\t${header_addon_data[$i]}"
##    done
##    echo -e "$summary_general_join_header" > $tmp_summary_general_join
##
##    # generate data
##    # prepare clauses
##    n_col_master_data=$( grep "^#" $join_master_data | head -1 | awk -F'\t' '{ printf NF }' )
##    n_col_addon_data=$( grep "^#" $join_addon_data | head -1 | awk -F'\t' '{ printf NF }' )
##    summary_general_join_format_first_clause="1.1"
##    for (( i=2; i<=$n_col_master_data; i++ ))
##    do
##	summary_general_join_format_first_clause+=",1.$i"
##    done
##    summary_general_join_format_second_clause="2.2"
##    for (( i=3; i<=$n_col_addon_data; i++ ))
##    do
##	summary_general_join_format_second_clause+=",2.$i"
##    done
##
##    # join content
##    summary_general_join_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $summary_general_join_format_first_clause,$summary_general_join_format_second_clause <( grep -v \"^#\" $join_master_data ) <( grep -v \"^#\" $join_addon_data | sort -t$'\t' -k1,1 ) | sort -t$'\t' -k1,1 >> $tmp_summary_general_join"
##    echo "##" 1>&2
##    echo "## >>>>>>>>>>>>>>>>>>>> join with $join_addon_data <<<<<<<<<<<<<<<<<<<<" 1>&2
##    echo "## executing: $summary_general_join_content_cmd" 1>&2
##    eval $summary_general_join_content_cmd
##
##    cmd="cp $tmp_summary_general_join $join_master_data"
##    eval $cmd
##
##    echo $(( n_col_addon_data - 1 ))
##}
##
##
###---------- join mt vcf gt --------------
##if [ ! -z "$mt_vcf_gt_in_file" ]; then
##    n_col_mt_vcf_gt=$( summary_general_join $tmp_join $mt_vcf_gt_in_file )
##fi
###---------- join gt vcf gt --------------
##
###---------- join gt vcf gt --------------
##if [ ! -z "$gt_vcf_gt_in_file" ]; then
##    n_col_gt_vcf_gt=$( summary_general_join $tmp_join $gt_vcf_gt_in_file )
##fi
###---------- join gt vcf gt --------------
##
###---------- generate suggesting sheet if any --------------
##if [ "$suggesting_sheet" = "True" ]; then
##
##    echo "##" 1>&2
##    echo "## >>>>>>>>>>>>>>>>>>>> generate with suggesting sheet <<<<<<<<<<<<<<<<<<<<" 1>&2
##    cmd="cp $tmp_join $tmp_suggesting_sheet"
##    eval $cmd
##
##    if [ "$exonic_filtering" = "On" ]; then
##	tmp_suggesting_sheet_exonic_filtering="$working_dir/tmp_suggesting_sheet_exonic_filtering"
##
##	exonic_filtering_cmd="awk -F'\t' '{ if (\$$COL_SA_EXONICFUNC != \"\") print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_exonic_filtering"
##	echo "## executing: $exonic_filtering_cmd" 1>&2
##	eval $exonic_filtering_cmd
##
##	cmd="cp $tmp_suggesting_sheet_exonic_filtering $tmp_suggesting_sheet"
##    	eval $cmd
##    fi
##    if [ "$missense_filtering" = "On" ]; then
##	tmp_suggesting_sheet_missense_filtering="$working_dir/tmp_suggesting_sheet_missense_filtering"
##
##	missense_filtering_cmd="awk -F'\t' '{ if ((\$$COL_SA_EXONICFUNC != \"\") && (\$$COL_SA_EXONICFUNC != \"unknown\") && (\$$COL_SA_EXONICFUNC != \"synonymous SNV\")) print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_missense_filtering"
##	echo "## executing: $missense_filtering_cmd" 1>&2
##	eval $missense_filtering_cmd
##
##	cmd="cp $tmp_suggesting_sheet_missense_filtering $tmp_suggesting_sheet"
##    	eval $cmd
##    fi
##    if [ "$deleterious_filtering" = "On" ]; then
##	tmp_suggesting_sheet_deleterious_filtering="$working_dir/tmp_suggesting_sheet_deleterious_filtering"
##
##	deleterious_filtering_cmd="awk -F'\t' '{ if ((\$$COL_SA_EXONICFUNC != \"\") && (\$$COL_SA_EXONICFUNC != \"nonsynonymous SNV\") && (\$$COL_SA_EXONICFUNC != \"unknown\") && (\$$COL_SA_EXONICFUNC != \"synonymous SNV\")) print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_deleterious_filtering"
##	echo "## executing: $deleterious_filtering_cmd" 1>&2
##	eval $deleterious_filtering_cmd
##
##	cmd="cp $tmp_suggesting_sheet_deleterious_filtering $tmp_suggesting_sheet"
##    	eval $cmd
##    fi
###    if [ "$rare_filtering" = "On" ]; then
###	tmp_suggesting_sheet_rare_filtering="$working_dir/tmp_suggesting_sheet_rare_filtering"
###
###	rare_filtering_cmd="awk -F'\t' '{ if ((\$$COL_SA_EXONICFUNC != \"\") && (\$$COL_SA_EXONICFUNC != \"unknown\") && (\$$COL_SA_EXONICFUNC != \"synonymous SNV\")) print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_rare_filtering"
###	echo "## executing: $rare_filtering_cmd" 1>&2
###	eval $rare_filtering_cmd
###
###	cmd="cp $tmp_suggesting_sheet_rare_filtering $tmp_suggesting_sheet"
###    	eval $cmd
###    fi
##fi
###---------- generate suggesting sheet if any --------------
##
####---------- generate output xls file --------------
##python_cmd="python $CSVS2XLS"
### set indexes of column to be hidden
##python_cmd+=" -C \"0,10,13,14,15,16,17,18,19,20,21,22\""
### set frequencies ratio to be highlighted
##python_cmd+=" -F $((COL_OAF_INSERTING-1)):$oaf_ratio,$COL_OAF_INSERTING:$maf_ratio"
### set raw input sheets together with their names
##sheets_param_value="all,$tmp_join"
##if [ "$suggesting_sheet" = "True" ]; then
##    sheets_param_value+=":suggested,$tmp_suggesting_sheet"
##fi
##python_cmd+=" -s $sheets_param_value"
##python_cmd+=" -o $out_file"
##if [ ! -z "$plink_region" ]; then
##    marked_key_range=$( plink_region_to_key_range "$plink_region" )
##    python_cmd+=" -R \"$marked_key_range\""
##fi
##python_cmd+=" -c $n_col_main,$(( n_col_main+n_col_mt_vcf_gt ))"
##echo "##" 1>&2
##echo "## >>>>>>>>>>>>>>>>>>>> convert csvs to xls <<<<<<<<<<<<<<<<<<<<" 1>&2
##echo "## executing: $python_cmd" 1>&2
##eval $python_cmd
###---------- generate output xls file --------------
##
##
##echo "##" 1>&2
#echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
