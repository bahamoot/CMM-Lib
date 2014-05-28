from __future__ import print_function
from collections import OrderedDict
import sys
import csv
import xlsxwriter
import ntpath

import argparse

IDX_COL_HAPLOTYPE_HAPLOTYPE = 1
IDX_COL_HAPLOTYPE_F_A       = 2
IDX_COL_HAPLOTYPE_F_U       = 3
IDX_COL_HAPLOTYPE_CHISQ     = 4
IDX_COL_HAPLOTYPE_OR        = 5
IDX_COL_HAPLOTYPE_P_VALUE   = 7
IDX_COL_HAPLOTYPE_SNPS      = 8
HAPLOTYPE_INFO_SIZE         = 5

IDX_COL_SNP_SNP = 0

COLOR_RGB = OrderedDict()
COLOR_RGB['GOLD'] = '#FFD700'
COLOR_RGB['GRAY25'] = '#DCDCDC'
COLOR_RGB['ROYAL_BLUE'] = '#4169E1'
#COLOR_RGB['=('gray50')
COLOR_RGB['PLUM'] = '#8E4585'
COLOR_RGB['GREEN'] = '#008000'
COLOR_RGB['ICEBLUE'] = '#A5F2F3'
#COLOR_RGB['=('indigo')
#COLOR_RGB['=('ivory')
#COLOR_RGB['LAVENDER'] = '#E6E6FA'
COLOR_RGB['LIGHT_BLUE'] = '#ADD8E6'
COLOR_RGB['LIGHT_GREEN'] = '#90EE90'
#COLOR_RGB[''] = 'light_orange')
COLOR_RGB['GRAY40'] = '#808080'
#COLOR_RGB['PALE_TURQUOISE'] = '#AFEEEE'
COLOR_RGB['LIGHT_YELLOW'] = '#FFFFE0'
COLOR_RGB['LIME'] = '#00FF00'
COLOR_RGB['MAGENTA'] = '#FF00FF'
#COLOR_RGB['=('gray80')
#COLOR_RGB['OCEAN_BLUE'] = '#03719C'
COLOR_RGB['OLIVE'] = '#808000'
#COLOR_RGB['=('olive_green')
COLOR_RGB['ORANGE'] = '#FF6600'
COLOR_RGB['SKY_BLUE'] = '#87CEEB'
#COLOR_RGB['PERIWINKLE'] = '#CCCCFF'
#COLOR_RGB['PINK'] = '#FF00FF'
COLOR_RGB['DARK_SLATE_GRAY'] = '#2F4F4F'
COLOR_RGB['PURPLE'] = '#800080'
COLOR_RGB['RED'] = '#FF0000'
COLOR_RGB['ROSY_BROWN'] = '#BC8F8F'
#COLOR_RGB['SEA_GREEN'] = '#2E8B57'
COLOR_RGB['SILVER'] = '#C0C0C0'
COLOR_RGB['SKY_BLUE'] = '#87CEEB'
COLOR_RGB['TAN'] = '#D2B48C'
COLOR_RGB['TEAL'] = '#008080'
#COLOR_RGB['=('teal_ega')
COLOR_RGB['TURQUOISE'] = '#40E0D0'
#COLOR_RGB['=('violet')
#COLOR_RGB['=('white')
COLOR_RGB['YELLOW'] = '#FFFF00'
COLOR_RGB['MEDIUM_AQUA_MARINE'] = '#66CDAA'
#COLOR_RGB['BLACK'] = '#000000'
COLOR_RGB['BLUE'] = '#0000FF'
COLOR_RGB['SLATE_GRAY'] = '#708090'
COLOR_RGB['LIME_GREEN'] = '#32CD32'
COLOR_RGB['BROWN'] = '#800000'
COLOR_RGB['CORAL'] = '#FF7F50'
COLOR_RGB['CYAN'] = '#00FFFF'
COLOR_RGB['DARK_BLUE'] = '#00008B'
#COLOR_RGB['=('dark_blue_ega')
#COLOR_RGB['DARK_GREEN'] = '#006400'
COLOR_RGB['YELLOW_GREEN'] = '#9ACD32'
#COLOR_RGB['=('dark_purple')
#COLOR_RGB['=('dark_red')
#COLOR_RGB['=('dark_red_ega')
COLOR_RGB['DODGER_BLUE'] = '#1E90FF'
COLOR_RGB['GOLDEN_ROD'] = '#DAA520'


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
argp.add_argument('-A', dest='additional_csvs', metavar='ADDITIONAL_CSVS', help='list of additional information csv-format file in together with their name in comma and colon separators format', default=None)
argp.add_argument('-S', dest='snps_info_file', metavar='SNPS_INFO_FILE', help='a file to descript SNPs annotation', required=True)
argp.add_argument('-H', dest='haplotypes_file', metavar='HAPLOTYPES_FILE', help='assoc.hap file with odds ratio', required=True)
argp.add_argument('-P', dest='p_value_significant_ratio', metavar='P_VALUE', help='P-value significant ratio', default=0)
args = argp.parse_args()

