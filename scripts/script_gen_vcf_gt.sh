#!/bin/bash
source $CMM_LIB_DIR/cmm_functions.sh

script_name=$(basename $0)
params="$@"

dev_mode="On"

#define default values
COL_CONFIG_DEFAULT="ALL"
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
-c {patient list}  specify vcf columns to exported. This can be either in comma-separated format or it can be a file name (default:$COL_CONFIG_DEFAULT)
-M                 only mutated genotypes are exported
-w {directory}     specify working directory (required)
-o {file}          specify output file (required)
-l {file}          specify log file name (required)
EOF
)

while getopts ":k:t:A:R:c:Mw:o:l:" OPTION; do
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
      col_config="$OPTARG"
      ;;
    M)
      mutated_only="yes"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    o)
      out_file="$OPTARG"
      ;;
    l)
      running_log_file="$OPTARG"
      ;;
    *)
      die "unrecognized option from executing: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specfify running key"
[ ! -z $tabix_file ] || die "Please specify tabix file"
[ ! -z $working_dir ] || die "Plesae specify working directory (-w)"
[ ! -z $out_file ] || die "Please specify output file"
[ ! -z $running_log_file ] || die "Plesae specify where to keep log output (-l)"
[ -d $working_dir ] || die "$working_dir is not a valid directory"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"
[ -f $running_log_file ] || die "$running_log_file is not a valid file name"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_config=$COL_CONFIG_DEFAULT}
: ${mutated_only=$MUTATED_ONLY_DEFAULT}

time_stamp=$( date )

if [ "$col_config" == "$COL_CONFIG_DEFAULT" ]
then
    col_count=$( vcf-query -l $tabix_file | wc -l)
    parsed_col_names=""
else
    if [ -f "$col_config" ]
    then
        parsed_col_names=`paste -sd, $col_config`
    else
        parsed_col_names="$col_config"
    fi

    IFS=',' read -ra col_list <<< "$parsed_col_names"
    for (( i=0; i<$((${#col_list[@]})); i++ ))
    do
        col_exist=$( vcf_col_exist $tabix_file ${col_list[$i]} )
	    if [ "$col_exist" -ne 1 ]
	    then
	        die "column ${col_list[$i]} is not exist"
	    fi
    done
    col_count=${#col_list[@]}
fi

## ****************************************  display configuration  ****************************************
new_section_txt "S T A R T <$script_name>"
info_msg
info_msg "description"
info_msg "  A script to create vgt database file"
info_msg
info_msg "version and script configuration"
display_param "parameters" "$params"
display_param "time stamp" "$time_stamp"
info_msg
## display required configuration
info_msg "overall configuration"
display_param "running key (-k)" "$running_key"
display_param "tabix file (-t)" "$tabix_file"

## display optional configuration
info_msg
info_msg "optional configuration"
if [ ! -z "$parsed_col_names" ]; then
    display_param "column names (-c)" "$parsed_col_names"
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
info_msg
info_msg "output configuration"
display_param "out file (-o)" "$out_file"
display_param "working dir (-w)" "$working_dir"

## ****************************************  executing  ****************************************
IDX_0_CHR_COL=0
IDX_0_POS_COL=1
IDX_0_REF_COL=3
IDX_0_ALT_COL=4
IDX_0_GT_COL=9

#generate vcf-gt header
vcf_gt_header="#key"
if [ ! -z "$parsed_col_names" ]; then
    IFS=',' read -ra col_list <<< "$parsed_col_names"
    for (( i=0; i<$((${#col_list[@]})); i++ ))
    do
    	vcf_gt_header+="\t${col_list[$i]}"
    done
else
    header_rec=$( vcf-query -l $tabix_file | sort -n | tr "\n" "\t" )
    parsed_col_names=$( vcf-query -l $tabix_file | sort -n | sed ':a;N;$!ba;s/\n/,/g' )
    vcf_gt_header+="\t$header_rec"
fi
echo -e "$vcf_gt_header" > $out_file

function generate_vcf_gt_content {
    region=$1
    
    vcf_query_cmd="vcf-query "
    if [ ! -z "$region" ]; then
        vcf_query_cmd+=" -r $region"
    fi
    if [ ! -z "$parsed_col_names" ]; then
        vcf_query_cmd+=" -c $parsed_col_names"
    fi
    vcf_query_cmd+=" -f '%CHROM\t%POS\t%ID\t%REF\t%ALT\t%QUAL\t%FILTER\t%INFO\t%FORMAT[\t%GT]\n' $tabix_file "
    info_msg
    info_msg "generating vcf genotyping using data from $vcf_query_cmd"
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
                        if [ "${gt[$k]}" = "${alt[$i]}" ]
        	            then
        	                if [ "${gt[0]}" = "${gt[1]}" ]
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

new_section_txt "F I N I S H <$script_name>"
