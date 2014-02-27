from __future__ import print_function
import sys
import csv
import xlwt
import ntpath

import argparse

IDX_COL_OAF = 5
IDX_COL_MAF = 6

DEFAULT_HORIZONTAL_SPLIT_IDX=1
DEFAULT_VERTICAL_SPLIT_IDX=13
DEFAULT_EFFECT_PREDICTORS_START_IDX=13

script_name = ntpath.basename(sys.argv[0])

def comment(*objs):
    print("##", *objs, end='\n', file=sys.stderr)

def display_param(param_name, param_value):
    fmt = "  {name:<40}{value}"
    comment(fmt.format(name=param_name+":", value=param_value))

argp = argparse.ArgumentParser(description="A script to manipulate csv files and group them into one xls")
tmp_help=[]
tmp_help.append("output xls file name")
argp.add_argument('-o', dest='out_file', help='output xls file name', required=True)
argp.add_argument('-s', dest='csvs', metavar='CSV INFO', help='list of csv files together with their name in comma and colon separators format', required=True)
argp.add_argument('-C', dest='hide_cols_idx', metavar='COLS IDX', help='indexes of column that are expected to hide', default="0,10")
argp.add_argument('-H', dest='hor_split_idx', metavar='COL IDX', help='index to do horizontal split', default=DEFAULT_HORIZONTAL_SPLIT_IDX)
argp.add_argument('-V', dest='ver_split_idx', metavar='COL IDX', help='index to do vertical split', default=DEFAULT_VERTICAL_SPLIT_IDX)
argp.add_argument('-P', dest='effect_predictors_start_idx', metavar='COL IDX', help='starting index of effect predictors', default=DEFAULT_EFFECT_PREDICTORS_START_IDX)
argp.add_argument('-M', dest='mark_region', metavar='KEY RANGE', help='region to be marked', default=None)
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


## ****************************************  display configuration  ****************************************
## display required configuration
comment("")
comment("")
comment("************************************************** S T A R T <" + script_name + "> **************************************************")
comment("")
comment("parameters")
comment("  " + " ".join(sys.argv[1:]))
comment("")
comment("required configuration")
display_param("xls output file (-o)", out_file)
comment("")
comment("csvs configuration (-s)(" + str(len(csvs_list)) + " sheet(s))")
for i in xrange(len(csvs_list)):
    display_param("sheet name #"+str(i+1), sheet_name[i])
    display_param("sheet csv  #"+str(i+1), sheet_csv[i])
comment("")
## display optional configuration
comment("optional configuration")
display_param("hide columns (-C)", hide_cols_idx)
display_param("horizontal split index (-H)", hor_split_idx)
display_param("vertical split index (-V)", ver_split_idx)
display_param("effect predictors starting index (-P)", effect_predictors_start_idx)
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
            for col in xrange(len(csv_record)):
                if (len(csv_record) > IDX_COL_OAF) and ((((isFloat(csv_record[IDX_COL_OAF]) and (float(csv_record[IDX_COL_OAF])<=0.1)) or (csv_record[IDX_COL_OAF]=='')) and ((isFloat(csv_record[IDX_COL_MAF]) and (float(csv_record[IDX_COL_MAF])<0.1)) or (csv_record[IDX_COL_MAF]==''))) and (csv_record[IDX_COL_MAF] != 'nonsynonymous SNV')):
#                    ws.write(csv_row, col, csv_record[col])
                    ws.write(csv_row, col, csv_record[col], st)
                else:
                    ws.write(csv_row, col, csv_record[col])
            csv_row += 1
    hide_cols_idx_list = hide_cols_idx.split(',')
    for i in xrange(len(hide_cols_idx_list)):
	ws.col(int(hide_cols_idx_list[i])).hidden = True
    ws.set_panes_frozen(True)
    ws.set_horz_split_pos(hor_split_idx)
    ws.set_vert_split_pos(ver_split_idx)
    ws.set_remove_splits(True)


wb = xlwt.Workbook()
yellow_st = xlwt.easyxf('pattern: pattern solid, fore_colour yellow;')

for i in xrange(len(csvs_list)):
    add_csv_sheet(wb, sheet_name[i], sheet_csv[i], yellow_st)

wb.save(out_file)
