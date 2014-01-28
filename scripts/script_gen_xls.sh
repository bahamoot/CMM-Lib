#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

working_dir=$script_dir/tmp

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

#define default values
SUB_PROJECT_NAME_DEFAULT=""
VCF_REGION_DEFAULT=""

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {name}          specify project name (required)
-s {name}          specify sub project name
-a {file}          specify annotation file (required)
-v {file}          specify vcf.gz file (required)
-R {region}        specify vcf region to be exported
-f {code}          specify family code (required)
-m {patient list}  specify list of family members (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts "p:s:a:v:R:f:m:" OPTION; do
  case "$OPTION" in
    p)
      project_name="$OPTARG"
      ;;
    s)
      sub_project_name="$OPTARG"
      ;;
    a)
      annotation_file="$OPTARG"
      ;;
    v)
      vcf_gz_file="$OPTARG"
      ;;
    R)
      region="$OPTARG"
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

[ ! -z $project_name ] || die "Please specfify project name"
[ ! -z $annotation_file ] || die "Please specify annoation file"
[ ! -z $vcf_gz_file ] || die "Please specify vcf.gz file"
[ ! -z $family_code ] || die "Please specify family code"
[ ! -z $member_list ] || die "Please specify codes of family members"
[ -f $vcf_gz_file ] || die "$vcf_gz_file is not a valid file name"
[ -f $annotation_file ] || die "$annotation_file is not a valid file name"

#setting default values:
: ${sub_project_name=$SUB_PROJECT_NAME_DEFAULT}
: ${vcf_region=$VCF_REGION_DEFAULT}

##---------- arguments --------------
#project_name=$1
#sub_project_name=$2
#sa_view_file=$3
#vcf_gz_file=$4
#chr=$5
#begin_pos=$6
#end_pos=$7
#family_code=$8
#
#patient_count=0
#declare -a args=("$@")
#for (( i=8; i<$((${#args[@]})); i++ ))
#do
#    patient_count=$((patient_count+1))
#    patient_code[$patient_count]="${args[$i]}"
#done
#
if [ ! -z "$sub_project_name" ]; then
    out_dir=$CMM_PROJECTS_ROOT_DIR/$project_name/$sub_project_name
    running_key="$project_name"_"$sub_project_name"
else
    out_dir=$CMM_PROJECTS_ROOT_DIR/$project_name
    running_key="$project_name"
fi

if [ ! -d "$CMM_PROJECTS_ROOT_DIR/$project_name" ]; then
    mkdir $CMM_PROJECTS_ROOT_DIR/$project_name
fi

if [ ! -d "$out_dir" ]; then
    mkdir $out_dir
fi
out_file=$out_dir/fam"$family_code".xls
##out_file=$out_dir/"$sub_project_name"_fam"$family_code".xls

#splite member list into array of patient codes
IFS=',' read -ra patient_code <<< "$member_list"

#for i in "${ADDR[@]}"; do
#        # process "$i"
#    done

##root_out_dir=
##working_dir=$script_dir/tmp
##sa_db_file=$CMM_AXEQ_CHR9_SA_DB
##vcf_gz_file=$CMM_AXEQ_CHR9_ALL_PATIENTS_GZ
##vcf_header_file=$CMM_AXEQ_CHR9_ALL_PATIENTS_HEADER
##tmp_sa_filtered=$working_dir/tmp_sa_filtered_for_"$project_name"_fam"$family_code"
##tmp_common_mutations_csv=$working_dir/"$project_name"_"$sub_project_name"_fam"$family_code"_common_mutations_tmp.tab.csv
##
##project_out_dir=$script_dir/../out/"$project_name"
##sub_project_out_dir=$project_out_dir/"$sub_project_name"
##out_dir=$sub_project_out_dir/"fam_"$family_code
##out_common_mutations_csv=$out_dir/"$sub_project_name"_fam"$family_code"_common_mutations.tab.csv
##out_file=$out_dir/"$sub_project_name"_fam"$family_code".xls

echo "##" 1>&2
echo "##" 1>&2
echo "## building an xls file for" 1>&2
echo "##   project:         $project_name" 1>&2
echo "##   sub project:     $sub_project_name" 1>&2
echo "##   running key:     $running_key" 1>&2
echo "##   working dir:     $working_dir" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   annotation_file: $annotation_file" 1>&2
echo "##   vcf gz file:     $vcf_gz_file" 1>&2
echo "##   region:          $region" 1>&2
echo "##   out dir:         $out_dir" 1>&2
echo "##   out file:        $out_file" 1>&2

#
###---------- get vcf columns from patient codes --------------
##function get_vcf_col {
##    grep "^#C" $1 | grep -i $2 | awk -va="$2" 'BEGIN{}
##    END{}
##    {
##        for(i=1;i<=NF;i++){
##            IGNORECASE = 1
##            if ( tolower($i) == tolower(a))
##                {print i }
##        }
##    }'
##}

#---------- get vcf columns from patient codes --------------

