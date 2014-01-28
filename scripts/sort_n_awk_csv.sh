#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

working_dir=$script_dir/tmp
tmp_sort_awk=$working_dir/tmp_sort_awk
tmp_awk1=$working_dir/tmp_awk1
tmp_awk2=$working_dir/tmp_awk2

COL_FUNC=1
COL_GENE=2
COL_EXONICFUNC=3
COL_AACHANGE=4
COL_1000G=8
COL_DBSNP=9
COL_PHYLOP=11
COL_PHYLOPPRED=12
COL_SIFT=13
COL_SIFTPRED=14
COL_POLYPHEN=15
COL_POLYPHENPRED=16
COL_LRT=17
COL_LRTPRED=18
COL_MT=19
COL_MTPRED=20
COL_CHR=22
COL_STARTPOS=23
COL_ENDPOS=24
COL_REF=25
COL_OBS=26
COL_VCF_KEYS=28
COL_OAF=29

maf_filter=0.1
oaf_filter=0.1


#---------- arguments --------------
csv=$1
#---------- arguments --------------

#echo "## sort and awk csv for later display" 1>&2
#echo "## parameters" 1>&2
#echo "## csv file:    $csv" 1>&2
#echo "## working dir: $working_dir" 1>&2


cmd="grep -v \"Func\" $csv | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n\", \$$COL_VCF_KEYS, \$$COL_FUNC, \$$COL_GENE, \$$COL_EXONICFUNC, \$$COL_AACHANGE, \$$COL_OAF, \$$COL_1000G, \$$COL_DBSNP, \$$COL_CHR, \$$COL_STARTPOS, \$$COL_ENDPOS, \$$COL_REF, \$$COL_OBS, \$$COL_PHYLOP, \$$COL_PHYLOPPRED, \$$COL_SIFT, \$$COL_SIFTPRED, \$$COL_POLYPHEN, \$$COL_POLYPHENPRED, \$$COL_LRT, \$$COL_LRTPRED, \$$COL_MT, \$$COL_MTPRED, \$$COL_VCF_KEYS}' > $tmp_awk1"
eval $cmd

grep -P "^[0-9]" $tmp_awk1 | sort -t$'\t' -n -k1 | cut -f2-30 > $tmp_awk2
grep -vP "^[0-9]" $tmp_awk1 | sort -t$'\t' -n -k1 | cut -f2-30 >> $tmp_awk2

cmd="head -1 $csv | awk -F'\t' '{ printf \"%s\t%s\t%s\t%s\tOAF\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tPhyloP\tPhyloP prediction\tSIFT\tSIFT prediction\tPolyPhen2\tPolyPhen2 prediction\tLRT\tLRT prediction\tMT\tMT prediction\n\", \$$COL_FUNC, \$$COL_GENE, \$$COL_EXONICFUNC, \$$COL_AACHANGE, \$$COL_1000G, \$$COL_DBSNP, \$$COL_CHR, \$$COL_STARTPOS, \$$COL_ENDPOS, \$$COL_REF, \$$COL_OBS}' > $tmp_sort_awk"
eval $cmd
cmd="grep -v \"nonsynonymous SNV\" $tmp_awk2 | awk -F'\t' '{ if (\$6 < $maf_filter && \$5 < $oaf_filter) print \$0 }'  >> $tmp_sort_awk"
eval $cmd
cmd="grep \"nonsynonymous SNV\" $tmp_awk2 | awk -F'\t' '{ if (\$6 < $maf_filter && \$5 < $oaf_filter) print \$0 }' >> $tmp_sort_awk"
eval $cmd
cmd="grep -v \"nonsynonymous SNV\" $tmp_awk2 | awk -F'\t' '{ if (\$6 >= $maf_filter || \$5 >= $oaf_filter) print \$0 }'  >> $tmp_sort_awk"
eval $cmd
cmd="grep \"nonsynonymous SNV\" $tmp_awk2 | awk -F'\t' '{ if (\$6 >= $maf_filter || \$5 >= $oaf_filter) print \$0 }' >> $tmp_sort_awk"
eval $cmd
cat $tmp_sort_awk
#head -1 $csv | awk -F'\t' '{ printf "%s\t%s\t%s\t%s\t%s\t%s\n", $$COL_FUNC, $$COL_GENE, $$COL_EXONICFUNC, $$COL_AACHANGE, $$COL_1000G, $$COL_DBSNP}'

#cut -f32,33 $csv | head

