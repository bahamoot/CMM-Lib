from __future__ import print_function
import sys
import csv
import xlwt
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
    ws = wb.add_sheet(sheet_name)
    with open(csv_file, 'rb') as csvfile:
        csv_records = list(csv.reader(csvfile, delimiter='\t'))
        csv_row = 0
        for xls_row in xrange(len(csv_records)):
            csv_record = csv_records[xls_row]
            for col in xrange(len(csv_record)):
                ws.write(csv_row, col, csv_record[col])
            csv_row += 1
    ws.set_panes_frozen(True)
    ws.set_horz_split_pos(1)

def add_selected_haplotypes_sheet(wb, sheet_name, haplotypes_csv, snps_csv):
    ws = wb.add_sheet(sheet_name)
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
            ws.write(row, item_idx, snp_record[item_idx])
    # Set SNPs extra header
    for header_idx in xrange(n_snp_col):
        if (header_idx != 0) and (header_idx != n_snp_col-1) and (header_idx != n_snp_col-2) :
            ws.write(HAPLOTYPE_INFO_SIZE, header_idx, snps_records[0][header_idx])
    # Add running numbers for the columns
    for running_idx in xrange(len(haplotypes_records) + n_snp_col -1 ):
        ws.write(0, running_idx, running_idx+1)
    # Add haplotypes information
    color_idx = 0
    for haplotype_idx in xrange(len(haplotypes_records)):
        col = haplotype_idx + n_snp_col - 1
        header_style = xlwt.easyxf('align: rotation 90')
        bp_style = xlwt.easyxf('')
        if (haplotype_idx > 0) and (float(haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_P_VALUE]) < float(p_value_significant_ratio)) :
            if color_idx >= len(bp_color_style):
                header_style = header_color_style[0]
                bp_style = bp_color_style[0]
            else:
                header_style = header_color_style[color_idx]
                bp_style = bp_color_style[color_idx]
                color_idx += 1
        ws.write(1, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_F_A], header_style)
        ws.write(2, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_F_U], header_style)
        ws.write(3, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_CHISQ], header_style)
        ws.write(4, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_OR], header_style)
        ws.write(5, col, haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_P_VALUE], header_style)
        if (haplotype_idx > 0):
            ws.col(col).width = 256 * 4
            # Map haplotype to the corresponding markers
            bps_list = haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_HAPLOTYPE]
            snps_list = haplotypes_records[haplotype_idx][IDX_COL_HAPLOTYPE_SNPS].split('|')
            for bp_idx in xrange(len(bps_list)):
                snp = snps_list[bp_idx]
                if snp in snp_row:
                    ws.write(snp_row[snp], col, bps_list[bp_idx], bp_style)
    for haplotype_row in xrange(1, 1 + HAPLOTYPE_INFO_SIZE):
        ws.row(haplotype_row).height = 256 * 3
    ws.set_panes_frozen(True)
    ws.set_horz_split_pos(HAPLOTYPE_INFO_SIZE + 1)
    ws.set_vert_split_pos(n_snp_col)

xlwt_colors = []
xlwt_colors.append('gold')
xlwt_colors.append('gray25')
#xlwt_colors.append('gray50')
xlwt_colors.append('plum')
xlwt_colors.append('green')
xlwt_colors.append('ice_blue')
#xlwt_colors.append('indigo')
#xlwt_colors.append('ivory')
xlwt_colors.append('lavender')
xlwt_colors.append('light_blue')
xlwt_colors.append('light_green')
xlwt_colors.append('light_orange')
xlwt_colors.append('gray40')
xlwt_colors.append('light_turquoise')
xlwt_colors.append('light_yellow')
xlwt_colors.append('lime')
xlwt_colors.append('magenta_ega')
#xlwt_colors.append('gray80')
xlwt_colors.append('ocean_blue')
xlwt_colors.append('olive_ega')
#xlwt_colors.append('olive_green')
xlwt_colors.append('orange')
xlwt_colors.append('pale_blue')
xlwt_colors.append('periwinkle')
xlwt_colors.append('pink')
xlwt_colors.append('gray_ega')
#xlwt_colors.append('purple_ega')
xlwt_colors.append('red')
xlwt_colors.append('rose')
xlwt_colors.append('sea_green')
xlwt_colors.append('silver_ega')
xlwt_colors.append('sky_blue')
xlwt_colors.append('tan')
xlwt_colors.append('teal')
#xlwt_colors.append('teal_ega')
xlwt_colors.append('turquoise')
#xlwt_colors.append('violet')
#xlwt_colors.append('white')
xlwt_colors.append('yellow')
xlwt_colors.append('aqua')
xlwt_colors.append('black')
xlwt_colors.append('blue')
xlwt_colors.append('blue_gray')
xlwt_colors.append('bright_green')
xlwt_colors.append('brown')
xlwt_colors.append('coral')
xlwt_colors.append('cyan_ega')
xlwt_colors.append('dark_blue')
#xlwt_colors.append('dark_blue_ega')
xlwt_colors.append('dark_green')
xlwt_colors.append('dark_green_ega')
#xlwt_colors.append('dark_purple')
#xlwt_colors.append('dark_red')
#xlwt_colors.append('dark_red_ega')
xlwt_colors.append('dark_teal')
xlwt_colors.append('dark_yellow')

bp_color_style = []
header_color_style = []
for color in xlwt_colors:
    bp_color_style.append(xlwt.easyxf('pattern: pattern solid, fore_colour ' + color + ';'))
    header_color_style.append(xlwt.easyxf('align: rotation 90; pattern: pattern solid, fore_colour ' + color + ';'))

wb = xlwt.Workbook()

add_selected_haplotypes_sheet(wb, 'selected haplotypes', haplotypes_file, snps_info_file)
for i in xrange(len(additional_csvs_list)):
    add_additional_csv_sheet(wb, additional_sheet_names[i], additional_sheet_csvs[i])

wb.save(out_file)

comment("************************************************** F I N I S H <" + script_name + "> **************************************************")
