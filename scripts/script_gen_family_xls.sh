#!/bin/bash

script_name=$(basename $0)

#define default values
VCF_REGION_DEFAULT=""
OAF_RATIO_DEFAULT="0.1"
MAF_RATIO_DEFAULT="0.1"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-k {name}          specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-O {file}          specify oaf input file name (required)
-M {file}          specify input file name of mutated GT db generated from vcf (required)
-S {file}          specify input file name of summarize annovar database (required)
-R {region}        specify vcf region of interest (default:None)
-A {percent}       specify OAF criteria for rare mutations (default:0.1)
-F {percent}       specify MAF criteria for rare mutations (default:0.1)
-o {directory}     specify output directory (required)
-w {directory}     specify working directory (required)
-f {code}          specify family code (required)
-m {patient list}  specify list of family members (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

# parse option
while getopts ":k:O:M:S:R:A:F:o:w:f:m:" OPTION; do
  case "$OPTION" in
    k)
      running_key="$OPTARG"
      ;;
    O)
      oaf_in_file="$OPTARG"
      ;;
    M)
      mt_vcf_gt_in_file="$OPTARG"
      ;;
    S)
      sa_in_file="$OPTARG"
      ;;
    R)
      vcf_region="$OPTARG"
      ;;
    A)
      oaf_ratio="$OPTARG"
      ;;
    F)
      maf_ratio="$OPTARG"
      ;;
    o)
      out_dir="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    f)
      family_code="$OPTARG"
      ;;
    m)
      member_list="$OPTARG"
      ;;
    *)
      die "unrecognized option"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specfify a unique key for this run"
[ ! -z $oaf_in_file ] || die "Please specify oaf input file name"
[ ! -z $mt_vcf_gt_in_file ] || die "Please specify mutated GT db input file name"
[ ! -z $sa_in_file ] || die "Please specify summarize annovar input file name"
[ ! -z $out_dir ] || die "Please specify an output file name"
[ ! -z $working_dir ] || die "Please specify a working directory"
[ ! -z $family_code ] || die "Please specify family code"
[ ! -z $member_list ] || die "Please specify list of family members"
[ -f $oaf_in_file ] || die "$oaf_in_file is not a valid file name"
[ -f $mt_vcf_gt_file ] || die "$mt_vcf_gt_file is not a valid file name"
[ -f $sa_in_file ] || die "$sa_in_file is not a valid file name"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$out_dir is not a valid directory"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${oaf_ratio=$OAF_RATIO_DEFAULT}
: ${maf_ratio=$MAF_RATIO_DEFAULT}

out_file="$out_dir/$running_key"_fam"$family_code".xls

