from __future__ import print_function
import sys
import csv
import xlwt
import ntpath

import argparse

IDX_COL_REC_KEY = 0
IDX_COL_EXONICFUNC = 3

DEFAULT_HORIZONTAL_SPLIT_IDX=1
DEFAULT_VERTICAL_SPLIT_IDX=13
DEFAULT_EFFECT_PREDICTORS_START_IDX=13

script_name = ntpath.basename(sys.argv[0])

def comment(*objs):
    print("##", *objs, end='\n', file=sys.stderr)

def display_header(header_txt):
    comment(header_txt)

def display_subheader(subheader_txt):
    comment("  " + subheader_txt)

def display_param(param_name, param_value):
    fmt = "  {name:<45}{value}"
    comment(fmt.format(name=param_name+":", value=param_value))

def display_subparam(subparam_name, subparam_value):
    display_param("  "+subparam_name, subparam_value)

argp = argparse.ArgumentParser(description="A script to manipulate csv files and group them into one xls")
tmp_help=[]
tmp_help.append("output xls file name")
argp.add_argument('-o', dest='out_file', help='output xls file name', required=True)
argp.add_argument('-s', dest='csvs', metavar='CSV INFO', help='list of csv files together with their name in comma and colon separators format', required=True)
argp.add_argument('-C', dest='hide_cols_idx', metavar='COLS IDX', help='indexes of column that are expected to hide', default="0,10")
argp.add_argument('-H', dest='hor_split_idx', metavar='COL IDX', help='index to do horizontal split', default=DEFAULT_HORIZONTAL_SPLIT_IDX)
argp.add_argument('-V', dest='ver_split_idx', metavar='COL IDX', help='index to do vertical split', default=DEFAULT_VERTICAL_SPLIT_IDX)
argp.add_argument('-P', dest='effect_predictors_start_idx', metavar='COL IDX', help='starting index of effect predictors', default=DEFAULT_EFFECT_PREDICTORS_START_IDX)
argp.add_argument('-R', dest='marked_key_range', metavar='KEY RANGE', help='region to be marked <start_key,end_key> (for example, -R 9|000000123456,9|000000789012)', default=None)
argp.add_argument('-F', dest='filter_frequencies', metavar='IDX-FREQUENCY PAIR', help='indexes of columns be filtered and their frequencies <idx_1:frequency_1,idx2:frequency_2,..> (for example, -F 3:0.2,4:0.1)', default=None)
argp.add_argument('-c', dest='common_mut_col_idx_range', metavar='COL IDX RANGE', help='range of index to find common mutations <start_idx,end_idx> (for example, -c 20,24)', default=None)
#argp.add_argument('--coding_only', dest='coding_only', action='store_true', default=False, help='specified if the result should display non-coding mutations (default: display all mutations)')
args = argp.parse_args()

## ****************************************  parse arguments into local global variables  ****************************************
out_file = args.out_file
sheet_name = []
sheet_csv = []
csvs_list = args.csvs.split(':')
for i in xrange(len(csvs_list)):
    sheet_info = csvs_list[i].split(',')
    sheet_name.append(sheet_info[0])
    sheet_csv.append(sheet_info[1])
hide_cols_idx = args.hide_cols_idx 
hor_split_idx = args.hor_split_idx 
ver_split_idx = args.ver_split_idx 
effect_predictors_start_idx = args.effect_predictors_start_idx 
marked_key_range = args.marked_key_range
comment(marked_key_range)
if marked_key_range is not None :
    marked_keys = marked_key_range.split(',')
    marked_start_key = marked_keys[0]
    marked_end_key = marked_keys[1]
common_mut_col_idx_range = args.common_mut_col_idx_range
if common_mut_col_idx_range is not None:
    common_mut_col_idxs = common_mut_col_idx_range.split(',')
    common_mut_start_col_idx = int(common_mut_col_idxs[0])
    common_mut_end_col_idx = int(common_mut_col_idxs[1])
