import sys
import csv
import xlwt

IDX_COL_KEY = 0
IDX_COL_END_POS = 9
IDX_COL_OAF = 5
IDX_COL_MAF = 6
IDX_VERT_SPLIT_POS = 13

sheet_csv = []
sheet_name = []
output_file = sys.argv[1]

sheets_count = (len(sys.argv)-2)/2
for isheet in xrange(sheets_count):
    sheet_name.append(sys.argv[isheet*2 + 2])
    sheet_csv.append(sys.argv[isheet*2 + 3])

def isFloat(string):
    try:
        float(string)
        return True
    except ValueError:
        return False

def explain_annotation(csv_record):
    col_ljb_phylop_pred         = 14
    col_ljb_sift_pred           = 16
    col_ljb_polyphen2_pred      = 18
    col_ljb_lrt_pred            = 20
    col_ljb_mutationtaster_pred = 22

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
    ws.col(IDX_COL_KEY).hidden = True
    ws.col(IDX_COL_END_POS).hidden = True
    ws.set_panes_frozen(True)
    ws.set_horz_split_pos(1)
    ws.set_vert_split_pos(IDX_VERT_SPLIT_POS)
    ws.set_remove_splits(True)


wb = xlwt.Workbook()
yellow_st = xlwt.easyxf('pattern: pattern solid, fore_colour yellow;')

for i in xrange(sheets_count):
    add_csv_sheet(wb, sheet_name[i], sheet_csv[i], yellow_st)

wb.save(output_file)

