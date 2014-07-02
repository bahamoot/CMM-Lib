#!/bin/bash

script_name=$(basename $0)

#define default values
COL_NAMES_DEFAULT=""
VCF_REGION_DEFAULT=""
MUTATED_ONLY_DEFAULT="no"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-k {project name}  specify primary key for running this script (required)
-t {file}          specify tabix file (required)
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
while getopts ":k:t:A:R:c:Mo:" OPTION; do
  case "$OPTION" in
    k)
      running_key="$OPTARG"
      ;;
    t)
      tabix_file="$OPTARG"
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
      die "unrecognized option from executing: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specfify running key"
[ ! -z $tabix_file ] || die "Please specify tabix file"
[ ! -z $out_file ] || die "Please specify output file"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_names=$COL_NAMES_DEFAULT}
: ${mutated_only=$MUTATED_ONLY_DEFAULT}

function display_param {
    PARAM_PRINT_FORMAT="##   %-35s%s\n"
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
echo "##   A script to create vgt database file" 1>&2
echo "##" 1>&2
echo "##" 1>&2
## display required configuration
echo "## overall configuration" 1>&2
display_param "running key (-k)" "$running_key"
display_param "tabix file (-t)" "$tabix_file"

## display optional configuration
echo "##" 1>&2
echo "## optional configuration" 1>&2
if [ ! -z "$col_names" ]; then
    display_param "column names (-c)" "$col_names"
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
display_param "mutated genotype only" "$mutated_only"

## display output configuration
echo "##" 1>&2
echo "## output configuration" 1>&2
display_param "out file (-o)" "$out_file"
#echo "##   working dir:           $working_dir" 1>&2

## ****************************************  executing  ****************************************
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
    header_rec=$( zcat $tabix_file | grep "^#C" )
    IFS=$'\t' read -ra col_list <<< "$header_rec"
    for (( i=$IDX_0_GT_COL; i<$((${#col_list[@]})); i++ ))
    do
	vcf_gt_header+="\t${col_list[$i]}"
    done
fi
echo -e "$vcf_gt_header" > $out_file

function generate_vcf_gt_content {
    region=$1
    
    vcf_query_cmd="vcf-query "
    if [ ! -z "$region" ]; then
        vcf_query_cmd+=" -r $region"
    fi
    if [ ! -z "$col_names" ]; then
        vcf_query_cmd+=" -c $col_names"
    fi
    vcf_query_cmd+=" -f '%CHROM\t%POS\t%ID\t%REF\t%ALT\t%QUAL\t%FILTER\t%INFO\t%FORMAT[\t%GT]\n' $tabix_file "
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

        # split ALT field in case that there are more than one alternate alleles
        # for all ALT
        IFS=',' read -ra alt <<< "$alt_list"
        for (( i=0; i<$((${#alt[@]})); i++ ))
        do
            number_re='^[0-9]+$'
            if ! [[ $chr =~ $number_re ]] ; then
                rec_out=$( printf "%s_%012d_%s_%s" $chr $pos $ref ${alt[$i]} )
            else
                rec_out=$( printf "%02d_%012d_%s_%s" $chr $pos $ref ${alt[$i]} )
            fi
            # for all GT fields
            for (( j=$IDX_0_GT_COL; j<$((${#rec_col[@]})); j++ ))
            do
                IFS='/' read -ra gt <<< "${rec_col[$j]}"
                if [ $mutated_only = "yes" ]; then
                    out_gt="."
                    # for both chromosomes
                    for (( k=0; k<$((${#gt[@]})); k++ ))
                    do
                        if [ ${gt[$k]} = ${alt[$i]} ]
        	            then
        	                if [ ${gt[0]} = ${gt[1]} ]
        	                then
                                out_gt="hom"
                            else
                                out_gt="het"
                            fi
                        fi
                    done
                    if [ "$out_gt" = "." ] && [ "${gt[0]}" = "${gt[1]}" ] && [ "${gt[0]}" = "$ref" ]
                    then
        	            out_gt="wt"
                    elif [ "$out_gt" = "." ] && [ "${gt[0]}" != "." ] && [ "${gt[1]}" != "." ]
                    then
        	            out_gt="oth"
                    fi
                    rec_out+="\t$out_gt"
                else
                    rec_out+="\t${rec_col[$j]}"
                fi
            done
            echo -e "$rec_out" >> $out_file
        done
    done
}

##generate vcf-gt content
if [ ! -z "$vcf_region" ]; then
    for (( n=0; n<$((${#vcf_region_list[@]})); n++ ))
    do
        generate_vcf_gt_content "${vcf_region_list[$n]}"
    done
else
    generate_vcf_gt_content ""
fi

echo "##" 1>&2
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