## ****************************************  parse arguments into local global variables  ****************************************
out_file = args.out_file
additional_sheet_names = []
additional_sheet_csvs = []
if args.additional_csvs is not None:
    additional_csvs_list = args.additional_csvs.split(':')
    for i in xrange(len(additional_csvs_list)):
        sheet_info = additional_csvs_list[i].split(',')
        additional_sheet_names.append(sheet_info[0])
        additional_sheet_csvs.append(sheet_info[1])
else:
    additional_csvs_list = []
snps_info_file = args.snps_info_file
haplotypes_file = args.haplotypes_file
p_value_significant_ratio = args.p_value_significant_ratio


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
display_param("SNPs information file (-S)", snps_info_file)
display_param("haplotypes file (-H)", haplotypes_file)
comment("")

if args.additional_csvs is not None:
    ## display additional_csvs configuration
    display_header("additional_csvs configuration (-s)(" + str(len(additional_csvs_list)) + " sheet(s))")
    for i in xrange(len(additional_csvs_list)):
        display_param("additional sheet name #"+str(i+1), additional_sheet_names[i])
        display_param("additional sheet csv  #"+str(i+1), additional_sheet_csvs[i])
    comment("")

## display optional configuration
display_header("optional configuration")
display_param("P-value significant ratio", p_value_significant_ratio)
comment("")

# ****************************************  executing  ****************************************
def add_additional_csv_sheet(wb, sheet_name, csv_file):
    ws = wb.add_worksheet(sheet_name)
    with open(csv_file, 'rb') as csvfile:
        csv_records = list(csv.reader(csvfile, delimiter='\t'))
        csv_row = 0
        for xls_row in xrange(len(csv_records)):
            csv_record = csv_records[xls_row]
            for col in xrange(len(csv_record)):
                ws.write(csv_row, col, csv_record[col], default_cell_wb_format)
            csv_row += 1
#    ws.set_panes_frozen(True)
    ws.freeze_panes(1, 0)
#    ws.set_horz_split_pos(1)

