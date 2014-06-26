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
#-a                 calculate allelic frequency
#-g                 genotyped frequency (default is caluculating allelic frequency)
-o {directory}     specify output directory (requried)
-w {directory}     specify working directory (required)
EOF
)

die () {
    echo >&2 "[exception] $@"
    echo >&2 "$usage"
    exit 1
}

#get file
while getopts ":k:t:A:R:c:o:w:" OPTION; do
#while getopts ":k:t:A:R:c:ago:w:" OPTION; do
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
#    a)
#      cal_allelic_frequency="yes"
#      ;;
#    g)
#      cal_genotyped_frequency="yes"
#      ;;
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

[ ! -z $running_key ] || die "Please specfify running key"
[ ! -z $tabix_file ] || die "Please specify tabix file"
[ ! -z $out_dir ] || die "Plesae specify output directory (-o)"
[ ! -z $working_dir ] || die "Plesae specify working directory (-w)"
[ -f $tabix_file ] || die "$tabix_file is not a valid file name"
[ -d $out_dir ] || die "$out_dir is not a valid directory"
[ -d $working_dir ] || die "$out_dir is not a valid directory"

#setting default values:
: ${vcf_region=$VCF_REGION_DEFAULT}
: ${col_names=$COL_NAMES_DEFAULT}
: ${cal_allelic_frequency=$CAL_ALLELIC_FREQUENCY_DEFAULT}
: ${cal_genotyped_frequency=$CAL_GENOTYPED_FREQUENCY_DEFAULT}

#if [ $cal_allelic_frequency = "yes" ]
#then
#    al_frq_out="$out_dir"
#    die "only one type of frequency can be calculated in one run"
#fi
#if [ $cal_allelic_frequency = "yes" ] && [ $cal_genotyped_frequency = "yes" ]
#then
#    die "only one type of frequency can be calculated in one run"
#fi
#if [ $cal_genotyped_frequency != "yes" ]
#then
#    cal_allelic_frequency="yes"
#fi
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

af_out_file="$out_dir/$running_key".af
gf_out_file="$out_dir/$running_key".gf
pf_out_file="$out_dir/$running_key".pf

## ****************************************  display configuration  ****************************************
echo "##" 1>&2
echo "## ************************************************** S T A R T <$script_name> **************************************************" 1>&2
echo "##" 1>&2
echo "## parameters" 1>&2
echo "##   $@" 1>&2
echo "##" 1>&2
echo "## description" 1>&2
echo "##   A script to count/calculate mutation statistics. There are three kind of frequencies calculated:" 1>&2
echo "##     - genotyping frequency: It's the ratio of \"number of samples being genotyped\"/\"total number samples\"" 1>&2
echo "##     - allelic frequency: It's the ratio of \"number of that particular allele in the samples\"/(\"number of genotyped samples\"*2)" 1>&2
echo "##     - population frequency: It's the ratio of \"number of that particular allele in the samples\"/(\"total number of samples\"*2)" 1>&2
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
#if [ $cal_allelic_frequency = "yes" ]
#then
#    display_param "type of frequency calculation" "allelic frequency"
#else
#    display_param "type of frequency calculation" "genotyped frequency"
#fi

## display output configuration
echo "##" 1>&2
echo "## output configuration" 1>&2
display_param "output directory (-o)" "$out_dir"
display_param "allelic frequency output file" "$af_out_file"
display_param "genotyping frequency output file" "$gf_out_file"
display_param "population frequency output file" "$pf_out_file"
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
            pf_count=0
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
            cmd="echo \"$al_count / ($col_count *2 ) \" | bc -l"
            pf=` eval "$cmd" `
            echo -e "$rec_out\t$af\t$gf\t$pf"
        done
    done
}

tmp_count_frequency="$working_dir/$running_key"_tmp_count_frequency
count_frequency > "$tmp_count_frequency"

gen_af_cmd="echo -e \"#KEY\tAF\" > $af_out_file; awk -F'\t' '{ printf \"%s\t%06.4f\n\", \$1, \$2 }' $tmp_count_frequency >> $af_out_file"
echo "##" 1>&2
echo "## generating allele frequency output file using command $gen_af_cmd" 1>&2
eval $gen_af_cmd
#if [ "$out_file" = "$OUT_FILE_DEFAULT" ]
#then
#    eval "$cmd"
#else
#    eval "$cmd" > $out_file
#fi
gen_gf_cmd="echo -e \"#KEY\tGF\" > $gf_out_file; awk -F'\t' '{ printf \"%s\t%06.4f\n\", \$1, \$3 }' $tmp_count_frequency >> $gf_out_file "
echo "##" 1>&2
echo "## generating allele frequency output file using command $gen_gf_cmd" 1>&2
eval $gen_gf_cmd
#if [ "$out_file" = "$OUT_FILE_DEFAULT" ]
#then
#    eval "$cmd"
#else
#    eval "$cmd" > $out_file
#fi
gen_pf_cmd="echo -e \"#KEY\tPF\" > $pf_out_file; awk -F'\t' '{ printf \"%s\t%06.4f\n\", \$1, \$4 }' $tmp_count_frequency >> $pf_out_file "
echo "##" 1>&2
echo "## generating allele frequency output file using command $gen_pf_cmd" 1>&2
eval $gen_pf_cmd

echo "## ************************************************** F I N I S H <$script_name> **************************************************" 1>&2
