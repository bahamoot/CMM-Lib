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
      annotation_input_file="$OPTARG"
      ;;
    v)
      vcf_gz_file="$OPTARG"
      ;;
    R)
      vcf_region="$OPTARG"
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
[ ! -z $annotation_input_file ] || die "Please specify annoation file"
[ ! -z $vcf_gz_file ] || die "Please specify vcf.gz file"
[ ! -z $family_code ] || die "Please specify family code"
[ ! -z $member_list ] || die "Please specify codes of family members"
[ -f $vcf_gz_file ] || die "$vcf_gz_file is not a valid file name"
[ -f $annotation_input_file ] || die "$annotation_input_file is not a valid file name"

#setting default values:
: ${sub_project_name=$SUB_PROJECT_NAME_DEFAULT}
: ${vcf_region=$VCF_REGION_DEFAULT}

if [ ! -z "$sub_project_name" ]; then
    sub_project_out_dir=$CMM_PROJECTS_OUTPUT_DIR/$project_name/$sub_project_name
    project_running_key="$project_name"_"$sub_project_name"
else
    sub_project_out_dir=$CMM_PROJECTS_OUTPUT_DIR/$project_name
    project_running_key="$project_name"
fi

out_dir=$sub_project_out_dir/"fam_"$family_code

if [ ! -d "$CMM_PROJECTS_OUTPUT_DIR/$project_name" ]; then
    mkdir $CMM_PROJECTS_OUTPUT_DIR/$project_name
fi

if [ ! -d "$sub_project_out_dir" ]; then
    mkdir $sub_project_out_dir
fi

if [ ! -d "$out_dir" ]; then
    mkdir $out_dir
fi
out_file=$out_dir/fam"$family_code".xls

