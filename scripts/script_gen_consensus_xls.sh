#!/bin/bash

#define default values
OAF_IN_DEFAULT=""
GT_VCF_GT_IN_DEFAULT=""
MT_VCF_GT_IN_DEFAULT=""

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-k {name}          specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-O {file}          specify oaf input file name (default:NONE)
-G {file}          specify input file name of genotyping db generated from vcf (default:NONE)
-M {file}          specify input file name of mutated GT db generated from vcf (default:NONE)
-S {file}          specify input file name of generating summarize annovar database (required)
-o {directory}     specify output directory (required)
-w {directory}     specify working directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts ":k:O:G:M:S:o:w:" OPTION; do
  case "$OPTION" in
    k)
      running_key="$OPTARG"
      ;;
    O)
      oaf_in_file="$OPTARG"
      ;;
    G)
      gt_vcf_gt_in_file="$OPTARG"
      ;;
    M)
      mt_vcf_gt_in_file="$OPTARG"
      ;;
    S)
      sa_in_file="$OPTARG"
      ;;
    o)
      out_dir="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    *)
      die "unrecognized option from executing: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specfify a unique key for this run"
[ ! -z $sa_in_file ] || die "Please specify summarize annovar input file name"
[ ! -z $out_dir ] || die "Please specify an output file name"
[ ! -z $working_dir ] || die "Please specify a working directory"
[ -f $sa_in_file ] || die "$sa_in_file is not a valid file name"
[ -d $out_dir ] || die "$out_dir is not a valid directory"

#setting default values:
: ${oaf_in_file=$OAF_IN_DEFAULT}
: ${gt_vcf_gt_in_file=$GT_VCF_GT_IN_DEFAULT}
: ${mt_vcf_gt_in_file=$MT_VCF_GT_IN_DEFAULT}

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

out_file="$out_dir/$running_key".xls

function display_param {
    PARAM_PRINT_FORMAT="##   %-40s%s\n"
    param_name=$1
    param_val=$2

    printf "$PARAM_PRINT_FORMAT" "$param_name"":" "$param_val" 1>&2
}

## ****************************************  display configuration  ****************************************
## display required configuration
echo "##" 1>&2
echo "## executing: $0 $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to join pre-computed mutations database and then generate excel sheet reporting consensus information" 1>&2
echo "##" 1>&2
echo "##" 1>&2
echo "## overall configuration" 1>&2
display_param "running key (-k)" "$running_key"
display_param "core annotation file (-S)" "$sa_in_file"
display_param "output file" "$out_file"
display_param "working directory (-w)" "$working_dir"

## display optional configuration
echo "##" 1>&2
echo "## input configuration" 1>&2
if [ ! -z "$oaf_in_file" ]; then
    display_param "oaf input file (-O)" "$oaf_in_file"
fi
if [ ! -z "$gt_vcf_gt_in_file" ]; then
    display_param "genotyped vcf gt input file (-G)" "$gt_vcf_gt_in_file"
fi
if [ ! -z "$mt_vcf_gt_in_file" ]; then
    display_param "mutated vcf gt input file (-M)" "$mt_vcf_gt_in_file"
fi

