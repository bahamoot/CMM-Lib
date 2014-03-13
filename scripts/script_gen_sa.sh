#!/bin/bash

script_name=$(basename $0)

#define default values
VCF_REGION_DEFAULT=""
COL_NAMES_DEFAULT=""

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-k {name}          specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-t {file}          specify a tabix vcf file (required)
-A {file}          specify annovar root directory (required)
-R {region}        specify vcf region of interest (default:all)
-c {patient list}  specify vcf columns to exported (default:all)
-o {out file}      specify output file name (required)
-w {dir}           specify working directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts ":k:t:A:R:c:o:w:" OPTION; do
  case "$OPTION" in
    k)
      running_key="$OPTARG"
      ;;
    t)
      tabix_file="$OPTARG"
      ;;
    A)
      annovar_root_dir="$OPTARG"
      ;;
    R)
      vcf_region="$OPTARG"
      ;;
    c)
      col_names="$OPTARG"
      ;;
    o)
      out_file="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    *)
      die "unrecognized option from executing:: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specfify a unique key for this run"
[ ! -z $tabix_file ] || die "Please specfify a tabix vcf file"
[ ! -z $annovar_root_dir ] || die "Please specify an annovar file"
[ ! -z $out_file ] || die "Please specify an output file name"
[ ! -z $working_dir ] || die "Please specify a working directory"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_names=$COL_NAMES_DEFAULT}

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

function display_param {
    PARAM_PRINT_FORMAT="##   %-32s%s\n"
    param_name=$1
    param_val=$2

    printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val" 1>&2
}

## ****************************************  display configuration  ****************************************
echo "##" 1>&2
echo "## ************************************************** S T A R T <$script_name> **************************************************" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to create summarize annovar database file" 1>&2
echo "##" 1>&2
## display required configuration
echo "## overall configurations" 1>&2
display_param "running key (-k)" "$running_key"
display_param "tabix file" "$tabix_file"
display_param "annovar root directory (-t)" "$annovar_root_dir"
display_param "output file" "$out_file"
display_param "working directory (-w)" "$working_dir"

## display optional configuration
echo "##" 1>&2
echo "## optional configurations" 1>&2
if [ ! -z "$col_names" ]; then
    display_param "column names" "$col_names"
else
    display_param "column names" "ALL"
