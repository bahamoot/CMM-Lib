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

IDX_COL_TFAM_INDIVIDUAL_ID = 1

IDX_COL_TPED_SNPS = 1
TPED_INFO_SIZE    = 4

IDX_COL_SNP_CODE = 0

COLOR_RGB = OrderedDict()
COLOR_RGB['GREEN_ANNIKA'] = '#CCFFCC'
COLOR_RGB['PINK_ANNIKA'] = '#E6B9B8'
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
argp.add_argument('-H', dest='report_haplos_file', metavar='REPORT_HAPLOTYPES_FILE', help='Haplotypes that are related to the ones with significant p-value in assoc.hap format with odds ratio', required=True)
argp.add_argument('-F', dest='filtered_haplos_file', metavar='FILTERED_HAPLOTYPES_FILE', help='Good-enough haplos in assoc.hap format with odds ratio', default=None)
argp.add_argument('-f', dest='plink_individuals_haplos_tfile_prefix', metavar='FAMILIES_HAPLOTYPES_FILE', help='PLINK individuals haplos tfile prefix', default=None)
argp.add_argument('-p', dest='p_value_significant_ratio', metavar='P_VALUE', help='P-value significant ratio', default=0)
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
if args.filtered_haplos_file is not None:
    filtered_haplos_file = args.filtered_haplos_file
else:
    filtered_haplos_file = None
if args.plink_individuals_haplos_tfile_prefix is not None:
    plink_individuals_haplos_tfile_prefix = args.plink_individuals_haplos_tfile_prefix
else:
    plink_individuals_haplos_tfile_prefix = None
snps_info_file = args.snps_info_file
report_haplos_file = args.report_haplos_file
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
display_param("selected haplos file (-H)", report_haplos_file)
if filtered_haplos_file is not None:
    display_param("filtered haplos file (-F)", filtered_haplos_file)
if plink_individuals_haplos_tfile_prefix is not None:
    display_param("individuals haplos tfile prefix (-f)", plink_individuals_haplos_tfile_prefix)
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
display_param("P-value significant ratio (-p)", p_value_significant_ratio)
comment("")

# ****************************************  executing  ****************************************
def add_additional_csv_sheet(wb, sheet_name, csv_file):
    ws = wb.add_worksheet(sheet_name)
    with open(csv_file, 'rb') as csvfile:
        csv_recs = list(csv.reader(csvfile, delimiter='\t'))
        csv_row = 0
        for xls_row in xrange(len(csv_recs)):
            csv_rec = csv_recs[xls_row]
            for col in xrange(len(csv_rec)):
                ws.write(csv_row, col, csv_rec[col], default_cell_wb_format)
            csv_row += 1
	csvfile.close()
    ws.freeze_panes(1, 0)

def old_add_report_haplos_sheet(wb, sheet_name, report_haplos_csv, snps_csv):
    ws = wb.add_worksheet(sheet_name)
    with open(report_haplos_csv, 'rb') as csvfile:
        haplo_recs = list(csv.reader(csvfile, delimiter='\t'))
	csvfile.close()
    with open(snps_csv, 'rb') as csvfile:
        snps_recs = list(csv.reader(csvfile, delimiter='\t'))
	csvfile.close()
    n_snp_col = len(snps_recs[0])
    # Add SNPs information
    snp_rows = {}
    for snp_idx in xrange(1, len(snps_recs)):
        row = snp_idx + HAPLOTYPE_INFO_SIZE
        snp_rec = snps_recs[snp_idx]
        snp_rows[snp_rec[IDX_COL_SNP_CODE]] = row
        for item_idx in xrange(len(snp_rec)):
            ws.write(row, item_idx, snp_rec[item_idx], default_cell_wb_format)
    # Set SNPs extra header
    for header_idx in xrange(n_snp_col):
        if (header_idx != 0) and (header_idx != n_snp_col-1) and (header_idx != n_snp_col-2) :
            ws.write(HAPLOTYPE_INFO_SIZE, header_idx, snps_recs[0][header_idx], default_cell_wb_format)
    # Add running numbers for the columns
    for running_idx in xrange(len(haplo_recs) + n_snp_col -1 ):
        ws.write(0, running_idx, running_idx+1, default_cell_wb_format)
    # Add haplos information
    color_idx = 0
    for haplo_idx in xrange(len(haplo_recs)):
        col = haplo_idx + n_snp_col - 1
        hap_info_wb_format = default_hap_info_wb_format
        bp_wb_format = default_bp_wb_format
        if (haplo_idx > 0) and (float(haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_P_VALUE]) < float(p_value_significant_ratio)) :
            if color_idx >= len(color_bp_wb_formats):
                hap_info_wb_format = color_hap_info_wb_formats[0]
                bp_wb_format = color_bp_wb_formats[0]
            else:
                hap_info_wb_format = color_hap_info_wb_formats[color_idx]
                bp_wb_format = color_bp_wb_formats[color_idx]
                color_idx += 1
        ws.write(1, col, haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_F_A], hap_info_wb_format)
        ws.write(2, col, haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_F_U], hap_info_wb_format)
        ws.write(3, col, haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_CHISQ], hap_info_wb_format)
        ws.write(4, col, haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_OR], hap_info_wb_format)
        ws.write(5, col, haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_P_VALUE], hap_info_wb_format)
        if (haplo_idx > 0):
            # Map haplo to the corresponding markers
            bps_list = haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_HAPLOTYPE]
            snps_list = haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_SNPS].split('|')
            for bp_idx in xrange(len(bps_list)):
                snp = snps_list[bp_idx]
                if snp in snp_rows:
                    ws.write(snp_rows[snp], col, bps_list[bp_idx], bp_wb_format)
    for haplo_row in xrange(1, 1 + HAPLOTYPE_INFO_SIZE):
        ws.set_row(haplo_row, 45, None, {})
    ws.set_column(n_snp_col, len(haplo_recs)+n_snp_col-2, 1.5)
    ws.freeze_panes(HAPLOTYPE_INFO_SIZE + 1, n_snp_col)

