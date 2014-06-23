#!/bin/bash

script_name=$(basename $0)

#define default values
PLINK_REGION_DEFAULT="All"
PLINK_PHENO_FILE_DEFAULT=""
FAMILIES_HAPLOTYPES_FILE_DEFAULT=""
PVALUE_SIGNIFICANCE_RATIO_DEFAULT="1e-03"
USE_CACHED_PLINK_HAP_ASSOC_DEFAULT="Off"
USE_CACHED_PLINK_EXTRA_INFO_DEFAULT="Off"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {project code}   specify UPPMAX project code (default: no job)
-k {name}	    specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-b {file}	    specify PLINK input bfile prefix (required)
-W {file}	    specify PLINK haplotype window sizes for association study (comma separated, e.g., -W 1,2) (required)
-R {region}	    specify PLINK region of interest (default: $PLINK_REGION_DEFAULT)
-P {file}	    specify PLINK phenotype file (default: None)
-f {file}	    specify PLINK families haplotypes database tfile prefix (default: None)
-I {file}	    specify PLINK tfam individual ids (comma separated, e.g., -I fam_8,fam_24) (default: None)
-S {number}         specify P-value significant ratio (default: $PVALUE_SIGNIFICANCE_RATIO_DEFAULT)
-a                  use cached for PLINK haplotype association study (default: $CACHED_PLINK_HAP_ASSOC_DEFAULT)
-r                  use cached to get PLINK extra information for report (default: $CACHED_PLINK_EXTRA_INFO_DEFAULT) 
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
while getopts ":p:t:k:b:W:P:f:I:R:S:aro:w:l:" OPTION; do
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
      plink_input_bfile_prefix="$OPTARG"
      ;;
    W)
      plink_hap_window_sizes="$OPTARG"
      ;;
    P)
      plink_pheno_file="$OPTARG"
      ;;
    f)
      plink_fams_haplos_db_tfile_prefix="$OPTARG"
      ;;
    I)
      plink_tfam_individual_ids="$OPTARG"
      ;;
    R)
      plink_region="$OPTARG"
      ;;
    S)
      pvalue_significance_ratio="$OPTARG"
      ;;
    a)
      use_cached_plink_hap_assoc="On"
      ;;
    r)
      use_cached_plink_extra_info="On"
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
[ ! -z $plink_input_bfile_prefix ] || die "Please specify PLINK binary input file prefix (-b)"
[ ! -z $plink_hap_window_sizes ] || die "Please specify PLINK haplotype window sizes (-W)"
[ ! -z $out_dir ] || die "Plesae specify output directory (-o)"
[ ! -z $working_dir ] || die "Plesae specify working directory (-w)"
[ ! -z $log_dir ] || die "Plesae specify logging directory (-l)"
[ -f "$plink_input_bfile_prefix".bed ] || die "$plink_input_bfile_prefix is not a valid file prefix"
[ -f "$plink_input_bfile_prefix".bim ] || die "$plink_input_bfile_prefix is not a valid file prefix"
[ -f "$plink_input_bfile_prefix".fam ] || die "$plink_input_bfile_prefix is not a valid file prefix"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$out_dir is not a valid directory"
[ -d $log_dir ] || die "$log_dir is not a valid directory"

#setting default values:
: ${plink_region=$PLINK_REGION_DEFAULT}
: ${plink_pheno_file=$PLINK_PHENO_FILE_DEFAULT}
: ${plink_fams_haplos_db_tfile_prefix=$FAMILIES_HAPLOTYPES_FILE_DEFAULT}
: ${pvalue_significance_ratio=$PVALUE_SIGNIFICANCE_RATIO_DEFAULT}
: ${use_cached_plink_hap_assoc=$USE_CACHED_PLINK_HAP_ASSOC_DEFAULT}
: ${use_cached_plink_extra_info=$USE_CACHED_PLINK_EXTRA_INFO_DEFAULT}

raw_plink_out_with_odds_ratio="$out_dir/raw_plink_out_w_OR.txt"
filtered_haplotypes_out="$out_dir/filtered_haplotypes_out.txt"
significant_windows_out="$out_dir/significant_windows_out.txt"
xls_out="$out_dir/$running_key"_report.xlsx

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
if [ ! -z "$project_code" ]
then
    display_param "project code (-p)" "$project_code"