if args.filter_frequencies is not None:
    filter_frequencies = args.filter_frequencies.split(',')
else:
    filter_frequencies = []
#coding_only = args.coding_only


## ****************************************  display configuration  ****************************************
## display required configuration
comment("")
comment("")
comment("************************************************** S T A R T <" + script_name + "> **************************************************")
comment("")
display_header("parameters")
comment("  " + " ".join(sys.argv[1:]))
comment("")

## display required configuration
display_header("required configuration")
display_param("xls output file (-o)", out_file)
comment("")

## display csvs configuration
display_header("csvs configuration (-s)(" + str(len(csvs_list)) + " sheet(s))")
for i in xrange(len(csvs_list)):
    display_param("sheet name #"+str(i+1), sheet_name[i])
    display_param("sheet csv  #"+str(i+1), sheet_csv[i])
comment("")

## display optional configuration
display_header("optional configuration")
display_param("hide columns (-C)", hide_cols_idx)
display_param("horizontal split index (-H)", hor_split_idx)
display_param("vertical split index (-V)", ver_split_idx)
display_param("effect predictors starting index (-P)", effect_predictors_start_idx)
if marked_key_range is not None :
    display_subheader("marked key range")
    display_subparam("start key", marked_start_key)
    display_subparam("end key", marked_end_key)
if common_mut_col_idx_range is not None:
    display_subheader("common mutation indices range")
    display_subparam("start column index", common_mut_start_col_idx)
    display_subparam("end column index", common_mut_end_col_idx)
if len(filter_frequencies) > 0:
    display_subheader("filter_frequencies (-F)")
    for i in xrange(len(filter_frequencies)):
	(filter_idx, filter_ratio) = filter_frequencies[i].split(':')
        display_subparam("idx   #"+str(i+1), filter_idx)
        display_subparam("ratio #"+str(i+1), filter_ratio)
#display_param("hide non-coding mutations (--coding_only)", coding_only)
comment("")
comment("")
comment("************************************************** F I N I S H <" + script_name + "> **************************************************")


## ****************************************  executing  ****************************************
def isFloat(string):
    try:
        float(string)
        return True
    except ValueError:
        return False

def explain_annotation(csv_record):
    col_ljb_phylop_pred         = effect_predictors_start_idx + 1
    col_ljb_sift_pred           = effect_predictors_start_idx + 3
    col_ljb_polyphen2_pred      = effect_predictors_start_idx + 5
    col_ljb_lrt_pred            = effect_predictors_start_idx + 7
    col_ljb_mutationtaster_pred = effect_predictors_start_idx + 9

    phylop_explanation         = {'C': 'conserved', 'N': 'not conserved'}
    sift_explanation           = {'T': 'tolerated', 'D': 'deleterious'}
    polyphen2_explanation      = {'D': 'probably damaging', 'P': 'possibly damaging', 'B': 'benign'}
    lrt_explanation            = {'D': 'tolerated', 'N': 'neutral'}
    mutationtaster_explanation = {'A': 'disease causing automatic', 'D': 'disease causing', 'N': 'polymorphism', 'P': 'polymorphism automatic'}

    if len(csv_record) < col_ljb_phylop_pred :
        return csv_record
    if csv_record[col_ljb_phylop_pred] in phylop_explanation:
        csv_record[col_ljb_phylop_pred]         = phylop_explanation[csv_record[col_ljb_phylop_pred]]
    if csv_record[col_ljb_sift_pred] in sift_explanation:
        csv_record[col_ljb_sift_pred]           = sift_explanation[csv_record[col_ljb_sift_pred]]
    if csv_record[col_ljb_polyphen2_pred] in polyphen2_explanation:
        csv_record[col_ljb_polyphen2_pred]      = polyphen2_explanation[csv_record[col_ljb_polyphen2_pred]]
    if csv_record[col_ljb_lrt_pred] in lrt_explanation:
        csv_record[col_ljb_lrt_pred]            = lrt_explanation[csv_record[col_ljb_lrt_pred]]
    if csv_record[col_ljb_mutationtaster_pred] in mutationtaster_explanation:
        csv_record[col_ljb_mutationtaster_pred] = mutationtaster_explanation[csv_record[col_ljb_mutationtaster_pred]]
    return csv_record


