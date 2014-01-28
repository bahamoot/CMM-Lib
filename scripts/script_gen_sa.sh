#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

working_dir=$script_dir/tmp

if [ ! -d "$working_dir" ]; then
    mkdir $working_dir
fi

#---------- arguments --------------
chr=$1
begin_pos=$2
end_pos=$3
tabix_file=$4
oaf_file=$5
out_prefix=$6
out_file=$7

#---------- arguments --------------

echo "## building summarize annovar database" 1>&2
echo "## parameters" 1>&2
echo "## chromosome:  $chr" 1>&2
echo "## begin pos:   $begin_pos" 1>&2
echo "## end pos:     $end_pos" 1>&2
echo "## tabix_file:  $tabix_file" 1>&2
echo "## oaf_file:    $oaf_file" 1>&2
echo "## working_dir: $working_dir" 1>&2
echo "## out_prefix:  $out_prefix" 1>&2
echo "## out_file:    $out_file" 1>&2


#---------- vcf2avdb --------------
tmp_avdb=$working_dir/$out_prefix"_tmp_avdb"
avdb_individual_prefix=$working_dir/$out_prefix"_individual"
tmp_avdb_uniq=$working_dir/$out_prefix".tmp_uniq.avdb"
avdb_uniq=$working_dir/$out_prefix".uniq.avdb"
avdb_key=$working_dir/$out_prefix".key.avdb"
avdb_oaf=$working_dir/$out_prefix".oaf.avdb"


if [ -z $chr ]
then
    cut_region="zcat $tabix_file | grep -v \"^#\""
else
    cut_region="tabix $tabix_file $chr:$begin_pos-$end_pos"
fi
create_tmp_avdb="zcat $tabix_file > $tmp_avdb"
echo "## executing $create_tmp_avdb" 1>&2
eval $create_tmp_avdb

convert2annovar="$CONVERT2ANNOVAR -format vcf4 $tmp_avdb -include --allsample --outfile $avdb_individual_prefix"
echo "## executing $convert2annovar" 1>&2
eval $convert2annovar

if [ -f "$tmp_avdb_uniq" ]; then
    rm $tmp_avdb_uniq
fi
for f in $avdb_individual_prefix*
do
    cut -f1-11 "$f" >> $tmp_avdb_uniq
done

sort $tmp_avdb_uniq | uniq > $avdb_uniq

#---------- vcf2avdb --------------


#---------- rearrange avdb and add key --------------
echo "##" 1>&2
add_key_to_avdb="grep -P \"^[0-9]\" $avdb_uniq | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%02d|%012d|%s|%s\n\", \$1, \$2, \$3, \$4, \$5, \$11, \$6, \$7, \$9, \$10 }' > $avdb_key"
echo "## executing $add_key_to_avdb" 1>&2
eval $add_key_to_avdb
add_key_to_avdb="grep -vP \"^[0-9]\" $avdb_uniq | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s|%012d|%s|%s\n\", \$1, \$2, \$3, \$4, \$5, \$11, \$6, \$7, \$9, \$10 }' >> $avdb_key"
echo "## executing $add_key_to_avdb" 1>&2
eval $add_key_to_avdb
#---------- rearrange avdb and add key --------------


##---------- add oaf to avdb --------------
echo "##" 1>&2
join_cmd="join -t $'\t' -a 1 -1 7 -2 1 -e NULL -o 1.1,1.2,1.3,1.4,1.5,1.6,1.7,2.2 <( grep -P \"^[0-9]\" $avdb_key | sort -t\$'\t' -k7 ) <(grep -P \"^[0-9]\" $oaf_file ) > $avdb_oaf"
echo "## executing $join_cmd" 1>&2
eval $join_cmd
join_cmd="join -t $'\t' -a 1 -1 7 -2 1 -e NULL -o 1.1,1.2,1.3,1.4,1.5,1.6,1.7,2.2 <( grep -vP \"^[0-9]\" $avdb_key | sort -t\$'\t' -k 7) <(grep -vP \"^[0-9]\" $oaf_file ) >> $avdb_oaf"
echo "## executing $join_cmd" 1>&2
eval $join_cmd
#---------- add oaf --------------


#---------- summarize --------------
summarize_out=$working_dir/$out_prefix
summarize_annovar="$SUMMARIZE_ANNOVAR -out $summarize_out -buildver hg19 -verdbsnp 137 -ver1000g 1000g2012apr -veresp 6500 -remove -alltranscript $avdb_oaf $ANNOVAR_HUMAN_DB_DIR"
echo "## executing $summarize_annovar" 1>&2
eval $summarize_annovar
#---------- summarize --------------


#---------- comma2tab --------------
csv_file=$summarize_out".genome_summary.csv"
comma2tab="perl -pe 'while (s/(,\"[^\"]+),/\1<COMMA>/g) {1}; s/\"//g; s/,/\t/g; s/<COMMA>/,/g' < $csv_file > $out_file"
echo "## executing $comma2tab" 1>&2
eval $comma2tab
#---------- comma2tab --------------