## ****************************************  executing  ****************************************
tmp_rearrange=$working_dir/tmp_rearrange
tmp_oaf=$working_dir/tmp_oaf
tmp_mt_vcf_gt=$working_dir/tmp_mt_vcf_gt
tmp_gt_vcf_gt=$working_dir/tmp_gt_vcf_gt
tmp_join=$working_dir/tmp_join

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
    echo "## executing: $join_oaf_header_cmd" 1>&2
    eval $join_oaf_header_cmd
    join_oaf_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $join_oaf_format_first_clause,2.2,$join_oaf_format_second_clause <( grep -v \"^#\" $tmp_join ) $oaf_in_file | sort -t$'\t' -k1,1 >> $tmp_oaf"
    echo "## executing: $join_oaf_content_cmd" 1>&2
    eval $join_oaf_content_cmd

    cp $tmp_oaf $tmp_join
fi
#---------- join oaf --------------

#---------- join gt vcf gt --------------
if [ ! -z "$gt_vcf_gt_in_file" ]; then
    IFS=$'\t' read -ra header_gt_vcf_gt <<< "$( grep "^#" $gt_vcf_gt_in_file | head -1 )"

    n_col_join=$( grep "^#" $tmp_join | head -1 | awk -F'\t' '{ printf NF }' )
    n_col_gt_vcf_gt=$( grep "^#" $gt_vcf_gt_in_file | head -1 | awk -F'\t' '{ printf NF }' )
    join_gt_vcf_gt_format_first_clause="1.1"
    for (( i=2; i<=$n_col_join; i++ ))
    do
	join_gt_vcf_gt_format_first_clause+=",1.$i"
    done
    join_gt_vcf_gt_format_second_clause="2.2"
    for (( i=3; i<=$n_col_gt_vcf_gt; i++ ))
    do
	join_gt_vcf_gt_format_second_clause+=",2.$i"
    done

    join_gt_vcf_gt_header=$( grep "^#" $tmp_join | head -1 )
    for (( i=1; i<=$((${#header_gt_vcf_gt[@]})); i++ ))
    do
	join_gt_vcf_gt_header+="\t${header_gt_vcf_gt[$i]}"
    done
    echo -e "$join_gt_vcf_gt_header" > $tmp_gt_vcf_gt
    join_gt_vcf_gt_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $join_gt_vcf_gt_format_first_clause,$join_gt_vcf_gt_format_second_clause <( grep -v \"^#\" $tmp_join ) <( grep -v \"^#\" $gt_vcf_gt_in_file | sort -t$'\t' -k1,1 ) | sort -t$'\t' -k1,1 >> $tmp_gt_vcf_gt"
    echo "##" 1>&2
    echo "## executing: $join_gt_vcf_gt_content_cmd" 1>&2
    eval $join_gt_vcf_gt_content_cmd

    cp $tmp_gt_vcf_gt $tmp_join
fi
#---------- join gt vcf gt --------------

#---------- join mt vcf gt --------------
if [ ! -z "$mt_vcf_gt_in_file" ]; then
    IFS=$'\t' read -ra header_mt_vcf_gt <<< "$( grep "^#" $mt_vcf_gt_in_file | head -1 )"

    n_col_join=$( grep "^#" $tmp_join | head -1 | awk -F'\t' '{ printf NF }' )
    n_col_mt_vcf_gt=$( grep "^#" $mt_vcf_gt_in_file | head -1 | awk -F'\t' '{ printf NF }' )
    join_mt_vcf_gt_format_first_clause="1.1"
    for (( i=2; i<=$n_col_join; i++ ))
    do
	join_mt_vcf_gt_format_first_clause+=",1.$i"
    done
    join_mt_vcf_gt_format_second_clause="2.2"
    for (( i=3; i<=$n_col_mt_vcf_gt; i++ ))
    do
	join_mt_vcf_gt_format_second_clause+=",2.$i"
    done

    join_mt_vcf_gt_header=$( grep "^#" $tmp_join | head -1 )
    for (( i=1; i<=$((${#header_mt_vcf_gt[@]})); i++ ))
    do
	join_mt_vcf_gt_header+="\t${header_mt_vcf_gt[$i]}"
    done
    echo -e "$join_mt_vcf_gt_header" > $tmp_mt_vcf_gt
    join_mt_vcf_gt_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $join_mt_vcf_gt_format_first_clause,$join_mt_vcf_gt_format_second_clause <( grep -v \"^#\" $tmp_join ) <( grep -v \"^#\" $mt_vcf_gt_in_file | sort -t$'\t' -k1,1 ) | sort -t$'\t' -k1,1 >> $tmp_mt_vcf_gt"
    echo "##" 1>&2
    echo "## executing: $join_mt_vcf_gt_content_cmd" 1>&2
    eval $join_mt_vcf_gt_content_cmd

    cp $tmp_mt_vcf_gt $tmp_join
fi
#---------- join gt vcf gt --------------


##---------- generate output xls file --------------
python_cmd="python $CSVS2XLS $out_file summary $tmp_join"
echo "" 1>&2
echo "## executing $python_cmd" 1>&2
eval $python_cmd
#---------- generate output xls file --------------
