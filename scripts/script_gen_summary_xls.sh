#!/bin/bash

script_name=$(basename $0)

#define default values
GT_VCF_GT_IN_DEFAULT=""
MT_VCF_GT_IN_DEFAULT=""
VCF_REGION_DEFAULT=""
EXONIC_FILTERING_DEFAULT="Off"
MISSENSE_FILTERING_DEFAULT="Off"
DELETERIOUS_FILTERING_DEFAULT="Off"
RARE_FILTERING_DEFAULT="Off"
OAF_RATIO_DEFAULT="0.1"
MAF_RATIO_DEFAULT="0.1"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-k {name}          specify a name that will act as unique keys of temporary files and default name for unspecified output file names (required)
-O {file}          specify oaf input file name (required)
-G {file}          specify input file name of genotyping db generated from vcf (default:NONE)
-M {file}          specify input file name of mutated GT db generated from vcf (default:NONE)
-S {file}          specify input file name of summarize annovar database (required)
-R {region}        specify vcf region of interest (default:None)
-A {float}         specify OAF criteria for rare mutations (default:0.1)
-F {float}         specify MAF criteria for rare mutations (default:0.1)
-e                 having a suggesting sheet with only exonic mutations
-m                 having a suggesting sheet with only missense mutations
-d                 having a suggesting sheet with only deleterious mutations
-r                 having a suggesting sheet with only rare mutations (using OAF and MAF criteria)
-o {directory}     specify output directory (required)
-w {directory}     specify working directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

# parse option
while getopts ":k:O:G:M:S:R:A:F:emdro:w:" OPTION; do
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
    R)
      vcf_region="$OPTARG"
      ;;
    A)
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
[ ! -z $oaf_in_file ] || die "Please specify oaf input file name"
[ ! -z $sa_in_file ] || die "Please specify summarize annovar input file name"
[ ! -z $out_dir ] || die "Please specify an output file name"
[ ! -z $working_dir ] || die "Please specify a working directory"
[ -f $oaf_in_file ] || die "$oaf_in_file is not a valid file name"
[ -f $sa_in_file ] || die "$sa_in_file is not a valid file name"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$out_dir is not a valid directory"

#setting default values:
: ${gt_vcf_gt_in_file=$GT_VCF_GT_IN_DEFAULT}
: ${mt_vcf_gt_in_file=$MT_VCF_GT_IN_DEFAULT}
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${exonic_filtering=$EXONIC_FILTERING_DEFAULT}
: ${missense_filtering=$MISSENSE_FILTERING_DEFAULT}
: ${deleterious_filtering=$DELETERIOUS_FILTERING_DEFAULT}
: ${rare_filtering=$RARE_FILTERING_DEFAULT}
: ${oaf_ratio=$OAF_RATIO_DEFAULT}
: ${maf_ratio=$MAF_RATIO_DEFAULT}

out_file="$out_dir/$running_key"_summary.xls

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

## ****************************************  display configuration  ****************************************
## display required configuration
echo "##" 1>&2
echo "## ************************************************** S T A R T <$script_name> **************************************************" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to join pre-computed mutations database and then generate excel sheet reporting summary information" 1>&2
echo "##" 1>&2
echo "## overall configuration" 1>&2
display_param "running key (-k)" "$running_key"
display_param "core annotation file (-S)" "$sa_in_file"
display_param "oaf input file (-O)" "$oaf_in_file"
display_param "output file" "$out_file"
display_param "working directory (-w)" "$working_dir"

## display optional configuration
echo "##" 1>&2
echo "## input configuration" 1>&2
if [ ! -z "$gt_vcf_gt_in_file" ]; then
    display_param "genotyped vcf gt input file (-G)" "$gt_vcf_gt_in_file"
fi
if [ ! -z "$mt_vcf_gt_in_file" ]; then
    display_param "mutated vcf gt input file (-M)" "$mt_vcf_gt_in_file"
fi
if [ ! -z "$vcf_region" ]; then
    display_param "vcf region (-R)" "$vcf_region"
fi