fi
if [ ! -z "$vcf_region" ]; then
    display_param "vcf region (-R)" "$vcf_region"
    IFS=$',' read -ra vcf_region_list <<< "$vcf_region"
    if [ $((${#vcf_region_list[@]})) -gt 1 ]; then
	for (( i=0; i<$((${#vcf_region_list[@]})); i++ ))
    	do
    	    display_param "      region $(( i+1 ))" "${vcf_region_list[$i]}"
    	done
    fi
else
    display_param "vcf region" "ALL"
fi


## ****************************************  executing  ****************************************
tmp_vcf_query=$working_dir/$running_key"_tmp_vcf_query"
tmp_avdb_uniq=$working_dir/$running_key"_tmp_uniq.avdb"
avdb_individual_prefix=$working_dir/$running_key"_avdb_individual"
avdb_uniq=$working_dir/$running_key".uniq.avdb"
avdb_key=$working_dir/$running_key".key.avdb"
summarize_out=$working_dir/$running_key
csv_file=$summarize_out".genome_summary.csv"
tmp_tab_csv=$working_dir/$running_key"_tmp.tab.csv"


#---------- vcf2avdb --------------
IDX_0_GT_COL=9

#generate query header
query_header="#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT"
if [ ! -z "$col_names" ]; then
    IFS=',' read -ra col_list <<< "$col_names"
    for (( i=0; i<$((${#col_list[@]})); i++ ))
    do
	query_header+="\t${col_list[$i]}"
    done
else
    header_rec=$( zcat $tabix_file | grep "^#C" )
    IFS=$'\t' read -ra col_list <<< "$header_rec"
    for (( i=$IDX_0_GT_COL; i<$((${#col_list[@]})); i++ ))
    do
	query_header+="\t${col_list[$i]}"
    done
fi
echo -e "$query_header" > $tmp_vcf_query

function run_vcf_query {
    
    region=$1

    vcf_query_cmd="vcf-query "
    if [ ! -z "$region" ]; then
        vcf_query_cmd+=" -r $region"
    fi
    if [ ! -z "$col_names" ]; then
        vcf_query_cmd+=" -c $col_names"
    fi
    vcf_query_cmd+=" -f '%CHROM\t%POS\t%ID\t%REF\t%ALT\t%QUAL\t%FILTER\t%INFO\tGT[\t%GTR]\n' $tabix_file >> $tmp_vcf_query"
    echo "##" 1>&2
    echo "##" 1>&2
    echo "## generating vcf genotyping using data from $vcf_query_cmd" 1>&2
    eval "$vcf_query_cmd"
} 

if [ ! -z "$vcf_region" ]; then
    for (( i=0; i<$((${#vcf_region_list[@]})); i++ ))
    do
        run_vcf_query "${vcf_region_list[$i]}"
    done
else
    run_vcf_query ""
fi

convert2annovar="$annovar_root_dir/convert2annovar.pl -format vcf4 $tmp_vcf_query -include --allsample --outfile $avdb_individual_prefix"
echo "## executing: $convert2annovar" 1>&2
eval $convert2annovar

if [ -f "$tmp_avdb_uniq" ]; then
    rm $tmp_avdb_uniq
fi
for f in $avdb_individual_prefix*
do
    cut -f1-11 "$f" >> $tmp_avdb_uniq
done

sort $tmp_avdb_uniq | uniq > $avdb_uniq
#---------- vcf2avdb --------------


#---------- rearrange avdb and add key --------------
echo "##" 1>&2
add_key_to_avdb="grep -P \"^[0-9]\" $avdb_uniq | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%02d|%012d|%s|%s\n\", \$1, \$2, \$3, \$4, \$5, \$11, \$6, \$7, \$9, \$10 }' > $avdb_key"
echo "## executing: $add_key_to_avdb" 1>&2
eval $add_key_to_avdb
add_key_to_avdb="grep -vP \"^[0-9]\" $avdb_uniq | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s|%012d|%s|%s\n\", \$1, \$2, \$3, \$4, \$5, \$11, \$6, \$7, \$9, \$10 }' >> $avdb_key"
echo "## executing: $add_key_to_avdb" 1>&2
eval $add_key_to_avdb
#---------- rearrange avdb and add key --------------


#---------- summarize --------------
summarize_annovar="$annovar_root_dir/summarize_annovar.pl -out $summarize_out -buildver hg19 -verdbsnp 137 -ver1000g 1000g2012apr -veresp 6500 -remove -alltranscript $avdb_key $annovar_root_dir/humandb"
echo "## executing: $summarize_annovar" 1>&2
eval $summarize_annovar
#---------- summarize --------------


#---------- comma2tab --------------
csv_file=$summarize_out".genome_summary.csv"
comma2tab="perl -pe 'while (s/(,\"[^\"]+),/\1<COMMA>/g) {1}; s/\"//g; s/,/\t/g; s/<COMMA>/,/g' < $csv_file > $tmp_tab_csv"
echo "## executing: $comma2tab" 1>&2
eval $comma2tab
#---------- comma2tab --------------


#---------- move key to the first column --------------
IDX_1_SA_CSV_KEY_COL=28

awk_printf_format_clause="%s"
awk_printf_param_content_clause="\$$IDX_1_SA_CSV_KEY_COL"
awk_printf_param_header_clause="\"#Key\""
for (( i=1; i<$IDX_1_SA_CSV_KEY_COL; i++ ))
do
    awk_printf_format_clause+="\t%s"
    awk_printf_param_content_clause+=", \$$i"
    awk_printf_param_header_clause+=", \$$i"
done
awk_printf_format_clause+="\n"
move_key_cmd="sed -n 1p $tmp_tab_csv | awk -F'\t' '{printf \"$awk_printf_format_clause\", $awk_printf_param_header_clause }' > $out_file"
echo "## executing: $move_key_cmd" 1>&2
eval $move_key_cmd
move_key_cmd="grep -v \"^Func\" $tmp_tab_csv | awk -F'\t' '{printf \"$awk_printf_format_clause\", $awk_printf_param_content_clause }' >> $out_file"
echo "## executing: $move_key_cmd" 1>&2
eval $move_key_cmd
#---------- comma2tab --------------

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