fi
display_param "running key (-k)" "$running_key"
display_param "total run time (-t)" "$total_run_time"
display_param "PLINK input file prefix (-b)" "$plink_input_bfile_prefix"
display_param "PLINK haplotype window sizes (-W)" "$plink_hap_window_sizes"
display_param "P-value significance ratio (-S)" "$pvalue_significance_ratio"
display_param "log directory (-l)" "$log_dir"
display_param "working directory (-w)" "$working_dir"
display_param "running-time key" "$running_time"

echo "##" 1>&2
echo "## output file" 1>&2
display_param "raw PLINK output with odds ratio" "$raw_plink_out_with_odds_ratio"
display_param "filtered PLINK output" "$filtered_haplotypes_out"
display_param "haplotype windows with significant P-value" "$significant_windows_out"
display_param "xls report" "$xls_out"

## display optional configuration
echo "##" 1>&2
echo "## optional configuration" 1>&2
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
display_param "using cached PLINK haplotype association" "$use_cached_plink_hap_assoc"
display_param "using cached PLINK extra SNPs information" "$use_cached_plink_extra_info"
if [ ! -z "$plink_pheno_file" ]
then
    display_param "PLINK phenotype file (-P)" "$plink_pheno_file"
fi
if [ ! -z "$plink_fams_haplos_db_tfile_prefix" ]
then
    display_param "families haplotypes database tfile prefix (-f)" "$plink_fams_haplos_db_tfile_prefix"