if [ "$suggesting_sheet" = "True" ]; then
    ## display suggesting-sheet configuration
    echo "##" 1>&2
    echo "## suggesting-sheet configuration" 1>&2
    display_param "filter exonic mutations" "$exonic_filtering"
    display_param "filter missense mutations" "$missense_filtering"
    display_param "filter deleterious mutations" "$deleterious_filtering"
    display_param "filter rare mutations" "$rare_filtering"
fi

## display other configuration
echo "##" 1>&2
echo "## other configuration" 1>&2
display_param "oaf ratio" "$oaf_ratio"
display_param "maf ratio" "$maf_ratio"

## ****************************************  executing  ****************************************
tmp_rearrange="$working_dir/tmp_rearrange"
tmp_oaf="$working_dir/tmp_oaf"
tmp_mt_vcf_gt="$working_dir/tmp_mt_vcf_gt"
tmp_gt_vcf_gt="$working_dir/tmp_gt_vcf_gt"
tmp_sed="$working_dir/tmp_sed"
tmp_join="$working_dir/tmp_join"
tmp_suggesting_sheet="$working_dir/tmp_suggesting_sheet"

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
#---------- join oaf --------------

function summary_general_join {
    join_master_data=$1
    join_addon_data=$2

    tmp_summary_general_join="$working_dir/tmp_summary_general_join"

    # generate header
    IFS=$'\t' read -ra header_addon_data <<< "$( grep "^#" $join_addon_data | head -1 )"
    summary_general_join_header=$( grep "^#" $join_master_data | head -1 )
    for (( i=1; i<=$((${#header_addon_data[@]})); i++ ))
    do
	summary_general_join_header+="\t${header_addon_data[$i]}"
    done
    echo -e "$summary_general_join_header" > $tmp_summary_general_join

    # generate data
    # prepare clauses
    n_col_master_data=$( grep "^#" $join_master_data | head -1 | awk -F'\t' '{ printf NF }' )
    n_col_addon_data=$( grep "^#" $join_addon_data | head -1 | awk -F'\t' '{ printf NF }' )
    summary_general_join_format_first_clause="1.1"
    for (( i=2; i<=$n_col_master_data; i++ ))
    do
	summary_general_join_format_first_clause+=",1.$i"
    done
    summary_general_join_format_second_clause="2.2"
    for (( i=3; i<=$n_col_addon_data; i++ ))
    do
	summary_general_join_format_second_clause+=",2.$i"
    done

    # join content
    summary_general_join_content_cmd="join -t $'\t' -a 1 -1 1 -2 1 -o $summary_general_join_format_first_clause,$summary_general_join_format_second_clause <( grep -v \"^#\" $join_master_data ) <( grep -v \"^#\" $join_addon_data | sort -t$'\t' -k1,1 ) | sort -t$'\t' -k1,1 >> $tmp_summary_general_join"
    echo "##" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> join with $join_addon_data <<<<<<<<<<<<<<<<<<<<" 1>&2
    echo "## executing: $summary_general_join_content_cmd" 1>&2
    eval $summary_general_join_content_cmd

    cmd="cp $tmp_summary_general_join $join_master_data"
    eval $cmd

    echo $(( n_col_addon_data - 1 ))
}


#---------- join mt vcf gt --------------
if [ ! -z "$mt_vcf_gt_in_file" ]; then
    n_col_mt_vcf_gt=$( summary_general_join $tmp_join $mt_vcf_gt_in_file )
fi
#---------- join gt vcf gt --------------

#---------- join gt vcf gt --------------
if [ ! -z "$gt_vcf_gt_in_file" ]; then
    n_col_gt_vcf_gt=$( summary_general_join $tmp_join $gt_vcf_gt_in_file )
fi
#---------- join gt vcf gt --------------

#---------- generate suggesting sheet if any --------------
if [ "$suggesting_sheet" = "True" ]; then

    echo "##" 1>&2
    echo "## >>>>>>>>>>>>>>>>>>>> generate with suggesting sheet <<<<<<<<<<<<<<<<<<<<" 1>&2
    cmd="cp $tmp_join $tmp_suggesting_sheet"
    eval $cmd

    if [ "$exonic_filtering" = "On" ]; then
	tmp_suggesting_sheet_exonic_filtering="$working_dir/tmp_suggesting_sheet_exonic_filtering"

	exonic_filtering_cmd="awk -F'\t' '{ if (\$$COL_SA_EXONICFUNC != \"\") print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_exonic_filtering"
	echo "## executing: $exonic_filtering_cmd" 1>&2
	eval $exonic_filtering_cmd

	cmd="cp $tmp_suggesting_sheet_exonic_filtering $tmp_suggesting_sheet"
    	eval $cmd
    fi
    if [ "$missense_filtering" = "On" ]; then
	tmp_suggesting_sheet_missense_filtering="$working_dir/tmp_suggesting_sheet_missense_filtering"

	missense_filtering_cmd="awk -F'\t' '{ if ((\$$COL_SA_EXONICFUNC != \"\") && (\$$COL_SA_EXONICFUNC != \"unknown\") && (\$$COL_SA_EXONICFUNC != \"synonymous SNV\")) print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_missense_filtering"
	echo "## executing: $missense_filtering_cmd" 1>&2
	eval $missense_filtering_cmd

	cmd="cp $tmp_suggesting_sheet_missense_filtering $tmp_suggesting_sheet"
    	eval $cmd
    fi
    if [ "$deleterious_filtering" = "On" ]; then
	tmp_suggesting_sheet_deleterious_filtering="$working_dir/tmp_suggesting_sheet_deleterious_filtering"

	deleterious_filtering_cmd="awk -F'\t' '{ if ((\$$COL_SA_EXONICFUNC != \"\") && (\$$COL_SA_EXONICFUNC != \"nonsynonymous SNV\") && (\$$COL_SA_EXONICFUNC != \"unknown\") && (\$$COL_SA_EXONICFUNC != \"synonymous SNV\")) print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_deleterious_filtering"
	echo "## executing: $deleterious_filtering_cmd" 1>&2
	eval $deleterious_filtering_cmd

	cmd="cp $tmp_suggesting_sheet_deleterious_filtering $tmp_suggesting_sheet"
    	eval $cmd
    fi
#    if [ "$rare_filtering" = "On" ]; then
#	tmp_suggesting_sheet_rare_filtering="$working_dir/tmp_suggesting_sheet_rare_filtering"
#
#	rare_filtering_cmd="awk -F'\t' '{ if ((\$$COL_SA_EXONICFUNC != \"\") && (\$$COL_SA_EXONICFUNC != \"unknown\") && (\$$COL_SA_EXONICFUNC != \"synonymous SNV\")) print \$0 }' $tmp_suggesting_sheet > $tmp_suggesting_sheet_rare_filtering"
#	echo "## executing: $rare_filtering_cmd" 1>&2
#	eval $rare_filtering_cmd
#
#	cmd="cp $tmp_suggesting_sheet_rare_filtering $tmp_suggesting_sheet"
#    	eval $cmd
#    fi
fi
#---------- generate suggesting sheet if any --------------
#---------- remove 'other' from tmp_join --------------
sed "s/\toth/\t/Ig" $tmp_join > $tmp_sed
cp $tmp_sed $tmp_join
#---------- remove 'other' from tmp_join --------------
##---------- generate output xls file --------------
python_cmd="python $CSVS2XLS"
# set indexes of column to be hidden
python_cmd+=" -C \"0,10,13,14,15,16,17,18,19,20,21,22\""
# set frequencies ratio to be highlighted
python_cmd+=" -F $((COL_OAF_INSERTING-1)):$oaf_ratio,$COL_OAF_INSERTING:$maf_ratio"
# set raw input sheets together with their names
sheets_param_value="all,$tmp_join"
if [ "$suggesting_sheet" = "True" ]; then
    sheets_param_value+=":suggested,$tmp_suggesting_sheet"
fi
python_cmd+=" -s $sheets_param_value"
python_cmd+=" -o $out_file"
if [ ! -z "$vcf_region" ]; then
    marked_key_range=$( vcf_region_to_key_range "$vcf_region" )
    python_cmd+=" -R \"$marked_key_range\""
fi
python_cmd+=" -c $n_col_main,$(( n_col_main+n_col_mt_vcf_gt ))"
echo "##" 1>&2
echo "## >>>>>>>>>>>>>>>>>>>> convert csvs to xls <<<<<<<<<<<<<<<<<<<<" 1>&2
echo "## executing: $python_cmd" 1>&2
eval $python_cmd
#---------- generate output xls file --------------


echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