def add_csv_sheet(wb, sheet_name, csv_file, st):
    ws = wb.add_sheet(sheet_name)
    with open(csv_file, 'rb') as csvfile:
        csv_records = list(csv.reader(csvfile, delimiter='\t'))
        csv_row = 0
        for xls_row in xrange(len(csv_records)):
            csv_record = csv_records[xls_row]
            csv_record = explain_annotation(csv_record)
            it_is_common_mutations = False
            if common_mut_col_idx_range is not None:
    	        it_is_common_mutations = True
    	        for col_idx in xrange(common_mut_start_col_idx, common_mut_end_col_idx):
    	            if (csv_record[col_idx] != 'het') and (csv_record[col_idx] != 'hom'):
    		            it_is_common_mutations = False
            else:
    	        it_is_common_mutations = False
            for col in xrange(len(csv_record)):
    	        # mark common mutations
    	        if (it_is_common_mutations) and (col in range(common_mut_start_col_idx, common_mut_end_col_idx)):
                    ws.write(csv_row, col, csv_record[col], st['common'])
    	        # mark region of interest
    	        elif (marked_key_range is not None) and (col == 1) and (csv_record[IDX_COL_REC_KEY] > marked_start_key) and (csv_record[IDX_COL_REC_KEY] < marked_end_key) :
                    ws.write(csv_row, col, csv_record[col], st['interest'])
    	        elif len(filter_frequencies) > 0:
        	        # mark rare mutations
    	            rare_mutation = True
    	            for item in filter_frequencies:
    		            (filter_idx, filter_ratio) = item.split(':')
    		            if not ((isFloat(csv_record[int(filter_idx)]) and (float(csv_record[int(filter_idx)])<=float(filter_ratio))) or (csv_record[int(filter_idx)]=='')):
    		                rare_mutation = False
    		                break
                    #elif (len(csv_record) > IDX_COL_OAF) and ((((isFloat(csv_record[IDX_COL_OAF]) and (float(csv_record[IDX_COL_OAF])<=0.1)) or (csv_record[IDX_COL_OAF]=='')) and ((isFloat(csv_record[IDX_COL_MAF]) and (float(csv_record[IDX_COL_MAF])<0.1)) or (csv_record[IDX_COL_MAF]==''))) and (csv_record[IDX_COL_MAF] != 'nonsynonymous SNV')):
    	            if rare_mutation:
    		            ws.write(csv_row, col, csv_record[col], st['rare'])
                    else:
                        ws.write(csv_row, col, csv_record[col])
    	        else:
                    ws.write(csv_row, col, csv_record[col])
#        if (coding_only) and ((csv_record[IDX_COL_EXONICFUNC] == '') or (csv_record[IDX_COL_EXONICFUNC] == 'synonymous SNV')):
#    	ws.row(csv_row).hidden = True
            csv_row += 1
    hide_cols_idx_list = hide_cols_idx.split(',')
    for i in xrange(len(hide_cols_idx_list)):
	ws.col(int(hide_cols_idx_list[i])).hidden = True
    ws.set_panes_frozen(True)
    ws.set_horz_split_pos(hor_split_idx)
    ws.set_vert_split_pos(ver_split_idx)
    ws.set_remove_splits(True)


wb = xlwt.Workbook()
st = {}
st['common'] = xlwt.easyxf('pattern: pattern solid, fore_colour lime;')
st['interest'] = xlwt.easyxf('pattern: pattern solid, fore_colour pale_blue;')
st['rare'] = xlwt.easyxf('pattern: pattern solid, fore_colour yellow;')

for i in xrange(len(csvs_list)):
    add_csv_sheet(wb, sheet_name[i], sheet_csv[i], st)

wb.save(out_file)
