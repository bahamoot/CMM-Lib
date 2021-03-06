#!/bin/bash
source $CMM_LIB_DIR/cmm_functions.sh

script_name=$(basename $0)
params="$@"

#define default values
COL_CONFIG_DEFAULT="ALL"
VCF_REGION_DEFAULT=""
CAL_ALLELIC_FREQUENCY_DEFAULT="no"
CAL_GENOTYPED_FREQUENCY_DEFAULT="no"
OUT_FILE_DEFAULT="STDOUT"

usage=$(
cat <<EOF
usage:
$0 [OPTION]
option:
-k {project name}  specify primary key for running this script (required)
-t {file}          specify tabix file (required)
-R {region}        specify vcf region to be exported (default:all)
-c {patient list}  specify vcf columns to exported. This can be either in comma-separated format or it can be a file name (default:$COL_CONFIG_DEFAULT)
-o {directory}     specify output directory (required)
-w {directory}     specify working directory (required)
-l {file}          specify log file name (required)
EOF
)

while getopts ":k:t:A:R:c:o:w:l:" OPTION; do
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
    o)
      out_dir="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
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
[ ! -z $out_dir ] || die "Plesae specify output directory (-o)"
[ ! -z $working_dir ] || die "Plesae specify working directory (-w)"
[ ! -z $running_log_file ] || die "Plesae specify where to keep log output (-l)"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$working_dir is not a valid directory"
[ -f $running_log_file ] || die "$running_log_file is not a valid file name"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_config=$COL_CONFIG_DEFAULT}
: ${cal_allelic_frequency=$CAL_ALLELIC_FREQUENCY_DEFAULT}
: ${cal_genotyped_frequency=$CAL_GENOTYPED_FREQUENCY_DEFAULT}

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

stat_out_file="$out_dir/$running_key".stat

## ****************************************  display configuration  ****************************************
new_section_txt "S T A R T <$script_name>"
info_msg
info_msg "parameters"
info_msg "  $params"
info_msg
info_msg "description"
info_msg "  A script to count/calculate mutation statistics. There are three kind of frequencies calculated:"
info_msg "    - genotyping frequency: It's the ratio of \"number of samples being genotyped\"/\"total number samples\""
info_msg "    - allelic frequency: It's the ratio of \"number of that particular allele in the samples\"/(\"number of genotyped samples\"*2)"
info_msg "    - population frequency: It's the ratio of \"number of that particular allele in the samples\"/(\"total number of samples\"*2)"
info_msg
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
display_param "column count" "$col_count"
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

## display output configuration
info_msg
info_msg "output configuration" 
display_param "output directory (-o)" "$out_dir"
display_param "  statistics output file" "$stat_out_file"
display_param "working dir (-w)" "$working_dir"

# ****************************************  executing  ****************************************
VCF_QUERY_FORMAT="'%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n'"
COL_KEY_COUNT=4
IDX_0_CHR_COL=0
IDX_0_POS_COL=1
IDX_0_REF_COL=2
IDX_0_ALT_COL=3
IDX_0_GT_COL=4

function query_vcf {
    query_region=$1
    
    vcf_query_cmd="vcf-query "
    if [ ! -z "$query_region" ]; then
        vcf_query_cmd+=" -r $query_region"
    fi
    if [ ! -z "$parsed_col_names" ]; then
        vcf_query_cmd+=" -c $parsed_col_names"
    fi
    vcf_query_cmd+=" -f "$VCF_QUERY_FORMAT" $tabix_file "
    info_msg
    info_msg "generating vcf genotyping using data from $vcf_query_cmd"
    eval "$vcf_query_cmd" 
}

function count_frequency {
    region="$1"

    # calculate statistics
    query_vcf "$1" | 
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
            wt_count=0
            het_count=0
            hom_count=0
            oth_count=0
            na_count=0
            gt_count=0
            al_count=0
            for (( j=$IDX_0_GT_COL; j<$((${#rec_col[@]})); j++ ))
            do
                # count genotypes
            	if [ ${rec_col[$j]} != "./." ] && [ ${rec_col[$j]} != "." ]
                then
                    let gt_count++
                else
                    let na_count++
                fi
            
                # count alleles
                IFS='/' read -ra gt <<< "${rec_col[$j]}"
                # for both chromosomes
            	for (( k=0; k<$((${#gt[@]})); k++ ))
            	do
                    if [ "${gt[$k]}" = "${alt[$i]}" ]
        	        then
                        let al_count++
        	            if [ "${gt[0]}" = "${gt[1]}" ]
        	            then
                            let hom_count++
                            let al_count++
                            break
                        else
                            let het_count++
                        fi
                    elif [ "${gt[0]}" != "${alt[$i]}" ] && [ "${gt[1]}" != "${alt[$i]}" ] && [ "${gt[$k]}" != "$ref" ] && [ "${gt[0]}" != "." ] && [ "${gt[1]}" != "." ]
                    then
                        let oth_count++
                        break
                    fi
            	done
                if [ "${gt[0]}" = "${gt[1]}" ] && [ "${gt[0]}" = "$ref" ]
                then
                    let wt_count++
                fi
            done
            if [ $gt_count -eq 0 ]
            then
                af=0
            else
                cmd="echo \"$al_count / ($gt_count * 2 ) \" | bc -l"
                af=` eval "$cmd" `
            fi
            cmd="echo \"$gt_count / ($col_count ) \" | bc -l"
            gf=` eval "$cmd" `
            cmd="echo \"$al_count / ($col_count *2 ) \" | bc -l"
            pf=` eval "$cmd" `
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%6.4f\t%6.4f\t%6.4f\n" "$rec_out" "$wt_count" "$het_count" "$hom_count" "$oth_count" "$na_count" "$gt_count" "$gf" "$af" "$pf"
        done
    done
}

# create header
echo -e "#KEY\tWT\tHET\tHOM\tOTH\tNA\tGT\tGF\tAF\tPF" > "$stat_out_file"
        
if [ ! -z "$vcf_region" ]; then
    for (( n=0; n<$((${#vcf_region_list[@]})); n++ ))
    do
        count_frequency "${vcf_region_list[$n]}" >> "$stat_out_file"
    done
else
    count_frequency "" >> "$stat_out_file"
fi

new_section_txt "F I N I S H <$script_name>"
