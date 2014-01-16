#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

working_dir=$script_dir/tmp
tmp_oaf=$working_dir/tmp_oaf

vcf_gz_file=$1
hbvdb_dir=$2
out_oaf_file=$3

echo "## building hbvdb & oaf" 1>&2
echo "## parameters" 1>&2
echo "## vcf gz file:     $vcf_gz_file" 1>&2
echo "## hbvdb directory: $hbvdb_dir" 1>&2
echo "## out oaf file:    $out_oaf_file" 1>&2

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

echo "## plainly add mutation from vcf file  $vcf_gz_file" 1>&2
cmd="$HBVDB_BVD_ADD <( zcat $vcf_gz_file ) --database $hbvdb_dir"
echo "## executing $cmd" 1>&2
eval $cmd

cmd="$HBVDB_BVD_GET --database $hbvdb_dir > $tmp_oaf"
echo "## executing $cmd" 1>&2
eval $cmd

echo "##" 1>&2
oaf_key_cmd="grep -P \"^[0-9]\" $tmp_oaf | awk -F'\t' '{ printf \"%02d|%012d|%s|%s\t%s\n\", \$1, \$2, \$4, \$5, \$6}' | sort -k1,1 > $out_oaf_file"
echo "## executing $oaf_key_cmd" 1>&2
eval $oaf_key_cmd
oaf_key_cmd="grep -vP \"^[0-9]\" $tmp_oaf | awk -F'\t' '{ printf \"%s|%012d|%s|%s\t%s\n\", \$1, \$2, \$4, \$5, \$6}' | sort -k1,1 >> $out_oaf_file"
echo "## executing $oaf_key_cmd" 1>&2
eval $oaf_key_cmd
