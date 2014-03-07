#!/bin/bash

hbvdb_tools_root_dir=$1
vcf_gz_file=$2
hbvdb_out_dir=$3
working_dir=$4
out_oaf_file=$5

tmp_oaf="$working_dir/tmp_oaf"

echo "## building hbvdb & oaf" 1>&2
echo "## parameters" 1>&2
echo "## vcf gz file:                 $vcf_gz_file" 1>&2
echo "## hbvdb tools root directory:  $hbvdb_tools_root_dir" 1>&2
echo "## hbvdb out directory:         $hbvdb_out_dir" 1>&2
echo "## working directory:           $working_dir" 1>&2
echo "## out oaf file:                $out_oaf_file" 1>&2

echo "## plainly add mutation from vcf file  $vcf_gz_file" 1>&2
cmd="$hbvdb_tools_root_dir/bin/bvd-add.pl <( zcat $vcf_gz_file ) --database $hbvdb_out_dir"
echo "## executing $cmd" 1>&2
eval $cmd

cmd="$hbvdb_tools_root_dir/bin/bvd-get.pl --database $hbvdb_out_dir > $tmp_oaf"
echo "## executing $cmd" 1>&2
eval $cmd

echo "##" 1>&2
oaf_key_cmd="grep -P \"^[0-9]\" $tmp_oaf | awk -F'\t' '{ printf \"%02d|%012d|%s|%s\t%s\n\", \$1, \$2, \$4, \$5, \$6}' | sort -k1,1 > $out_oaf_file"
echo "## executing $oaf_key_cmd" 1>&2
eval $oaf_key_cmd
oaf_key_cmd="grep -vP \"^[0-9]\" $tmp_oaf | awk -F'\t' '{ printf \"%s|%012d|%s|%s\t%s\n\", \$1, \$2, \$4, \$5, \$6}' | sort -k1,1 >> $out_oaf_file"
echo "## executing $oaf_key_cmd" 1>&2
eval $oaf_key_cmd