function get_patient_idxs {
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

function display_param {
    PARAM_PRINT_FORMAT="##   %-40s%s\n"
    param_name=$1
    param_val=$2

    printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val" 1>&2
}

function vcf_region_to_key_range {
    KEY_FORMAT="%s|%012d,%s|%012d"
    vcf_region=$1

    IFS=':' read -ra tmp_split_region <<< "$vcf_region"
    tmp_chrom=${tmp_split_region[0]}
    number_re='^[0-9]+$'
    if ! [[ $tmp_chrom =~ $number_re ]] ; then
        chrom=$( printf "%s" $tmp_chrom )
    else
        chrom=$( printf "%02d" $tmp_chrom )
    fi
    IFS='-' read -ra tmp_split_pos <<< "${tmp_split_region[1]}"
    printf "$KEY_FORMAT" "$chrom" "${tmp_split_pos[0]}" "$chrom" "${tmp_split_pos[1]}"
}

#splite member list into array of patient codes
IFS=',' read -ra array_full_patient_codes <<< "$member_list"
number_of_patients=$((${#array_full_patient_codes[@]}))
for (( i=0; i<$((${#array_full_patient_codes[@]})); i++ ))
do
    IFS='-' read -ra tmp_patient_code <<< "${array_full_patient_codes[$i]}"
    array_displayed_patient_codes[$i]=${tmp_patient_code[1]}
    patient_idxs[$i]=$( get_patient_idxs $mt_vcf_gt_in_file ${array_full_patient_codes[$i]} )
done

## ****************************************  display configuration  ****************************************
## display required configuration
echo "##" 1>&2
echo "## ************************************************** S T A R T <$script_name> **************************************************" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to join pre-computed mutations database and then generate excel sheet reporting consensus information" 1>&2
echo "##" 1>&2
echo "## overall configuration" 1>&2
display_param "running key (-k)" "$running_key"
display_param "core annotation file (-S)" "$sa_in_file"
display_param "oaf input file (-O)" "$oaf_in_file"
display_param "mutated vcf gt input file (-M)" "$mt_vcf_gt_in_file"
display_param "output file" "$out_file"
display_param "working directory (-w)" "$working_dir"

## display optional configuration
if [ ! -z "$vcf_region" ]; then
    echo "##" 1>&2
    echo "## input configuration" 1>&2
    display_param "vcf region (-R)" "$vcf_region"
fi

## display other configuration
echo "##" 1>&2
echo "## other configuration" 1>&2
display_param "oaf ratio" "$oaf_ratio"
display_param "maf ratio" "$maf_ratio"

## display family and members information
echo "##" 1>&2
echo "## family & members" 1>&2
display_param "family code" "$family_code"
display_param "patients count" "$number_of_patients"
for (( i=0; i<$((${#array_full_patient_codes[@]})); i++ ))
do
    display_param "  patient code$((i+1))" "${array_displayed_patient_codes[$i]}"
    display_param "  patient index$((i+1))" "${patient_idxs[$i]}"
done
patient_idx_list=${patient_idxs[0]}
for (( i=1; i<$((${#patient_idxs[@]})); i++ ))
do
    patient_idx_list+=","${patient_idxs[$i]}
done

## ****************************************  executing  ****************************************
tmp_rearrange="$working_dir/tmp_rearrange"
tmp_oaf="$working_dir/tmp_oaf"
tmp_mt_vcf_gt="$working_dir/tmp_mt_vcf_gt"
#tmp_gt_vcf_gt="$working_dir/tmp_gt_vcf_gt"
tmp_join="$working_dir/tmp_join"

#---------- rearrange summarize annovar --------------
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
#COL_SA_OAF=29

rearrange_header_cmd="head -1 $sa_in_file | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tPhyloP\tPhyloP prediction\tSIFT\tSIFT prediction\tPolyPhen2\tPolyPhen2 prediction\tLRT\tLRT prediction\tMT\tMT prediction\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS}' > $tmp_rearrange"
echo "##" 1>&2
echo "## >>>>>>>>>>>>>>>>>>>> rearrange header <<<<<<<<<<<<<<<<<<<<" 1>&2
echo "## executing: $rearrange_header_cmd" 1>&2
eval $rearrange_header_cmd

rearrange_content_cmd="grep -v \"Func\" $sa_in_file | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n\", \$$COL_SA_KEY, \$$COL_SA_FUNC, \$$COL_SA_GENE, \$$COL_SA_EXONICFUNC, \$$COL_SA_AACHANGE, \$$COL_SA_1000G, \$$COL_SA_DBSNP, \$$COL_SA_CHR, \$$COL_SA_STARTPOS, \$$COL_SA_ENDPOS, \$$COL_SA_REF, \$$COL_SA_OBS, \$$COL_SA_PHYLOP, \$$COL_SA_PHYLOPPRED, \$$COL_SA_SIFT, \$$COL_SA_SIFTPRED, \$$COL_SA_POLYPHEN, \$$COL_SA_POLYPHENPRED, \$$COL_SA_LRT, \$$COL_SA_LRTPRED, \$$COL_SA_MT, \$$COL_SA_MTPRED}' | sort -t$'\t' -k1,1 >> $tmp_rearrange"
echo "## executing: $rearrange_content_cmd" 1>&2
eval $rearrange_content_cmd

cp $tmp_rearrange $tmp_join
#---------- rearrange summarize annovar --------------

#---------- join oaf --------------
COL_OAF_INSERTING=6

if [ ! -z "$oaf_in_file" ]; then
    n_col=$( grep "^#" $tmp_join | head -1 | awk -F'\t' '{ printf NF }' )

    awk_oaf_printf_format_first_clause="%s"
    awk_oaf_printf_param_content_clause+="\$1"
    join_oaf_format_first_clause="1.1"
    for (( i=2; i<$COL_OAF_INSERTING; i++ ))
    do
        awk_oaf_printf_format_first_clause+="\t%s"
	awk_oaf_printf_param_content_clause+=", \$$i"
	join_oaf_format_first_clause+=",1.$i"
    done
    awk_oaf_printf_format_second_clause="%s"
    awk_oaf_printf_param_content_clause+=", \$$i"
    join_oaf_format_second_clause="1.$COL_OAF_INSERTING"
    for (( i=$(( COL_OAF_INSERTING+1 )); i<=$n_col; i++ ))
    do
        awk_oaf_printf_format_second_clause+="\t%s"
	awk_oaf_printf_param_content_clause+=", \$$i"
	join_oaf_format_second_clause+=",1.$i"
    done
    join_oaf_header_cmd="head -1 $tmp_join | awk -F'\t' '{ printf \"$awk_oaf_printf_format_first_clause\tOAF\t$awk_oaf_printf_format_second_clause\n\", $awk_oaf_printf_param_content_clause }' > $tmp_oaf"
    echo "##" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> join with oaf <<<<<<<<<<<<<<<<<<<<" 1>&2
    echo "## executing: $join_oaf_header_cmd" 1>&2
    eval $join_oaf_header_cmd
    join_oaf_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $join_oaf_format_first_clause,2.2,$join_oaf_format_second_clause <( grep -v \"^#\" $tmp_join ) $oaf_in_file | sort -t$'\t' -k1,1 >> $tmp_oaf"
    echo "## executing: $join_oaf_content_cmd" 1>&2
    eval $join_oaf_content_cmd

    cp $tmp_oaf $tmp_join
fi
n_col_main=$( head -1 $tmp_join | awk -F'\t' '{ print NF }' )
---------- join oaf --------------

function build_mutations_csv {
    join_master_data=$1
    mt_vcf_gt_col_idxs=$2


    #splite column indexs
    IFS=',' read -ra array_mt_vcf_gt_col_idxs <<< "$mt_vcf_gt_col_idxs"

    # ---------- filter mt_vcf_gt ----------
    mt_vcf_gt_filter_cmd=" awk -F'\t' '{ if ((\$${array_mt_vcf_gt_col_idxs[0]} != \".\")"
    columns_clause="\$1, \$${array_mt_vcf_gt_col_idxs[0]}"
    printf_clause="%s\t%s"
    mutations_csv_running_key=${array_mt_vcf_gt_col_idxs[0]}
    for (( j=1; j<$((${#array_mt_vcf_gt_col_idxs[@]})); j++ ))
    do
        #echo "## j:  $j" 1>&2
	mt_vcf_gt_filter_cmd+=" && (\$${array_mt_vcf_gt_col_idxs[$j]} != \".\")"
	columns_clause+=", \$${array_mt_vcf_gt_col_idxs[$j]}"
	printf_clause+="\t%s"
	mutations_csv_running_key+="_"${array_mt_vcf_gt_col_idxs[$j]}
    done
    tmp_file_prefix=$working_dir/"$running_key"_"$mutations_csv_running_key"_tmp
    tmp_mt_vcf_gt_filtered=$tmp_file_prefix"_mt_vcf_gt_filtered"

    mt_vcf_gt_filter_cmd+=") printf \"$printf_clause\n\", $columns_clause }' $mt_vcf_gt_in_file > $tmp_mt_vcf_gt_filtered"
#    echo "## awk filter clause :  $mt_vcf_gt_filter_cmd" 1>&2
#    echo "## columns clause :  $columns_clause" 1>&2
#    echo "## printf clause :  $printf_clause" 1>&2
    echo "## mutations_csv running key :  $mutations_csv_running_key" 1>&2

    echo "## executing: $mt_vcf_gt_filter_cmd" 1>&2
    eval $mt_vcf_gt_filter_cmd

    # ---------- join master data with mt_vcf_gt ----------
    # generate join header
    tmp_build_mutations_join=$tmp_file_prefix"_build_mutations_join"
    IFS=$'\t' read -ra tmp_mt_vcf_gt_patient_codes <<< "$( head -1 $tmp_mt_vcf_gt_filtered )"
    build_mutations_join_header=$( grep "^#" $join_master_data | head -1 )
    for (( j=1; j<=$((${#tmp_mt_vcf_gt_patient_codes[@]})); j++ ))
    do
	IFS='-' read -ra tmp_full_mt_vcf_gt_patient_code <<< "${tmp_mt_vcf_gt_patient_codes[$j]}"
	build_mutations_join_header+="\t${tmp_full_mt_vcf_gt_patient_code[1]}"
    done
    echo -e "$build_mutations_join_header" > $tmp_build_mutations_join

    # generate join content
    # prepare clauses
    n_col_master_data=$( grep "^#" $join_master_data | head -1 | awk -F'\t' '{ printf NF }' )
    n_col_mt_vcf_gt_filtered=$( grep "^#" $tmp_mt_vcf_gt_filtered | head -1 | awk -F'\t' '{ printf NF }' )
    build_mutations_join_format_first_clause="1.1"
    for (( j=2; j<=$n_col_master_data; j++ ))
    do
	build_mutations_join_format_first_clause+=",1.$j"
    done
    build_mutations_join_format_second_clause="2.2"
    for (( j=3; j<=$n_col_mt_vcf_gt_filtered; j++ ))
    do
	build_mutations_join_format_second_clause+=",2.$j"
    done

    # join content
    build_mutations_join_content_cmd="join -t $'\t' -1 1 -2 1 -o $build_mutations_join_format_first_clause,$build_mutations_join_format_second_clause <( grep -v \"^#\" $join_master_data ) <( grep -v \"^#\" $tmp_mt_vcf_gt_filtered | sort -t$'\t' -k1,1 ) | sort -t$'\t' -k1,1 >> $tmp_build_mutations_join"
    echo "##" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> join with $tmp_mt_vcf_gt_filtered <<<<<<<<<<<<<<<<<<<<" 1>&2
    echo "## executing: $build_mutations_join_content_cmd" 1>&2
    eval $build_mutations_join_content_cmd

    cat $tmp_build_mutations_join
}

#---------- generate csv files --------------
# individuals
for (( i=0; i<$((${#array_full_patient_codes[@]})); i++ ))
do
    out_individual_mutations_csv[$i]=$out_dir/"$running_key"_fam"$family_code"_"${array_full_patient_codes[$i]}".tab.csv

    echo "" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> generating csv for individual mutation of patient ${array_full_patient_codes[$i]} <<<<<<<<<<<<<<<<<<<<" 1>&2
    build_mutations_csv $tmp_join ${patient_idxs[$i]} > ${out_individual_mutations_csv[$i]}
done

if [ $number_of_patients -gt 1 ]; then
    out_common_mutations_csv=$out_dir/"$running_key"_fam"$family_code"_common_mutations.tab.csv
    
    echo "" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> gerating csv for common mutation <<<<<<<<<<<<<<<<<<<<" 1>&2
    build_mutations_csv $tmp_join $patient_idx_list > $out_common_mutations_csv
fi
#---------- generate csv files --------------

##---------- generate output xls file --------------
python_cmd="python $CSVS2XLS"
python_cmd+=" -C \"0,10\""
python_cmd+=" -F $((COL_OAF_INSERTING-1)):$oaf_ratio,$COL_OAF_INSERTING:$maf_ratio"
python_cmd+=" --coding_only"
python_cmd+=" -s ${array_displayed_patient_codes[0]},${out_individual_mutations_csv[0]}"
for (( i=1; i<$((${#out_individual_mutations_csv[@]})); i++ ))
do
    python_cmd+=":${array_displayed_patient_codes[$i]},${out_individual_mutations_csv[$i]}"
done
if [ $number_of_patients -gt 1 ]; then
    python_cmd+=":shared,$out_common_mutations_csv"
fi
python_cmd+=" -o $out_file"
if [ ! -z "$vcf_region" ]; then
    marked_key_range=$( vcf_region_to_key_range "$vcf_region" )
    python_cmd+=" -R \"$marked_key_range\""
fi
echo "##" 1>&2
echo "## >>>>>>>>>>>>>>>>>>>> convert csvs to xls <<<<<<<<<<<<<<<<<<<<" 1>&2
echo "## executing: $python_cmd" 1>&2
eval $python_cmd
#---------- generate output xls file --------------


echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