fi
if [ ! -z "$plink_tfam_individual_ids" ]
then
    IFS=',' read -ra tfam_individual_ids <<< "$plink_tfam_individual_ids"
    display_param "input individual ids (-I)" "$plink_tfam_individual_ids"
    for (( i=0; i<$((${#tfam_individual_ids[@]})); i++ ))
    do
	display_param "  individual idi #$((i+1))" "${tfam_individual_ids[$i]}"
    done
fi

# ****************************************  executing  ****************************************
COL_HAP_ASSOC_LOCUS=1
COL_HAP_ASSOC_HAPLOTYPE=2
COL_HAP_ASSOC_F_A=3
COL_HAP_ASSOC_F_U=4
COL_HAP_ASSOC_CHISQ=5
COL_HAP_ASSOC_DF=6
COL_HAP_ASSOC_P_VALUE=7
COL_HAP_ASSOC_SNPS=8
NEW_COL_HAP_ASSOC_P_VALUE=8
NEW_COL_HAP_ASSOC_SNPS=9
COL_HAP_ASSOC_INSERTED_OR=6

COL_STAT_CHR=1
COL_STAT_SNP=2
COL_STAT_CLST=3
COL_STAT_N_MISS=4
COL_STAT_N_GENO=5
COL_STAT_N_CLUS=6
COL_STAT_F_MISS=7

COL_TFILE_CHR=1
COL_TFILE_POS=4

# ---------- General functions --------------
function submit_cmd {
    cmd=$1
    job_name=$2
    project_code=$3
    n_cores=$4

    sbatch_cmd="sbatch"
    sbatch_cmd+=" -A $project_code"
    if [ "$n_cores" -ge "8" ]
    then
	sbatch_cmd+=" -p node"
    else
	sbatch_cmd+=" -p core"
    fi
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

# ---------- submitting PLINK job --------------
plink_base_cmd="$PLINK_DUMMY --noweb --bfile $plink_input_bfile_prefix"
tmp_hap_assoc_out_base_prefix="$working_dir/$running_key"_tmp_assoc_out
if [ "$plink_region" != "All" ]
then
    if [ ! -z "$plink_from_bp" ]
    then
	plink_base_cmd+=" --chr $plink_chrom --from-bp $plink_from_bp --to-bp $plink_to_bp"
    else
	plink_base_cmd+=" --chr $plink_chrom"
    fi
fi
if [ ! -z "$plink_pheno_file" ]
then
    plink_base_cmd+=" --pheno $plink_pheno_file"
fi
plink_base_cmd+=" --hap-assoc --geno 0.1 --maf 0.01"

echo "##" 1>&2
echo "## > > > > > > > > > > > > > > > > > > > > Submitting PLINK job < < < < < < < < < < < < < < < < < < < < " 1>&2
IFS=',' read -ra list_plink_hap_window_sizes <<< "$plink_hap_window_sizes"
for (( i=0; i<$((${#list_plink_hap_window_sizes[@]})); i++ ))
do
    window_size="${list_plink_hap_window_sizes[$i]}"
    job_key="$running_key"_win_$window_size
    tmp_hap_assoc_out_prefix[$i]="$tmp_hap_assoc_out_base_prefix"_$window_size
    submit_job_cmd="$plink_base_cmd --out ${tmp_hap_assoc_out_prefix[$i]} --hap-window $window_size"
    if [ ! -z "$project_code" ]
    then
        if [ "$window_size" -ge "50" ]
        then
	    n_cores=8
	else
	    n_cores=1
        fi
	running_job_id[$running_job_count]=`submit_cmd "$submit_job_cmd" "$job_key" "$project_code" "$n_cores"`
    	running_job_count=$((running_job_count+1))
    else
        echo "## executing: $submit_job_cmd " 1>&2
	if [ "$use_cached_plink_hap_assoc" == "Off" ]
	then
            eval "$submit_job_cmd"
	fi
    fi
done
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
# ---------- submitting PLINK job --------------

# ---------- merging PLINK assoc.hap files --------------
tmp_merged_hap_assoc="$working_dir/$running_key"_tmp_merged_hap_assoc
head -1 ${tmp_hap_assoc_out_prefix[0]}.assoc.hap > $tmp_merged_hap_assoc
for (( i=0; i<$((${#tmp_hap_assoc_out_prefix[@]})); i++ ))
do
    grep -v "HAPLOTYPE" ${tmp_hap_assoc_out_prefix[$i]}.assoc.hap | sed s/WIN/WIN${list_plink_hap_window_sizes[$i]}_/g >> $tmp_merged_hap_assoc
done
# ---------- merging PLINK assoc.hap files --------------

# ---------- calculating odds ratio --------------
cal_odds_ratio_cmd="awk '{
if (\$$COL_HAP_ASSOC_HAPLOTYPE == \"OMNIBUS\" || \$$COL_HAP_ASSOC_F_A == \"1\"  || \$$COL_HAP_ASSOC_F_A == \"0\" || \$$COL_HAP_ASSOC_F_U == \"1\" || \$$COL_HAP_ASSOC_F_U == \"0\") 
    printf \"%s\t%s\t%s\t%s\t%s\tNA\t%s\t%s\t%s\n\", \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8
else if (\$$COL_HAP_ASSOC_HAPLOTYPE == \"HAPLOTYPE\")  
    printf \"%s\t%s\t%s\t%s\t%s\tOR\t%s\t%s\t%s\n\", \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8
else {
    F_A=strtonum(\$$COL_HAP_ASSOC_F_A)
    F_U=strtonum(\$$COL_HAP_ASSOC_F_U)
    odds_ratio=(F_A/(1-F_A))/(F_U/(1-F_U))
    printf \"%s\t%s\t%s\t%s\t%s\t%0.4f\t%s\t%s\t%s\n\", \$1, \$2, \$3, \$4, \$5, odds_ratio, \$6, \$7, \$8
    }
}' $tmp_merged_hap_assoc > $raw_plink_out_with_odds_ratio"
echo "##" 1>&2
echo "## executing: $cal_odds_ratio_cmd " 1>&2
eval "$cal_odds_ratio_cmd"
# ---------- calculating odds ratio --------------

# ---------- filtering haplotype with significant P value, F_A, F_U, and odds ratio --------------
# 1. F_A > F_U
# 2. P < 0.05
# 3. odds ratio > 1.5
filtering_haplotype_cmd="awk '{
if (\$$COL_HAP_ASSOC_HAPLOTYPE == \"HAPLOTYPE\")  
    printf \"%s\n\", \$0
else { 
    F_A=strtonum(\$$COL_HAP_ASSOC_F_A)
    F_U=strtonum(\$$COL_HAP_ASSOC_F_U)
    P_VALUE=strtonum(\$$NEW_COL_HAP_ASSOC_P_VALUE)
    ORS=strtonum(\$$COL_HAP_ASSOC_INSERTED_OR)
#    if (ORS > 0.1)
#    if ((F_A > F_U) && (P_VALUE < 0.05) && (ORS > 1.5))
#    if (P_VALUE < 0.05)
    if ((F_A > F_U) && (P_VALUE < 0.05))
	printf \"%s\n\", \$0
    }
}' $raw_plink_out_with_odds_ratio | grep -v \"OMNIBUS\" | grep -v \"NA\"> $filtered_haplotypes_out"
echo "##" 1>&2
echo "## executing: $filtering_haplotype_cmd " 1>&2
eval "$filtering_haplotype_cmd"
# ---------- filtering haplotype with significant P value, F_A, F_U, and odds ratio --------------

# ---------- filtering windows with significant P value below significant threshold --------------
filter_pvalue_cmd="awk -F'\t' '{if (\$$NEW_COL_HAP_ASSOC_P_VALUE<$pvalue_significance_ratio) printf \"%s\n\", \$0}' $filtered_haplotypes_out > $significant_windows_out"
echo "##" 1>&2
echo "## executing: $filter_pvalue_cmd " 1>&2
eval "$filter_pvalue_cmd"

number_of_significant_windows=$( cat $significant_windows_out | wc -l )
if [ "$number_of_significant_windows" -le "0" ]
then
    echo "##" 1>&2
    echo "## ! ! ! ! ! No significant window has been found ! ! ! ! ! " 1>&2
    echo "##" 1>&2
    echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
    exit
fi

# ---------- filtering windows with significant P value below significant threshold --------------

# ---------- Using SNPs from windows with significant P value to get significant haplotypes --------------
tmp_all_list_significant_SNPs="$working_dir/$running_key"_tmp_all_list_significant_SNPs
tmp_significant_haplotypes="$working_dir/$running_key"_tmp_significant_haplotypes
if [ -f "$tmp_significant_haplotypes" ]
then
    rm $tmp_significant_haplotypes
fi

n_list=0
cut -f"$NEW_COL_HAP_ASSOC_SNPS" "$significant_windows_out" |
while read list_SNPs_in
do
    let n_list++
#    echo "$list_SNPs_in"
    IFS='|' read -ra tmp_SNPs <<< "$list_SNPs_in"
    # get all the significant haplotypes that have any of uniq SNPs
    for (( i=0; i<$((${#tmp_SNPs[@]})); i++ ))
    do
        grep "${tmp_SNPs[$i]}" "$filtered_haplotypes_out" | sed s/WIN/HAP"$n_list"_WIN/g >> "$tmp_significant_haplotypes"
    done
done

# uniq the significant haplotypes from above
tmp_selected_haplotypes_out="$working_dir/$running_key"_tmp_selected_haplotypes_out
get_selected_haplotypes_cmd="head -1 $filtered_haplotypes_out > $tmp_selected_haplotypes_out; sort -k2,$NEW_COL_HAP_ASSOC_SNPS $tmp_significant_haplotypes | uniq -f1 | sort -k1,1 -V >> $tmp_selected_haplotypes_out"
echo "##" 1>&2
echo "## executing: $get_selected_haplotypes_cmd " 1>&2
eval "$get_selected_haplotypes_cmd"
# ---------- Using SNPs from windows with significant P value to get significant haplotypes --------------

# ---------- generating SNPs information --------------
tmp_all_list_xls_SNPs="$working_dir/$running_key"_tmp_all_list_xls_SNPs
if [ -f "$tmp_all_list_xls_SNPs" ]
then
    rm $tmp_all_list_xls_SNPs
fi

#cut -f"$NEW_COL_HAP_ASSOC_SNPS" "$tmp_selected_haplotypes_out" |
cut -f"$NEW_COL_HAP_ASSOC_SNPS" "$filtered_haplotypes_out" |
while read list_SNPs_in
do
#    echo "$list_SNPs_in"
    IFS='|' read -ra tmp_SNPs <<< "$list_SNPs_in"
    for (( i=0; i<$((${#tmp_SNPs[@]})); i++ ))
    do
	echo "${tmp_SNPs[$i]}" >> $tmp_all_list_xls_SNPs
    done
done

# uniq list of SNPs from above
tmp_uniq_list_xls_SNPs="$working_dir/$running_key"_tmp_uniq_list_xls_SNPs
sort "$tmp_all_list_xls_SNPs" | uniq | grep -v "SNPS" > "$tmp_uniq_list_xls_SNPs"

# extract SNPs position from PLINK binary files
tmp_extract_SNPs_position_prefix="$working_dir/$running_key"_tmp_extract_SNPs_position
extract_SNPs_position_from_bed_cmd="plink --noweb --bfile $plink_input_bfile_prefix --recode --tab --extract $tmp_uniq_list_xls_SNPs --out $tmp_extract_SNPs_position_prefix"
echo "##" 1>&2
echo "## > > > > > > > > > > > > > > > > > > > > Preparing SNPs information for PLINK report < < < < < < < < < < < < < < < < < < < < " 1>&2
echo "## executing: $extract_SNPs_position_from_bed_cmd " 1>&2
if [ "$use_cached_plink_extra_info" == "Off" ]
then
    eval "$extract_SNPs_position_from_bed_cmd"
fi

# extract SNPs genotyping statistics from PLINK binary files
tmp_extract_SNPs_stat_prefix="$working_dir/$running_key"_tmp_extract_SNPs_stat
extract_SNPs_stat_from_bed_cmd="plink --noweb --bfile $plink_input_bfile_prefix --missing --extract $tmp_uniq_list_xls_SNPs --out $tmp_extract_SNPs_stat_prefix --within $plink_pheno_file"
echo "##" 1>&2
echo "## executing: $extract_SNPs_stat_from_bed_cmd " 1>&2
if [ "$use_cached_plink_extra_info" == "Off" ]
then
    eval "$extract_SNPs_stat_from_bed_cmd"
fi

# generating SNPs info file
tmp_SNPs_info="$working_dir/$running_key"_tmp_SNPs_info
join_snps_info_cmd="join -t $'\t' -j 1 -o 0,1.2,1.3,2.2,2.3 <( join -t $'\t' -j 1 -o 0,1.2,2.2 <( awk 'BEGIN { printf \"SNP\tF_MISS_A\n\" }{ if (\$$COL_STAT_CLST == \"2\" ) printf \"%s\t%s\n\", \$$COL_STAT_SNP, \$$COL_STAT_F_MISS }' $tmp_extract_SNPs_stat_prefix.lmiss) <( awk 'BEGIN { printf \"SNP\tF_MISS_U\n\" }{ if (\$$COL_STAT_CLST == \"1\" ) printf \"%s\t%s\n\", \$$COL_STAT_SNP, \$$COL_STAT_F_MISS }' $tmp_extract_SNPs_stat_prefix.lmiss )) <( awk -F'\t' 'BEGIN { printf \"SNP\tCHROM\tPOS\n\" }{ printf \"%s\t%s\t%s\n\", \$2, \$1, \$4}' $tmp_extract_SNPs_position_prefix.map ) > $tmp_SNPs_info"
echo "##" 1>&2
echo "## executing: $join_snps_info_cmd " 1>&2
eval "$join_snps_info_cmd"
# ---------- generating SNPs information --------------

# ---------- prepare haplotypes families information if indicated --------------
if [ ! -z "$plink_fams_haplos_db_tfile_prefix" ]
then
    tmp_xls_fams_haplos_db_tfile_prefix="$working_dir/$running_key"_tmp_xls_families_haplotypes
    # picking only markers of interest
    tmp_awk_filter_row_out="$working_dir/$running_key"_tmp_awk_filter_row
    if [ "$plink_region" != "All" ]
    then
	tmp_awk_filter_row_cmd="awk -F'\t' '{"
        if [ ! -z "$plink_from_bp" ]
        then
	    tmp_awk_filter_row_cmd+=" if ((\$$COL_TFILE_CHR == \"$plink_chrom\" ) && (\$$COL_TFILE_POS > $plink_from_bp) && (\$$COL_TFILE_POS < $plink_to_bp))"
        else
	    tmp_awk_filter_row_cmd+=" if (\$$COL_TFILE_CHR == \"$plink_chrom\" )"
        fi
	tmp_awk_filter_row_cmd+=" printf \"%s\n\", \$0}' $plink_fams_haplos_db_tfile_prefix.tped > $tmp_awk_filter_row_out"
    else
	tmp_awk_filter_row_cmd="cp $plink_fams_haplos_db_tfile_prefix.tped $tmp_awk_filter_row_out"
    fi
    echo "##" 1>&2
    echo "## > > > > > > > > > > > > > > > > > > > > Preparing haplotypes families information < < < < < < < < < < < < < < < < < < < < " 1>&2
    echo "##" 1>&2
    echo "## executing: $tmp_awk_filter_row_cmd " 1>&2
    eval "$tmp_awk_filter_row_cmd"

    # picking only individuals of interest
    tmp_cut_filter_col_out="$working_dir/$running_key"_tmp_cut_filter_col
    if [ ! -z "$plink_tfam_individual_ids" ]
    then
	# preparing command to generate output tped file
	tmp_cut_filter_col_cmd="cut -f1-4"
	tmp_row_list=""
        for (( i=0; i<$((${#tfam_individual_ids[@]})); i++ ))
        do
	    grep_cmd="grep -nP \"\t${tfam_individual_ids[$i]}\t\" $plink_fams_haplos_db_tfile_prefix.tfam"
	    IFS=':' read -ra tmp_extract_individual_col <<< "`eval $grep_cmd`"
	    tmp_row=${tmp_extract_individual_col[0]}
	    tmp_row_list+=",$tmp_row"
	    tmp_cut_filter_col_cmd+=",$((tmp_row+4))"
        done
	tmp_cut_filter_col_cmd+=" $tmp_awk_filter_row_out > $tmp_xls_fams_haplos_db_tfile_prefix.tped"

	# generating tfam file
	if [ -f "$tmp_xls_fams_haplos_db_tfile_prefix.tfam" ]
    	then
    	    rm "$tmp_xls_fams_haplos_db_tfile_prefix.tfam"
    	fi
	sort_row_list=`echo "$tmp_row_list" | tr "," "\n" | sort | tr "\n" " " | sed 's/,$//' | sed 's/^,//'`
	for sorted_row in `echo $sort_row_list`; 
	do
	    sed -n "$sorted_row"p $plink_fams_haplos_db_tfile_prefix.tfam >> "$tmp_xls_fams_haplos_db_tfile_prefix.tfam"
	done
    else
	# preparing command to generate output tped file
	tmp_cut_filter_col_cmd+=" cp $tmp_awk_filter_row_out $tmp_xls_fams_haplos_db_tfile_prefix.tped"

	# generating tfam file
	cp $plink_fams_haplos_db_tfile_prefix.tfam "$tmp_xls_fams_haplos_db_tfile_prefix.tfam"
    fi
    echo "##" 1>&2
    echo "## executing: $tmp_cut_filter_col_cmd " 1>&2
    eval "$tmp_cut_filter_col_cmd"
fi
# ---------- prepare haplotypes families information if indicated --------------

# ---------- generate output xls file --------------
python_cmd="python $PLINK2XLS"
#python_cmd+=" -A raw,$raw_plink_out_with_odds_ratio"
#python_cmd+=" -A raw,$raw_plink_out_with_odds_ratio:filtered-assoc.hap,$filtered_haplotypes_out:input,$tmp_selected_haplotypes_out"
#python_cmd+=" -A filtered-assoc.hap,$filtered_haplotypes_out:input,$tmp_selected_haplotypes_out"
#python_cmd+=" -A OR,$raw_plink_out_with_odds_ratio:input,$tmp_selected_haplotypes_out"
python_cmd+=" -S $tmp_SNPs_info"
python_cmd+=" -H $tmp_selected_haplotypes_out"
python_cmd+=" -F $filtered_haplotypes_out"
if [ ! -z "$plink_fams_haplos_db_tfile_prefix" ]
then
    python_cmd+=" -f $tmp_xls_fams_haplos_db_tfile_prefix"
fi
python_cmd+=" -p $pvalue_significance_ratio"
python_cmd+=" -o $xls_out"
echo "##" 1>&2
echo "## > > > > > > > > > > > > > > > > > > > > Generating PLINK xls < < < < < < < < < < < < < < < < < < < < " 1>&2
echo "## executing: $python_cmd" 1>&2
eval $python_cmd
# ---------- generate output xls file --------------

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2