def add_selected_haplotypes_sheet(wb, sheet_name, haplotypes_csv, snps_csv):
    ws = wb.add_worksheet(sheet_name)
    with open(haplotypes_csv, 'rb') as csvfile:
        haplotypes_records = list(csv.reader(csvfile, delimiter='\t'))
    with open(snps_csv, 'rb') as csvfile:
        snps_records = list(csv.reader(csvfile, delimiter='\t'))
    n_snp_col = len(snps_records[0])
    # Add SNPs information
    snp_row = {}
    for snp_idx in xrange(1, len(snps_records)):
        row = snp_idx + HAPLOTYPE_INFO_SIZE
        snp_record = snps_records[snp_idx]
        snp_row[snp_record[IDX_COL_SNP_SNP]] = row
        for item_idx in xrange(len(snp_record)):
            ws.write(row, item_idx, snp_record[item_idx], default_cell_wb_format)
    # Set SNPs extra header
    for header_idx in xrange(n_snp_col):
        if (header_idx != 0) and (header_idx != n_snp_col-1) and (header_idx != n_snp_col-2) :
            ws.write(HAPLOTYPE_INFO_SIZE, header_idx, snps_records[0][header_idx], default_cell_wb_format)
    # Add running numbers for the columns
    for running_idx in xrange(len(haplotypes_records) + n_snp_col -1 ):
        ws.write(0, running_idx, running_idx+1, default_cell_wb_format)
    # Add haplotypes information
    color_idx = 0
    for haplotype_idx in xrange(len(haplotypes_records)):
        col = haplotype_idx + n_snp_col - 1
        hash_info_wb_format = default_hap_info_wb_format
        bp_wb_format = default_bp_wb_format
        if (haplotype_idx > 0) and (float(haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_P_VALUE]) < float(p_value_significant_ratio)) :
            if color_idx >= len(color_bp_wb_formats):
                hash_info_wb_format = color_hap_info_wb_formats[0]
                bp_wb_format = color_bp_wb_formats[0]
            else:
                hash_info_wb_format = color_hap_info_wb_formats[color_idx]
                bp_wb_format = color_bp_wb_formats[color_idx]
                color_idx += 1
        ws.write(1, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_F_A], hash_info_wb_format)
        ws.write(2, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_F_U], hash_info_wb_format)
        ws.write(3, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_CHISQ], hash_info_wb_format)
        ws.write(4, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_OR], hash_info_wb_format)
        ws.write(5, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_P_VALUE], hash_info_wb_format)
        if (haplotype_idx > 0):
            # Map haplotype to the corresponding markers
            bps_list = haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_HAPLOTYPE]
            snps_list = haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_SNPS].split('|')
            for bp_idx in xrange(len(bps_list)):
                snp = snps_list[bp_idx]
                if snp in snp_row:
                    ws.write(snp_row[snp], col, bps_list[bp_idx], bp_wb_format)
    for haplotype_row in xrange(1, 1 + HAPLOTYPE_INFO_SIZE):
        ws.set_row(haplotype_row, 45, None, {})
    ws.set_column(n_snp_col, len(haplotypes_records)+n_snp_col-2, 1.5)
    ws.freeze_panes(HAPLOTYPE_INFO_SIZE + 1, n_snp_col)



wb = xlsxwriter.Workbook(out_file)

default_cell_hash_format = {'font_name': 'Arial', 'font_size': 10}
default_cell_wb_format   = wb.add_format(default_cell_hash_format)
default_hap_info_hash_format = default_cell_hash_format.copy()
default_hap_info_hash_format['rotation'] = 90
default_hap_info_wb_format = wb.add_format(default_hap_info_hash_format)
default_bp_hash_format = default_cell_hash_format.copy()
default_bp_hash_format['align'] = 'center'
default_bp_wb_format = wb.add_format(default_bp_hash_format)
color_bp_wb_formats = []
color_hap_info_wb_formats = []
for color in COLOR_RGB:
    comment(color)
    color_bp_hash_format = default_bp_hash_format.copy()
    color_bp_hash_format['bg_color'] = COLOR_RGB[color]
    color_bp_wb_formats.append(wb.add_format(color_bp_hash_format))
    color_hap_info_hash_format = default_hap_info_hash_format.copy()
    color_hap_info_hash_format['bg_color'] = COLOR_RGB[color]
    color_hap_info_wb_formats.append(wb.add_format(color_hap_info_hash_format))
add_selected_haplotypes_sheet(wb, 'selected haplotypes', haplotypes_file, snps_info_file)

for i in xrange(len(additional_csvs_list)):
    add_additional_csv_sheet(wb, additional_sheet_names[i], additional_sheet_csvs[i])

wb.close()

comment("************************************************** F I N I S H <" + script_name + "> **************************************************")