#splite member list into array of patient codes
IFS=',' read -ra array_patient_codes <<< "$member_list"
number_of_patients=$((${#array_patient_codes[@]}))

echo "##" 1>&2
echo "##" 1>&2
echo "## building an xls file for" 1>&2
echo "##   project:         $project_name" 1>&2
echo "##   sub project:     $sub_project_name" 1>&2
echo "##   running key:     $project_running_key" 1>&2
echo "##   working dir:     $working_dir" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   annotation_input_file: $annotation_input_file" 1>&2
echo "##   vcf gz file:     $vcf_gz_file" 1>&2
echo "##   out dir:         $out_dir" 1>&2
echo "##   out file:        $out_file" 1>&2

#pick out the requested region from the annotation input file to increase performance
if [ ! -z "$vcf_region" ]; then
    IFS=':' read -ra tmp_split_chrom <<< "$vcf_region"
    chrom=${tmp_split_chrom[0]}
    IFS='-' read -ra tmp_split_pos <<< "${tmp_split_chrom[1]}"
    start_pos=${tmp_split_pos[0]}
    end_pos=${tmp_split_pos[1]}

    re='^[0-9]+$'
    if ! [[ $chrom =~ $re ]] ; then
	awk_start_pos="$( printf "%s|%012d" $chrom $((start_pos-1)) )"
	awk_end_pos="$( printf "%s|%012d" $chrom $((end_pos+1)) )"
    else
	awk_start_pos="$( printf "%02d|%012d" $chrom $((start_pos-1)) )"
	awk_end_pos="$( printf "%02d|%012d" $chrom $((end_pos+1)) )"
    fi
    echo "##" 1>&2
    echo "## region " 1>&2
    echo "##   input region:    $vcf_region" 1>&2
    echo "##   chrom:           $chrom" 1>&2
    echo "##   start pos:       $start_pos" 1>&2
    echo "##   end pos:         $end_pos" 1>&2

    annotation_processing_file=$working_dir/"$project_running_key"_tmp_annotation_procession.tab.csv
    sed -n 1p $annotation_input_file > $annotation_processing_file
    awk_cmd="awk -F'\t' '{ if ((\$28 > \"$awk_start_pos\") && (\$28 < \"$awk_end_pos\")) print \$0 }' $annotation_input_file >> $annotation_processing_file"
    eval $awk_cmd
else
    annotation_processing_file=$annotation_input_file
fi

echo "##" 1>&2
echo "## family & members" 1>&2
echo "##   family code:     $family_code" 1>&2
echo "##   patients count:  $number_of_patients" 1>&2
for (( i=0; i<$((${#array_patient_codes[@]})); i++ ))
do
    echo "##   patient code$((i+1)):   ${array_patient_codes[$i]}" 1>&2
done

function build_mutations_csv {
    col_names=$1

    #splite column names
    IFS=',' read -ra array_col_names <<< "$col_names"

    #prepare clauses which are varied according to number of patients
    awk_filter_clause=" awk -F'\t' '{ if ((\$10 != \".\" && \$10 != \"./.\" && \$10 !~ \"0/0\")"
    columns_clause="\$10"
    printf_clause="%s"
    mutations_csv_running_key=${array_col_names[0]}
    for (( j=2; j<=$((${#array_col_names[@]})); j++ ))
    do
        #echo "## j:  $j" 1>&2
	awk_filter_clause+=" && (\$$((j+9)) != \".\" && \$$((j+9)) != \"./.\" && \$$((j+9)) !~ \"0/0\")"
	columns_clause+=", \$$((j+9))"
	printf_clause+="\t%s"
	mutations_csv_running_key+="_"${array_col_names[$((j-1))]}
    done
    awk_filter_clause+=") print \$0 }'"

#    echo "## awk filter clause :  $awk_filter_clause" 1>&2
#    echo "## columns clause :  $columns_clause" 1>&2
#    echo "## printf clause :  $printf_clause" 1>&2
#    echo "## mutations_csv running key :  $mutations_csv_running_key" 1>&2

    #prepare region query clause
    if [ ! -z "$vcf_region" ]; then
	vcf_region_clause="vcf-query -r $vcf_region"
    else
	vcf_region_clause="vcf-query"
    fi

    tmp_file_prefix=$working_dir/"$project_running_key"_"$mutations_csv_running_key"_tmp
    tmp_vcf_keys=$tmp_file_prefix"_vcf_keys"
    tmp_join_sa_vcf=$tmp_file_prefix"_join_sa_vcf"

    echo "## ************************** Build mutations *******************************" 1>&2
    echo "## generating vcf keys for mutations in $col_names" 1>&2
    get_vcf_records_clause="$vcf_region_clause -c \"${col_names/"-"/\-}\" -f '%CHROM\t%POS\t%ID\t%REF\t%ALT\t%QUAL\t%FILTER\t%INFO\t%FORMAT[\t%GTR]\n' $vcf_gz_file | $awk_filter_clause "
    generate_vcf_keys_cmd="$get_vcf_records_clause | grep -P \"^[0-9]\" | awk -F'\t' '{ printf \"%02d|%012d|%s|%s\t$printf_clause\n\", \$1, \$2, \$4, \$5, $columns_clause }' > $tmp_vcf_keys"
    echo "## executing $generate_vcf_keys_cmd" 1>&2
    eval $generate_vcf_keys_cmd
    generate_vcf_keys_cmd="$get_vcf_records_clause | grep -vP \"^[0-9]\" | awk -F'\t' '{ printf \"%s|%012d|%s|%s\t$printf_clause\n\", \$1, \$2, \$4, \$5, $columns_clause }' >> $tmp_vcf_keys"
    echo "## executing $generate_vcf_keys_cmd" 1>&2
    eval $generate_vcf_keys_cmd

    sed -n 1p $annotation_processing_file > $tmp_join_sa_vcf
    echo "" 1>&2
    join_sa_vcf_clause="join -t $'\t' -1 1 -2 1 -o 2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,2.10,2.11,2.12,2.13,2.14,2.15,2.16,2.17,2.18,2.19,2.20,2.21,2.22,2.23,2.24,2.25,2.26,2.27,2.28,2.29,2.30,2.31,2.32,2.33,2.34"
    join_sa_vcf_cmd="$join_sa_vcf_clause <( sort -t\$'\t' -k1,1 $tmp_vcf_keys ) <( awk -F '\t' '{ printf \"%s\t%s\n\", \$28, \$0 }' $annotation_processing_file | sort -t\$'\t' -k1,1 | grep -v \"Func\") | sort -t\$'\t' -n -k28,28 >> $tmp_join_sa_vcf"
    echo "## executing $join_sa_vcf_cmd" 1>&2
    eval $join_sa_vcf_cmd

    $SORT_N_AWK_CSV $tmp_join_sa_vcf
}

#---------- generate csv files --------------
# individuals
for (( i=0; i<$((${#array_patient_codes[@]})); i++ ))
do
    out_individual_mutations_csv[$i]=$out_dir/"$project_running_key"_fam"$family_code"_"${array_patient_codes[$i]}".tab.csv

    echo "" 1>&2
    echo "## generating csv for individual mutation of patient ${array_patient_codes[$i]}" 1>&2
    build_mutations_csv ${array_patient_codes[$i]} > ${out_individual_mutations_csv[$i]}
done

if [ $number_of_patients -gt 1 ]; then
    out_common_mutations_csv=$out_dir/"$project_running_key"_fam"$family_code"_common_mutations.tab.csv
    
    echo "" 1>&2
    echo "## gerating csv for common mutation" 1>&2
    build_mutations_csv $member_list > $out_common_mutations_csv
fi
#---------- generate csv files --------------

##---------- generate output xls file --------------
if [ $number_of_patients -eq 1 ]; then

    python_cmd="python $CSV2XLS ${out_individual_mutations_csv[0]} ${array_patient_codes[0]} $out_file"

else
    python_cmd="python $CSV2XLS "
    for (( i=0; i<=$((${#array_patient_codes[@]})); i++ ))
    do
        python_cmd+=" ${out_individual_mutations_csv[$i]} ${array_patient_codes[$i]} "
    done
    python_cmd+=" $out_common_mutations_csv $out_file"
fi
echo "" 1>&2
echo "## executing $python_cmd" 1>&2
eval $python_cmd
#---------- generate output xls file --------------