echo "##" 1>&2
echo "## family & members" 1>&2
echo "##   family code:     $family_code" 1>&2
for (( i=0; i<$((${#patient_code[@]})); i++ ))
do
#    patient_col[$i]=`get_vcf_col $vcf_header_file ${patient_code[$i]}`
    echo "##   patient code$i:   ${patient_code[$i]}" 1>&2
#    echo "## column:                 ${patient_col[$i]}" 1>&2
done

###---------- display sub project configuration --------------
##
##echo "##" 1>&2
##echo "## sub project configuration" 1>&2
##echo "## sub project name:       $sub_project_name" 1>&2
##echo "## chromosome:             $chrom" 1>&2
##echo "## min position:           $min_pos" 1>&2
##echo "## max position:           $max_pos" 1>&2
##
###---------- check if output directory exist --------------
##if [ ! -d "$project_out_dir" ]; then
##    mkdir $project_out_dir
##fi
##if [ ! -d "$sub_project_out_dir" ]; then
##    mkdir $sub_project_out_dir
##fi
##if [ ! -d "$out_dir" ]; then
##    mkdir $out_dir
##fi
###---------- check if output directory exist --------------

function join_sa_vcf_n_filter {
    vcf_keys_file=$1
    filtered_sa_file=$2
    tmp_dir=$3
    col_name=$4

    tmp_join_sa_vcf=$tmp_dir/tmp_join_sa_vcf_"$running_key"_"$col_name"

    echo "" 1>&2
    join_sa_vcf_clause="join -t $'\t' -1 1 -2 1 -o 2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,2.10,2.11,2.12,2.13,2.14,2.15,2.16,2.17,2.18,2.19,2.20,2.21,2.22,2.23,2.24,2.25,2.26,2.27,2.28,2.29,2.30,2.31,2.32,2.33,2.34"
    join_sa_vcf_cmd="$join_sa_vcf_clause <( sort -t\$'\t' -k1,1 $vcf_keys_file ) <( awk -F '\t' '{ printf \"%s\t%s\n\", \$28, \$0 }' $filtered_sa_file | sort -t\$'\t' -k1,1 | grep -v \"Func\") | sort -t\$'\t' -n -k28 > $tmp_join_sa_vcf"
    echo "## executing $join_sa_vcf_cmd" 1>&2
    eval $join_sa_vcf_cmd

    cat $tmp_join_sa_vcf
}
##
##function build_common_mutations_csv {
##    gz_file=$1
##    sa_file=$2
##    tmp_dir=$3
##    col1=$4
##    col2=$4
##    col3=$4
##
##    if [ $# -gt 4 ]; then
##        col2=$5
##    fi
##    if [ $# -gt 5 ]; then
##        col3=$6
##    fi
##
##    tmp_vcf_keys=$tmp_dir/tmp_vcf_keys_for_"$project_name"
##
##    echo "## ************************** Build commmon mutations *******************************" 1>&2
##    echo "## generate vcf keys for all mutations that there are mutations in any members of family $family_code" 1>&2
##    get_vcf_records_clause="tabix $gz_file $chrom":"$min_pos"-"$max_pos | grep -v \"^#\" | awk -F'\t' '{ if ((\$$col1 != \".\" && \$$col1 != \"./.\" && \$$col1 !~ \"0/0\") && (\$$col2 != \".\" && \$$col2 != \"./.\" && \$$col2 !~ \"0/0\") && (\$$col3 != \".\" && \$$col3 != \"./.\" && \$$col3 !~ \"0/0\")) print \$0 }'"
##    generate_vcf_keys_cmd="$get_vcf_records_clause | grep -P \"^[0-9]\" | awk -F'\t' '{ printf \"%02d|%012d|%s|%s\t%s\t%s\t%s\n\", \$1, \$2, \$4, \$5, \$$col1, \$$col2, \$$col3 }' > $tmp_vcf_keys"
##    echo "## executing $generate_vcf_keys_cmd" 1>&2
##    eval $generate_vcf_keys_cmd
##    generate_vcf_keys_cmd="$get_vcf_records_clause | grep -vP \"^[0-9]\" | awk -F'\t' '{ printf \"%s|%012d|%s|%s\t%s\t%s\t%s\n\", \$1, \$2, \$4, \$5, \$$col1, \$$col2, \$$col3 }' >> $tmp_vcf_keys"
##    echo "## executing $generate_vcf_keys_cmd" 1>&2
##    eval $generate_vcf_keys_cmd
##
##    join_sa_vcf_n_filter $tmp_vcf_keys $sa_file $tmp_dir
##}

function build_individual_mutations_csv {
    gz_file=$1
    sa_file=$2
    tmp_dir=$3
#    col=$4
    col_name=$4

    tmp_vcf_keys=$tmp_dir/tmp_vcf_keys_for_"$running_key"_"$col_name"

    echo "## ************************** Build individual mutations (col $col)*******************************" 1>&2
    echo "## generate vcf keys for individual mutations" 1>&2
#    get_vcf_records_clause="zcat $gz_file | grep -v \"^#\" | awk -F'\t' '{ if (\$$col != \".\" && \$$col !~ \"\\./\\.\" && \$$col !~ \"0/0\") print \$0 }'"
    get_vcf_records_clause="vcf-subset -c $col_name $gz_file | grep -v \"^#\" | awk -F'\t' '{ if (\$10 != \".\" && \$10 !~ \"0/0\") print \$0 }'"
#    get_vcf_records_clause="tabix $gz_file $region | grep -v \"^#\" | awk -F'\t' '{ if (\$$col != \".\" && \$$col !~ \"\\./\\.\" && \$$col !~ \"0/0\") print \$0 }'"
    generate_vcf_keys_cmd="$get_vcf_records_clause | grep -P \"^[0-9]\" | awk -F'\t' '{ printf \"%02d|%012d|%s|%s\t%s\n\", \$1, \$2, \$4, \$5, \$10 }' > $tmp_vcf_keys"
    echo "## executing $generate_vcf_keys_cmd" 1>&2
    eval $generate_vcf_keys_cmd
    generate_vcf_keys_cmd="$get_vcf_records_clause | grep -vP \"^[0-9]\" | awk -F'\t' '{ printf \"%s|%012d|%s|%s\t%s\n\", \$1, \$2, \$4, \$5, \$10 }' >> $tmp_vcf_keys"
    echo "## executing $generate_vcf_keys_cmd" 1>&2
    eval $generate_vcf_keys_cmd

    join_sa_vcf_n_filter $tmp_vcf_keys $sa_file $tmp_dir $col_name
}
##
###---------- filter annotation from summarize annovar --------------
##sed -n 1p $sa_db_file > $tmp_sa_filtered
##filter_sa="cat $sa_db_file   > $tmp_sa_filtered"
###filter_sa="grep \"^exon\" $sa_db_file | grep -vP \"\tsyn\" | awk -F'\t' '{ if (\$3 != \"unknown\" && \$3 != \"\") print \$0}'  >> $tmp_sa_filtered"
##echo "" 1>&2
##echo "## ************************** filter annotation from summarize annovar *******************************" 1>&2
##echo "## no filter" 1>&2
##echo "## executing $filter_sa" 1>&2
##eval $filter_sa
###---------- filter annotation from summarize annovar --------------

#---------- generate csv files --------------
# individuals
for (( i=0; i<$((${#patient_code[@]})); i++ ))
do
    tmp_individual_mutations_csv[$i]=$working_dir/"$project_name"_"$sub_project_name"_fam"$family_code"_"${patient_code[$i]}"_tmp.tab.csv
    out_individual_mutations_csv[$i]=$out_dir/"$sub_project_name"_fam"$family_code"_"${patient_code[$i]}".tab.csv

    echo "" 1>&2
    echo "## gerating csv for individual mutation of patient ${patient_code[$i]}" 1>&2
    sed -n 1p $annotation_file > ${tmp_individual_mutations_csv[$i]}
    build_individual_mutations_csv $vcf_gz_file $annotation_file $working_dir ${patient_code[$i]} >> ${tmp_individual_mutations_csv[$i]}
#    build_individual_mutations_csv $vcf_gz_file $annotation_file $working_dir ${patient_col[$i]} >> ${tmp_individual_mutations_csv[$i]}

    cmd="$SORT_N_AWK_CSV ${tmp_individual_mutations_csv[$i]}  > ${out_individual_mutations_csv[$i]}"
    eval $cmd
done

### common
##if [ $# -ge 7 ]; then
##    build_common_mutations_csv_cmd="build_common_mutations_csv $vcf_gz_file $tmp_sa_filtered $working_dir "
##    for (( i=1; i<=$((${#patient_code[@]})); i++ ))
##    do
##        build_common_mutations_csv_cmd+=" ${patient_col[$i]} "
##    done
##
##    echo "" 1>&2
##    echo "## gerating csv for common mutation" 1>&2
##    sed -n 1p $sa_db_file > $tmp_common_mutations_csv
##    build_common_mutations_csv_cmd+=" >> $tmp_common_mutations_csv"
##    eval $build_common_mutations_csv_cmd
##
##    cmd="$sort_n_awk_csv $tmp_common_mutations_csv > $out_common_mutations_csv"
##    eval $cmd
##fi
###---------- generate csv files --------------
##
###---------- generate output xls file --------------
##if [ $# -eq 6 ]; then
    python_cmd="python $CSV2XLS ${out_individual_mutations_csv[0]} ${patient_code[0]} $out_file"
    echo "" 1>&2
    echo "executing $python_cmd" 1>&2
    eval $python_cmd
##else
##    python_cmd="python $csvs2xls "
##    for (( i=1; i<=$((${#patient_code[@]})); i++ ))
##    do
##        python_cmd+=" ${out_individual_mutations_csv[$i]} ${patient_code[$i]} "
##    done
##    python_cmd+=" $out_common_mutations_csv $out_file"
##    echo "" 1>&2
##    echo "executing $python_cmd" 1>&2
##    eval $python_cmd
##fi
###---------- generate output xls file --------------
#
