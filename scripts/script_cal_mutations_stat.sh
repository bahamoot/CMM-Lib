#!/bin/bash

script_name=$(basename $0)

#define default values
COL_NAMES_DEFAULT=""
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
-c {patient list}  specify vcf columns to exported (default:all)
-a                 calculate allelic frequency
-g                 genotyped frequency (default is caluculating allelic frequency)
-o {file}          specify output file (default:STDOUT)
-w {directory}     specify working directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts ":k:t:A:R:c:ago:w:" OPTION; do
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
    a)
      cal_allelic_frequency="yes"
      ;;
    g)
      cal_genotyped_frequency="yes"
      ;;
    o)
      out_file="$OPTARG"
      ;;
    w)
      working_dir="$OPTARG"
      ;;
    *)
      die "unrecognized option from executing: $0 $@"
      ;;
  esac
done

[ ! -z $running_key ] || die "Please specfify running key"
[ ! -z $tabix_file ] || die "Please specify tabix file"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_names=$COL_NAMES_DEFAULT}
: ${cal_allelic_frequency=$CAL_ALLELIC_FREQUENCY_DEFAULT}
: ${cal_genotyped_frequency=$CAL_GENOTYPED_FREQUENCY_DEFAULT}
: ${out_file=$OUT_FILE_DEFAULT}

if [ $cal_allelic_frequency = "yes" ] && [ $cal_genotyped_frequency = "yes" ]
then
    die "only one type of frequency can be calculated in one run"
fi
if [ $cal_genotyped_frequency != "yes" ]
then
    cal_allelic_frequency="yes"
fi
if [ ! -z "$col_names" ]
then
    IFS=',' read -ra col_list <<< "$col_names"
    for (( i=0; i<$((${#col_list[@]})); i++ ))
    do
	col_exist=$( $VCF_COL_EXIST $tabix_file ${col_list[$i]} )
	if [ "$col_exist" -ne 1 ]
	then
	    die "column ${col_list[$i]} is not exist"
	fi
    done
    col_count=${#col_list[@]}
else
    col_count=$( vcf-query -l $tabix_file | wc -l)
fi

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
echo "##   A script to count/calculate mutation statistics" 1>&2
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
if [ $cal_allelic_frequency = "yes" ]
then
    display_param "type of frequency calculation" "allelic frequency"
else
    display_param "type of frequency calculation" "genotyped frequency"
fi

## display output configuration
echo "##" 1>&2
echo "## output configuration" 1>&2
display_param "out file (-o)" "$out_file"
display_param "working dir (-w)" "$working_dir"

# ****************************************  executing  ****************************************
VCF_QUERY_FORMAT="'%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n'"
#VCF_QUERY_FORMAT="'%CHROM\t%POS\t%REF\t%ALT\t%INFO[\t%GT]\n'"
COL_KEY_COUNT=4
IDX_0_CHR_COL=0
IDX_0_POS_COL=1
IDX_0_REF_COL=2
IDX_0_ALT_COL=3
IDX_0_GT_COL=4

function query_vcf {
    
    vcf_query_cmd="vcf-query "
    if [ ! -z "$vcf_region" ]; then
        vcf_query_cmd+=" -r $vcf_region"
    fi
    if [ ! -z "$col_names" ]; then
        vcf_query_cmd+=" -c $col_names"
    fi
    vcf_query_cmd+=" -f "$VCF_QUERY_FORMAT" $tabix_file "
    echo "##" 1>&2
    echo "##" 1>&2
    echo "## generating vcf genotyping using data from $vcf_query_cmd" 1>&2
    eval "$vcf_query_cmd" 
}

function count_frequency {
    query_vcf | 
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
    	        rec_out=$( printf "%s|%012d|%s|%s" $chr $pos $ref ${alt[$i]} )
    	    else
    	        rec_out=$( printf "%02d|%012d|%s|%s" $chr $pos $ref ${alt[$i]} )
    	    fi
	    # for all GT fields
	    al_count=0
	    gt_count=0
            for (( j=$IDX_0_GT_COL; j<$((${#rec_col[@]})); j++ ))
            do
		# count genotypes
            	if [ ${rec_col[$j]} != "./." ] && [ ${rec_col[$j]} != "." ]
		then
		    let gt_count++
		fi

		# count alleles
                IFS='/' read -ra gt <<< "${rec_col[$j]}"
    	    	out_gt="."
		# for both chromosomes
            	for (( k=0; k<$((${#gt[@]})); k++ ))
            	do
            	    if [ ${gt[$k]} = ${alt[$i]} ]; then
			let al_count++
            	    fi
            	done
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
            echo -e "$rec_out\t$af\t$gf"
        done
    done
}

if [ "$cal_allelic_frequency" = "yes" ]
then
    cmd="echo -e \"#KEY\tAF\"; count_frequency | awk -F'\t' '{ printf \"%s\t%06.4f\n\", \$1, \$2 }'  "
    if [ "$out_file" = "$OUT_FILE_DEFAULT" ]
    then
	
	eval "$cmd"
    else
	eval "$cmd" > $out_file
    fi
else
    cmd="echo -e \"#KEY\tGF\"; count_frequency | awk -F'\t' '{ printf \"%s\t%06.4f\n\", \$1, \$3 }'  "
    if [ "$out_file" = "$OUT_FILE_DEFAULT" ]
    then
	eval "$cmd"
    else
	eval "$cmd" > $out_file
    fi
fi
echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