def create_sheet_layout(ws, haplos_csv, snps_csv, haplos_dict=None, n_individual_haplos=0):
    with open(haplos_csv, 'rb') as csvfile:
        haplo_recs = list(csv.reader(csvfile, delimiter='\t'))
        csvfile.close()
    with open(snps_csv, 'rb') as csvfile:
        snps_recs = list(csv.reader(csvfile, delimiter='\t'))
	csvfile.close()
    n_snp_col = len(snps_recs[0])
    # Extract SNP
    snps_dict = {}
    for hap_idx in xrange(1, len(haplo_recs)):
	snps_list = haplo_recs[hap_idx][IDX_COL_HAPLOTYPE_SNPS].split('|')
	for snp in snps_list:
	    snps_dict[snp] = 1
    # Add SNPs information
    snp_rows = {}
    row_idx = HAPLOTYPE_INFO_SIZE
    for snp_idx in xrange(1, len(snps_recs)):
        snp_rec = snps_recs[snp_idx]
	snp_code = snp_rec[IDX_COL_SNP_CODE]
	if snp_code not in snps_dict:
	    continue
	row_idx += 1
        snp_rows[snp_code] = row_idx
        for item_idx in xrange(len(snp_rec)):
            ws.write(row_idx, item_idx, snp_rec[item_idx], default_cell_wb_format)
    # Set SNPs extra header
    for header_idx in xrange(n_snp_col):
        if (header_idx != 0) and (header_idx != n_snp_col-1) and (header_idx != n_snp_col-2) :
            ws.write(HAPLOTYPE_INFO_SIZE, header_idx, snps_recs[0][header_idx], default_cell_wb_format)
    if haplos_dict is not None:
	if n_individual_haplos == 1:
            ws.write(HAPLOTYPE_INFO_SIZE, n_snp_col, ws.get_name(), color_hap_info_wb_formats[0])
	else:
            ws.write(HAPLOTYPE_INFO_SIZE, n_snp_col, "shared", color_hap_info_wb_formats[0])
            ws.write(HAPLOTYPE_INFO_SIZE, n_snp_col+1, "unshared", color_hap_info_wb_formats[1])
	for haplo_idx in xrange(n_individual_haplos):
	    for snp_code in snp_rows:
		if snp_code in haplos_dict:
		    bp = haplos_dict[snp_code].split(" ")[haplo_idx]
		    if bp != "0":
			ws.write(snp_rows[snp_code], n_snp_col+haplo_idx, bp, color_bp_wb_formats[haplo_idx])
    # Add running numbers for the columns
    for running_idx in xrange(len(haplo_recs)+n_snp_col+n_individual_haplos-1 ):
        ws.write(0, running_idx, running_idx+1, default_cell_wb_format)
    # Add haplos header
    col = n_snp_col - 1
    header = haplo_recs[0]
    ws.write(1, col, header[IDX_COL_HAPLOTYPE_F_A], default_hap_info_wb_format)
    ws.write(2, col, header[IDX_COL_HAPLOTYPE_F_U], default_hap_info_wb_format)
    ws.write(3, col, header[IDX_COL_HAPLOTYPE_CHISQ], default_hap_info_wb_format)
    ws.write(4, col, header[IDX_COL_HAPLOTYPE_OR], default_hap_info_wb_format)
    ws.write(5, col, header[IDX_COL_HAPLOTYPE_P_VALUE], default_hap_info_wb_format)
    ws.set_row(1, 45, None, {})
    ws.set_row(2, 45, None, {})
    ws.set_row(3, 30, None, {})
    ws.set_row(4, 40, None, {})
    ws.set_row(5, 55, None, {})
    ws.set_column(n_snp_col, len(haplo_recs)+n_snp_col+n_individual_haplos-2, 1.5)
    #ws.set_column(n_snp_col+n_individual_haplos, len(haplo_recs)+n_snp_col+n_individual_haplos-2, 1.5)
    ws.freeze_panes(HAPLOTYPE_INFO_SIZE+1, n_snp_col+n_individual_haplos )

    return (snp_rows, n_snp_col+n_individual_haplos, haplo_recs)

