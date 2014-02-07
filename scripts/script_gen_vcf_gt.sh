#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

working_dir=$WORKING_DIR

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

#define default values
COL_NAMES_DEFAULT=""
VCF_REGION_DEFAULT=""
MUTATED_ONLY_DEFAULT="no"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-p {name}          specify project name (required)
-v {file}          specify vcf.gz file (required)
-R {region}        specify vcf region to be exported (default:all)
-c {patient list}  specify vcf columns to exported (default:all)
-M                 only mutated genotypes are exported
-o {file}          specify output file (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts ":p:v:R:c:Mo:" OPTION; do
  case "$OPTION" in
    p)
      project_name="$OPTARG"
      ;;
    v)
      vcf_gz_file="$OPTARG"
      ;;
    R)
      vcf_region="$OPTARG"
      ;;
    c)
      col_names="$OPTARG"
      ;;
    M)
      mutated_only="yes"
      ;;
    o)
      out_file="$OPTARG"
      ;;
    *)
      die "unrecognized option"
      ;;
  esac
done

[ ! -z $project_name ] || die "Please specfify project name"
[ ! -z $vcf_gz_file ] || die "Please specify vcf.gz file"
[ ! -z $out_file ] || die "Please specify output file"
[ -f $vcf_gz_file ] || die "$vcf_gz_file is not a valid file name"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_names=$COL_NAMES_DEFAULT}
: ${mutated_only=$MUTATED_ONLY_DEFAULT}

project_running_key="$project_name"_mutated_"$mutated_only"

out_dir=$VCF_GT_OUT_DIR

echo "##" 1>&2
echo "##" 1>&2
echo "## overall configuration" 1>&2
echo "##   project:               $project_name" 1>&2
echo "##   running key:           $project_running_key" 1>&2
echo "##   working dir:           $working_dir" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   vcf gz file:           $vcf_gz_file" 1>&2
if [ ! -z "$col_names" ]; then
    echo "##   column names:          $col_names" 1>&2
else
    echo "##   column names:          All" 1>&2
fi
echo "##   mutated genotype only: $mutated_only" 1>&2
echo "##   out dir:               $out_dir" 1>&2
echo "##   out file:              $out_file" 1>&2

#display region information
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
    echo "##   input region:          $vcf_region" 1>&2
    echo "##   chrom:                 $chrom" 1>&2
    echo "##   start pos:             $start_pos" 1>&2
    echo "##   end pos:               $end_pos" 1>&2
fi

IDX_0_CHR_COL=0
IDX_0_POS_COL=1
IDX_0_REF_COL=3
IDX_0_ALT_COL=4
IDX_0_GT_COL=9

#generate vcf-gt header
vcf_gt_header="#key"
if [ ! -z "$col_names" ]; then
    IFS=',' read -ra col_list <<< "$col_names"
    for (( i=0; i<$((${#col_list[@]})); i++ ))
    do
	vcf_gt_header+="\t${col_list[$i]}"
    done
else
    header_rec=$( zcat $vcf_gz_file | grep "^#C" )
    IFS=$'\t' read -ra col_list <<< "$header_rec"
    for (( i=$IDX_0_GT_COL; i<$((${#col_list[@]})); i++ ))
    do
	vcf_gt_header+="\t${col_list[$i]}"
    done
fi
echo -e "$vcf_gt_header" > $out_file

#generate vcf-gt content
vcf_query_cmd="vcf-query "
if [ ! -z "$vcf_region" ]; then
    vcf_query_cmd+=" -r $vcf_region"
fi
if [ ! -z "$col_names" ]; then
    vcf_query_cmd+=" -c $col_names"
fi
vcf_query_cmd+=" -f '%CHROM\t%POS\t%ID\t%REF\t%ALT\t%QUAL\t%FILTER\t%INFO\t%FORMAT[\t%GT]\n' $vcf_gz_file "
echo "##" 1>&2
echo "##" 1>&2
echo "## generating vcf genotyping using data from $vcf_query_cmd" 1>&2
eval "$vcf_query_cmd" | 
while read rec_in; do
    #parse input vcf record into vcf columns
    IFS=$'\t' read -ra rec_col <<< "$rec_in"
    chr=${rec_col[$IDX_0_CHR_COL]}
    pos=${rec_col[$IDX_0_POS_COL]}
    ref=${rec_col[$IDX_0_REF_COL]}
    alt_list=${rec_col[$IDX_0_ALT_COL]}

    #split ALT field in case that there are more than one alternate alleles
    IFS=',' read -ra alt <<< "$alt_list"
    for (( i=0; i<$((${#alt[@]})); i++ ))
    do
        rec_out=$( printf "%02d|%012d|%s|%s" $chr $pos $ref ${alt[$i]} )
        raw_out="$alt_list\t${alt[$i]}"
        for (( j=$IDX_0_GT_COL; j<$((${#rec_col[@]})); j++ ))
        do
            IFS='/' read -ra gt <<< "${rec_col[$j]}"
	    if [ $mutated_only = "yes" ]; then
		out_gt="."
            	for (( k=0; k<$((${#gt[@]})); k++ ))
            	do
            	    if [ ${gt[$k]} = ${alt[$i]} ]; then
            	        out_gt="${rec_col[$j]}"
            	    fi
            	done
            	rec_out+="\t$out_gt"
	    else
		rec_out+="\t${rec_col[$j]}"
	    fi
            raw_out+="\t${rec_col[$j]}"
        done
        echo -e "$rec_out" >> $out_file
    done
done