def add_report_haplos_sheet(wb, sheet_name, report_haplos_csv, snps_csv):
    ws = wb.add_worksheet(sheet_name)
    (snp_rows, start_col_idx0, haplo_recs) = create_sheet_layout(ws, report_haplos_csv, snps_csv)
    # Add haplos information
    color_idx = 0
    for haplo_idx in xrange(1, len(haplo_recs)):
	haplo_rec = haplo_recs[haplo_idx]
        col = haplo_idx + start_col_idx0 - 1
        hap_info_wb_format = default_hap_info_wb_format
        bp_wb_format = default_bp_wb_format
        if (haplo_idx > 0) and (float(haplo_recs[haplo_idx][IDX_COL_HAPLOTYPE_P_VALUE]) < float(p_value_significant_ratio)) :
            if color_idx >= len(color_bp_wb_formats):
                hap_info_wb_format = color_hap_info_wb_formats[0]
                bp_wb_format = color_bp_wb_formats[0]
            else:
                hap_info_wb_format = color_hap_info_wb_formats[color_idx]
                bp_wb_format = color_bp_wb_formats[color_idx]
                color_idx += 1
        # set haplotype stats
        ws.write(1, col, haplo_rec[IDX_COL_HAPLOTYPE_F_A], hap_info_wb_format)
        ws.write(2, col, haplo_rec[IDX_COL_HAPLOTYPE_F_U], hap_info_wb_format)
        ws.write(3, col, haplo_rec[IDX_COL_HAPLOTYPE_CHISQ], hap_info_wb_format)
        ws.write(4, col, haplo_rec[IDX_COL_HAPLOTYPE_OR], hap_info_wb_format)
        ws.write(5, col, haplo_rec[IDX_COL_HAPLOTYPE_P_VALUE], hap_info_wb_format)
        # Map haplo to the corresponding markers
        bps_list = haplo_rec[IDX_COL_HAPLOTYPE_HAPLOTYPE]
        snps_list = haplo_rec[IDX_COL_HAPLOTYPE_SNPS].split('|')
        for bp_idx in xrange(len(bps_list)):
	    bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if snp_code in snp_rows:
                ws.write(snp_rows[snp_code], col, bp, bp_wb_format)

def add_individual_haplos_sheets(wb, filtered_haplos_csv, snps_csv, individuals_haplos_tfile_prefix):
    with open(individuals_haplos_tfile_prefix+'.tfam', 'rb') as csvfile:
        individual_recs = list(csv.reader(csvfile, delimiter='\t'))
	csvfile.close()
    for individual_idx in xrange(len(individual_recs)):
	individual_rec = individual_recs[individual_idx]
	haplos_dict = {}
        with open(individuals_haplos_tfile_prefix+'.tped', 'rb') as csvfile:
            haplos_recs = csv.reader(csvfile, delimiter='\t')
            for haplos_rec in haplos_recs:
		haplos_dict[haplos_rec[IDX_COL_TPED_SNPS]] = haplos_rec[TPED_INFO_SIZE+individual_idx]
	    csvfile.close()
	add_individual_haplos_sheet(wb, individual_rec[IDX_COL_TFAM_INDIVIDUAL_ID], filtered_haplos_csv, snps_csv, haplos_dict)

def add_individual_haplos_sheet(wb, individual_id, filtered_haplos_csv, snps_csv, haplos_dict):
    if individual_id.find('_shared_only') == 9:
        ws = wb.add_worksheet('matched with '+individual_id.replace('_shared_only', ''))
	n_individual_haplos = 1
    else:
        ws = wb.add_worksheet('matched with '+individual_id)
	n_individual_haplos = 2
    (snp_rows, start_col_idx0, haplo_recs) = create_sheet_layout(ws, filtered_haplos_csv, snps_csv, haplos_dict=haplos_dict, n_individual_haplos=n_individual_haplos)
    # Add haplos information
    color_idx = 0
    for haplo_idx in xrange(1, len(haplo_recs)):
	haplo_rec = haplo_recs[haplo_idx]
        col = haplo_idx + start_col_idx0 - 1
	# get cell format
        hap_info_wb_format = default_hap_info_wb_format
        bp_wb_format = default_bp_wb_format
	matched_individual_haplos = []
	compared_haplos = []
	for individual_idx in xrange(n_individual_haplos):
	    matched_individual_haplos.append(True)
	    compared_haplos.append(False)
        bps_list = haplo_rec[IDX_COL_HAPLOTYPE_HAPLOTYPE]
        snps_list = haplo_rec[IDX_COL_HAPLOTYPE_SNPS].split('|')
        for bp_idx in xrange(len(bps_list)):
	    filtered_bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if (snp_code in snp_rows) and (snp_code in haplos_dict) :
		for individual_idx in xrange(n_individual_haplos):
		    individual_bp = haplos_dict[snp_code].split(" ")[individual_idx]
		    if individual_bp == "0":
		        continue
		    if filtered_bp != individual_bp:
			matched_individual_haplos[individual_idx] = False
		    else:
			compared_haplos[individual_idx] = True
	for individual_idx in xrange(n_individual_haplos):
	    if (matched_individual_haplos[individual_idx] == True) and (compared_haplos[individual_idx] == True):
                hap_info_wb_format = color_hap_info_wb_formats[individual_idx]
                bp_wb_format = color_bp_wb_formats[individual_idx]
		break
        # set haplotype stats
        ws.write(1, col, haplo_rec[IDX_COL_HAPLOTYPE_F_A], hap_info_wb_format)
        ws.write(2, col, haplo_rec[IDX_COL_HAPLOTYPE_F_U], hap_info_wb_format)
        ws.write(3, col, haplo_rec[IDX_COL_HAPLOTYPE_CHISQ], hap_info_wb_format)
        ws.write(4, col, haplo_rec[IDX_COL_HAPLOTYPE_OR], hap_info_wb_format)
        ws.write(5, col, haplo_rec[IDX_COL_HAPLOTYPE_P_VALUE], hap_info_wb_format)
        # Map filtered haplo to the corresponding markers
        bps_list = haplo_rec[IDX_COL_HAPLOTYPE_HAPLOTYPE]
        snps_list = haplo_rec[IDX_COL_HAPLOTYPE_SNPS].split('|')
        for bp_idx in xrange(len(bps_list)):
	    filtered_bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if snp_code in snp_rows:
                ws.write(snp_rows[snp_code], col, filtered_bp, bp_wb_format)


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
#    comment(color)
    color_bp_hash_format = default_bp_hash_format.copy()
    color_bp_hash_format['bg_color'] = COLOR_RGB[color]
    color_bp_wb_formats.append(wb.add_format(color_bp_hash_format))
    color_hap_info_hash_format = default_hap_info_hash_format.copy()
    color_hap_info_hash_format['bg_color'] = COLOR_RGB[color]
    color_hap_info_wb_formats.append(wb.add_format(color_hap_info_hash_format))
if (filtered_haplos_file is not None) and (plink_individuals_haplos_tfile_prefix is not None):
    add_individual_haplos_sheets(wb, filtered_haplos_file, snps_info_file, plink_individuals_haplos_tfile_prefix)
add_report_haplos_sheet(wb, 'significant haplos', report_haplos_file, snps_info_file)
#old_add_report_haplos_sheet(wb, 'old significant haplos', report_haplos_file, snps_info_file)

if filtered_haplos_file is not None:
    add_additional_csv_sheet(wb, "filtered-assoc.hap", filtered_haplos_file)
add_additional_csv_sheet(wb, "input", report_haplos_file)
for i in xrange(len(additional_csvs_list)):
    add_additional_csv_sheet(wb, additional_sheet_names[i], additional_sheet_csvs[i])

wb.close()

comment("************************************************** F I N I S H <" + script_name + "> **************************************************")
