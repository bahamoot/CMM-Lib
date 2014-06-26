from __future__ import print_function
from collections import OrderedDict
import sys
import csv
import xlsxwriter
import ntpath

import argparse

# ****************************** define constants ******************************
IDX_COL_HAPASSOC_HAPLO   = 1
IDX_COL_HAPASSOC_F_A     = 2
IDX_COL_HAPASSOC_F_U     = 3
IDX_COL_HAPASSOC_CHISQ   = 4
IDX_COL_HAPASSOC_OR      = 5
IDX_COL_HAPASSOC_P_VALUE = 7
IDX_COL_HAPASSOC_SNPS    = 8
HAPLO_INFO_SIZE          = 5

IDX_COL_MAP_MARKER = 1

IDX_COL_PED_FAM_ID = 0
IDX_COL_PED_INDV_ID = 1

IDX_COL_SNP_CODE = 0
IDX_COL_SNP_F_MISS_A = 1
IDX_COL_SNP_F_MISS_U = 2
IDX_COL_SNP_CHROM = 3

COLOR_RGB = OrderedDict()
COLOR_RGB['GREEN_ANNIKA'] = '#CCFFCC'
COLOR_RGB['PINK_ANNIKA'] = '#E6B9B8'
COLOR_RGB['GOLD'] = '#FFD700'
COLOR_RGB['GRAY25'] = '#DCDCDC'
COLOR_RGB['PLUM'] = '#8E4585'
COLOR_RGB['GREEN'] = '#008000'
COLOR_RGB['LIGHT_GREEN'] = '#90EE90'
COLOR_RGB['SKY_BLUE'] = '#87CEEB'
COLOR_RGB['GRAY40'] = '#808080'
COLOR_RGB['LIGHT_YELLOW'] = '#FFFFE0'
COLOR_RGB['OLIVE'] = '#808000'
COLOR_RGB['ORANGE'] = '#FF6600'
COLOR_RGB['DARK_SLATE_GRAY'] = '#2F4F4F'
COLOR_RGB['PURPLE'] = '#800080'
COLOR_RGB['RED'] = '#FF0000'
COLOR_RGB['ROSY_BROWN'] = '#BC8F8F'
COLOR_RGB['SILVER'] = '#C0C0C0'
COLOR_RGB['SKY_BLUE'] = '#87CEEB'
COLOR_RGB['TAN'] = '#D2B48C'
COLOR_RGB['TEAL'] = '#008080'
COLOR_RGB['TURQUOISE'] = '#40E0D0'
COLOR_RGB['YELLOW'] = '#FFFF00'
COLOR_RGB['MEDIUM_AQUA_MARINE'] = '#66CDAA'
COLOR_RGB['BLUE'] = '#0000FF'
COLOR_RGB['SLATE_GRAY'] = '#708090'
COLOR_RGB['LIME_GREEN'] = '#32CD32'
COLOR_RGB['BROWN'] = '#800000'
COLOR_RGB['CORAL'] = '#FF7F50'
COLOR_RGB['DARK_BLUE'] = '#00008B'
COLOR_RGB['YELLOW_GREEN'] = '#9ACD32'
COLOR_RGB['DODGER_BLUE'] = '#1E90FF'
COLOR_RGB['GOLDEN_ROD'] = '#DAA520'
COLOR_RGB['CYAN'] = '#00FFFF'
COLOR_RGB['ROYAL_BLUE'] = '#4169E1'
COLOR_RGB['LIME'] = '#00FF00'
COLOR_RGB['MAGENTA'] = '#FF00FF'
COLOR_RGB['ICEBLUE'] = '#A5F2F3'
COLOR_RGB['LIGHT_BLUE'] = '#ADD8E6'

OTH_INDV_COLORS = ['ICEBLUE', 'LIGHT_BLUE']
DFLT_FMT = 'default_format'

script_name = ntpath.basename(sys.argv[0])

def comment(*objs):
    print("##", *objs, end='\n', file=sys.stderr)

def disp_header(header_txt):
    comment(header_txt)

def disp_subheader(subheader_txt):
    comment("  " + subheader_txt)

def disp_param(param_name, param_value):
    fmt = "  {name:<45}{value}"
    comment(fmt.format(name=param_name+":", value=param_value))

def disp_subparam(subparam_name, subparam_value):
    disp_param("  "+subparam_name, subparam_value)

# ****************************** define classes ******************************
class PlinkBase(object):
    """ A base object of PLINK class """

    def __init__(self):
        pass

    def info(self, info_msg):
        print >> sys.stderr, info_msg

    def throw(self, err_msg):
        raise Exception(err_msg)

    @property
    def current_func_name(self):
        frame = inspect.currentframe(1)
        code  = frame.f_code
        globs = frame.f_globals
        functype = type(lambda: 0)
        funcs = []
        for func in gc.get_referrers(code):
            if type(func) is functype:
                if getattr(func, "func_code", None) is code:
                    if getattr(func, "func_globals", None) is globs:
                        funcs.append(func)
                        if len(funcs) > 1:
                            return None
        return funcs[0].__name__ if funcs else None

class CellFormatManager(PlinkBase):
    """ A class to define cell format property """

    def __init__(self, work_book, color_dict):
        self.__wb = work_book
        self.__color_dict = color_dict
        self.__dflt_hash_fmt = {'font_name': 'Arial', 'font_size': 10}
        self.__dflt_fmt = self.__add_fmt(self.__dflt_hash_fmt)
        self.__init_color_formats()

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"color dict: ": self.__color_dict,
                "number of color: ": self.n_colors,
                }

    def __add_fmt(self, fmt_dict):
        return self.__wb.add_format(fmt_dict)

    @property
    def default_format(self):
        return self.__dflt_fmt

    def __init_color_format(self, default_hash_format):
        fmts = OrderedDict()
        fmts[DFLT_FMT] = self.__add_fmt(default_hash_format)
        colors = self.__color_dict.keys()
        for color_idx in xrange(len(colors)):
            color = colors[color_idx]
            color_hash_fmt = default_hash_format.copy()
            color_hash_fmt['bg_color'] = self.__color_dict[color]
            fmts[color_idx] = self.__add_fmt(color_hash_fmt)
            fmts[color] = fmts[color_idx]
        return fmts

    def __init_color_formats(self):
        dflt_bp_hash_fmt = self.__dflt_hash_fmt.copy()
        dflt_bp_hash_fmt['align'] = 'center'
        self.__bp_fmts = self.__init_color_format(dflt_bp_hash_fmt)
        dflt_stat_hash_fmt = self.__dflt_hash_fmt.copy()
        dflt_stat_hash_fmt['rotation'] = 90
        self.__stat_fmts = self.__init_color_format(dflt_stat_hash_fmt)

    @property
    def n_colors(self):
        return len(self.__color_dict)

    @property
    def bp_fmts(self):
        return self.__bp_fmts

    @property
    def stat_fmts(self):
        return self.__stat_fmts

class PlinkPedRecord(PlinkBase):
    """ A class to parse information for each record in Pedigree file """

    def __init__(self, data):
        self.__data = data
        self.__gts = None

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"raw data: ": self.__data,
                "individual ID": self.indv_id,
                "ploidy: ": self.n_ploid,
                "colors: ": self.colors,
                }

    @property
    def fam_id(self):
        return self.__data[IDX_COL_PED_FAM_ID]

    @property
    def indv_id(self):
        return self.__data[IDX_COL_PED_INDV_ID].replace('_shared_only', '')

    @property
    def n_ploid(self):
        if self.__data[IDX_COL_PED_INDV_ID].find('_shared_only') == 9:
            return 1
        return 2

    @property
    def gts(self):
        if self.__gts is None:
            return self.__data[6:len(self.__data)]
        else:
            return self.__gts

    @gts.setter
    def gts(self, value):
        self.__gts = value

class PlinkPedManager(PlinkBase):
    """ A manager class to handle PLINK pedigree file """

    def __init__(self, file_name):
        self.__file_name = file_name
        self.__indv_ids = None

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"ped file name": self.__file_name,
                }
    @property
    def indv_infos(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            for raw_indv_info in csv_reader:
                yield(PlinkPedRecord(raw_indv_info))
            csvfile.close()

    def get_indv_info(self, indv_id):
        for indv_info in self.indv_infos:
            if indv_info.indv_id == indv_id:
                return indv_info

    @property
    def indv_ids(self):
        if self.__indv_ids is not None:
            return self.__indv_ids
        else:
            self.__indv_ids = map(lambda x: x.indv_id, self.indv_infos)
            return self.__indv_ids

class PlinkMapManager(PlinkBase, list):
    """ A manager class to handle PLINK map file """

    def __init__(self, file_name):
        self.__file_name = file_name
        self.__load_markers()

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"map file name": self.__file_name,
                "number of markers": len(self),
                }

    def __load_markers(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            for marker_info in csv_reader:
                self.append(marker_info[IDX_COL_MAP_MARKER])
            csvfile.close()

class PlinkGTManager(PlinkBase):
    """ A manager class to handle PLINK genotyping data """

    def __init__(self, gt_file_prefix, special_indv_infos):
        self.__gt_file_prefix = gt_file_prefix
        self.__map_mg = PlinkMapManager(gt_file_prefix + '.map')
        self.__ped_mg = PlinkPedManager(gt_file_prefix + '.ped')
        self.__special_indv_infos = {}
        for special_indv_info in special_indv_infos:
            indv_id = special_indv_info.indv_id
            self.__special_indv_infos[indv_id] = special_indv_info

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"genotyping file prefix": self.__gt_file_prefix,
                "individual IDs": self.indv_ids,
                }

    def map_gts_to_snps(self, indv_haplos, markers):
        gts = {}
        for idx in xrange(len(markers)):
            gts[markers[idx]] = indv_haplos.gts[idx]
        return gts

    @property
    def indv_ids(self):
        return self.__ped_mg.indv_ids

    def get_indv_info(self, indv_id):
        indv_info = self.__ped_mg.get_indv_info(indv_id)
        indv_info.gts = self.map_gts_to_snps(indv_info, self.__map_mg)
        indv_id = indv_info.indv_id
        if indv_id in self.__special_indv_infos:
            indv_info.colors = self.__special_indv_infos[indv_id].colors
        else:
            indv_info.colors = OTH_INDV_COLORS
        return indv_info

    @property
    def special_indv_ids(self):
        return self.__special_indv_infos.keys()

class PlinkAssocHapRecord(PlinkBase):
    """ A class to parse each record of haplotype association study result """

    def __init__(self, data):
        self.__data = data

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"raw data": self.__data,
                "haplotype": self.haplotype,
                "f_a": self.f_a,
                "f_u": self.f_u,
                "chisq": self.chisq,
                "OR": self.or_value,
                "p value": self.p_value,
                "snps": self.snps,
                }

    @property
    def haplotype(self):
        return self.__data[IDX_COL_HAPASSOC_HAPLO]

    @property
    def f_a(self):
        return float(self.__data[IDX_COL_HAPASSOC_F_A])

    @property
    def f_u(self):
        return float(self.__data[IDX_COL_HAPASSOC_F_U])

    @property
    def chisq(self):
        return float(self.__data[IDX_COL_HAPASSOC_CHISQ])

    @property
    def or_value(self):
        return float(self.__data[IDX_COL_HAPASSOC_OR])

    @property
    def p_value(self):
        return float(self.__data[IDX_COL_HAPASSOC_P_VALUE])

    @property
    def snps(self):
        return self.__data[IDX_COL_HAPASSOC_SNPS].split('|')

class PlinkAssocHapManager(PlinkBase):
    """ A class to handle PLINK haplotype association study file """

    def __init__(self, hap_assoc_file):
        self.__file_name = hap_assoc_file
        self.__haplos_count = None

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"asso.hap file name": self.__file_name,
                "header": self.header,
                "number of haplotypes": self.haplos_count,
                }

    @property
    def header(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            header = csv_reader.next()
            csvfile.close()
        return header

    @property
    def haplos_info(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            csv_reader.next()
            for haplo_info in csv_reader:
                yield(PlinkAssocHapRecord(haplo_info))
            csvfile.close()

    @property
    def haplos_count(self):
        if self.__haplos_count is not None:
            return self.__haplos_count
        else:
            self.__haplos_count = len(list(self.haplos_info))
            return self.__haplos_count

class SnpsInfoManager(PlinkBase):
    """ A class to handle SNPs information """

    def __init__(self, snps_info_file):
        self.__file_name = snps_info_file

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"snps infomation file name": self.__file_name,
                "header": self.header,
                "record size": self.record_size,
                "number of snps": len(list(self.snps_info)),
                }

    @property
    def header(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            header = csv_reader.next()
            csvfile.close()
        return header

    @property
    def snps_info(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            csv_reader.next()
            for snp_info in csv_reader:
                yield(snp_info)
            csvfile.close()

    @property
    def record_size(self):
        return len(self.header)

class SpecialStudyIndividualInfo(PlinkBase):
    """ A class to parse information for each record in Pedigree file """

    def __init__(self, raw_info):
        self.__raw_info = raw_info
        self.__info = raw_info.split('|')
        if len(self.__info) < 3:
            self.__colors = [self.__info[1], self.__info[1]]
        else:
            self.__colors = [self.__info[1], self.__info[2]]

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return {"raw info: ": self.__raw_info,
                "individual ID": self.indv_id,
                "color 0: ": self.colors[0],
                "color 1: ": self.colors[1],
                }

    @property
    def indv_id(self):
        return self.__info[0].replace('_shared_only', '')

    @property
    def colors(self):
        return self.__colors

# ****************************** get arguments ******************************
argp = argparse.ArgumentParser(description="A script to manipulate csv files and group them into one xls")
tmp_help=[]
tmp_help.append("output xls file name")
argp.add_argument('-o', dest='out_file',
                        help='output xls file name',
                        required=True)
argp.add_argument('-A', dest='addn_csvs',
                        metavar='ADDITIONAL_CSVS',
                        help='list of addn informaion csv-format file in together with their name in comma and colon separators format',
                        default=None)
argp.add_argument('-S', dest='snps_info_file',
                        metavar='SNPS_INFO_FILE',
                        help='a file to descript SNPs annotation',
                        required=True)
argp.add_argument('-H', dest='report_haplos_file',
                        metavar='REPORT_HAPLOS_FILE',
                        help='Haplotypes that are related to the ones with significant p-value in assoc.hap format with odds ratio',
                        required=True)
argp.add_argument('-F', dest='fltred_haplos_file',
                        metavar='FILTERED_HAPLOS_FILE',
                        help='Good-enough haplos in assoc.hap format with odds ratio',
                        required=True)
argp.add_argument('-f', dest='plink_indvs_haplos_file_prefix',
                        metavar='FILE_PREFIX',
                        help='PLINK indvs haplos file prefix',
                        default=None)
argp.add_argument('-s', dest='special_indv_infos',
                        metavar='INDIVIDUAL_CODES',
                        help='information of individual(s) to be specially studied, in this version all haplotypes from other individuals will be align with them to see who common the haplotypes in question in the population ',
                        default=None)
argp.add_argument('-p', dest='p_value_sig_ratio',
                        metavar='P_VALUE',
                        help='P-value significant ratio',
                        default=0)
argp.add_argument('-D', dest='dev_mode',
                        action='store_true',
                        help='To enable development mode, this will effect how the result is shown up',
                        default=False)
argp.add_argument('-I', dest='show_indv_haplo_sheets',
                        action='store_true',
                        help='To enable showing sheets, one for each individual, which map individual haplotype(s) with filtered assoc.hap ',
                        default=False)
args = argp.parse_args()

## **************  parse arguments into local global variables  **************
out_file = args.out_file
addn_sheet_names = []
addn_sheet_csvs = []
if args.addn_csvs is not None:
    addn_csvs_list = args.addn_csvs.split(':')
    for i in xrange(len(addn_csvs_list)):
        sheet_info = addn_csvs_list[i].split(',')
        addn_sheet_names.append(sheet_info[0])
        addn_sheet_csvs.append(sheet_info[1])
else:
    addn_csvs_list = []
fltred_haplos_file = args.fltred_haplos_file
if args.plink_indvs_haplos_file_prefix is not None:
    plink_indvs_haplos_file_prefix = args.plink_indvs_haplos_file_prefix
else:
    plink_indvs_haplos_file_prefix = None
snps_info_file = args.snps_info_file
report_haplos_file = args.report_haplos_file
p_value_sig_ratio = args.p_value_sig_ratio
dev_mode = args.dev_mode
show_indv_haplo_sheets = args.show_indv_haplo_sheets
special_indv_infos = []
if args.special_indv_infos is not None:
    for info in args.special_indv_infos.split(','):
        special_indv_infos.append(SpecialStudyIndividualInfo(info))

## ****************************************  display configuration  ****************************************
## display required configuration
comment("")
comment("")
comment("************************************************** S T A R T <" + script_name + "> **************************************************")
comment("")
disp_header("parameters")
comment("  " + " ".join(sys.argv[1:]))
comment("")

## display required configuration
disp_header("required configuration")
disp_param("xls output file (-o)", out_file)
disp_param("SNPs information file (-S)", snps_info_file)
disp_param("selected haplotypes file (-H)", report_haplos_file)
disp_param("filtered haplos file (-F)", fltred_haplos_file)
if plink_indvs_haplos_file_prefix is not None:
    disp_param("individuals haplos file prefix (-f)",
               plink_indvs_haplos_file_prefix)
comment("")

if args.addn_csvs is not None:
    ## display additional csvs configuration
    n_addn_sheet = len(addn_csvs_list)
    header_txt = "additional csv sheets configuration (-A)"
    header_txt += "(" + str(n_addn_sheet) + " sheet(s))"
    disp_header(header_txt)
    for i in xrange(n_addn_sheet):
        disp_param("additional sheet name #"+str(i+1), addn_sheet_names[i])
        disp_param("additional sheet csv  #"+str(i+1), addn_sheet_csvs[i])
    comment("")

## display optional configuration
disp_header("optional configuration")
disp_param("P-value significant ratio (-p)", p_value_sig_ratio)
if dev_mode:
    disp_param("developer mode (-D)", "ON")
disp_param("show individual haplotypes mapping (-I)", show_indv_haplo_sheets)
if special_indv_infos is not None:
    disp_subheader("special studies on individuals (-s)")
    for i in xrange(len(special_indv_infos)):
        indv_info = special_indv_infos[i]
        disp_subparam("individual code #"+str(i+1), indv_info.indv_id)
        disp_subparam("color 0 #"+str(i+1), indv_info.colors[0])
        disp_subparam("color 1 #"+str(i+1), indv_info.colors[1])
    pass
else:
    disp_param("special studies on individuals (-s)", special_indv_infos)
comment("")

# ****************************** define functions ******************************
def add_sheet(wb, sheet_name):
    ws = wb.add_worksheet(sheet_name)
    ws.set_default_row(11)
    return ws

def add_addn_csv_sheet(wb, dflt_cell_fmt, sheet_name, csv_file):
    ws = add_sheet(wb, sheet_name)
    with open(csv_file, 'rb') as csvfile:
        csv_recs = list(csv.reader(csvfile, delimiter='\t'))
        csv_row = 0
        for xls_row in xrange(len(csv_recs)):
            csv_rec = csv_recs[xls_row]
            for col in xrange(len(csv_rec)):
                ws.write(csv_row, col, csv_rec[col], dflt_cell_fmt)
            csv_row += 1
        csvfile.close()
    ws.freeze_panes(1, 0)

def add_run_no_to_ws(ws,
                     dflt_cell_fmt,
                     start_idx,
                     end_idx,
                     ):
    for i in xrange(start_idx, end_idx+1):
        ws.write(0, i, i+1, dflt_cell_fmt)

def add_snp_header_to_ws(ws,
                         dflt_cell_fmt,
                         row_idx,
                         snp_header,
                         ):
    ws.write(row_idx,
             IDX_COL_SNP_F_MISS_A,
             snp_header[IDX_COL_SNP_F_MISS_A],
             dflt_cell_fmt)
    ws.write(row_idx,
             IDX_COL_SNP_F_MISS_U,
             snp_header[IDX_COL_SNP_F_MISS_U],
             dflt_cell_fmt)

def add_snp_info_to_ws(ws,
                       dflt_cell_fmt,
                       snps_info_mg,
                       snps_list,
                       ):
    n_snps_col = snps_info_mg.record_size
    # Add SNPs information
    snps_rows_mapping = {}
    row_idx = HAPLO_INFO_SIZE
    for snp_info in snps_info_mg.snps_info:
        snp_code = snp_info[IDX_COL_SNP_CODE]
        if snp_code not in snps_list:
            continue
        row_idx += 1
        snps_rows_mapping[snp_code] = row_idx
        for item_idx in xrange(len(snp_info)):
            ws.write(row_idx,
                     item_idx,
                     snp_info[item_idx],
                     dflt_cell_fmt)
    add_snp_header_to_ws(ws, dflt_cell_fmt, HAPLO_INFO_SIZE, snps_info_mg.header)
    add_run_no_to_ws(ws, dflt_cell_fmt, 0, n_snps_col-1)
    # Set column chrom width to 5
    ws.set_column(IDX_COL_SNP_CHROM, IDX_COL_SNP_CHROM, 1.2)
    return (snps_rows_mapping, n_snps_col)

def add_haplo_stat_to_ws(ws,
                         cell_fmt_mg,
                         col,
                         haplo_info,
                         wb_fmt,
                         ):
    dflt_cell_fmt = cell_fmt_mg.default_format
    ws.write(0, col, col+1, dflt_cell_fmt)
    ws.write(1, col, haplo_info.f_a, wb_fmt)
    ws.write(2, col, haplo_info.f_u, wb_fmt)
    ws.write(3, col, haplo_info.chisq, wb_fmt)
    ws.write(4, col, haplo_info.or_value, wb_fmt)
    ws.write(5, col, haplo_info.p_value, wb_fmt)

def add_assoc_hap_header_to_ws(ws,
                               dflt_cell_fmt,
                               haplos_header_rec,
                               header_col,
                               ):
    rec = haplos_header_rec
    col = header_col
    # Add haplos header
    ws.write(1, col, rec[IDX_COL_HAPASSOC_F_A], dflt_cell_fmt)
    ws.write(2, col, rec[IDX_COL_HAPASSOC_F_U], dflt_cell_fmt)
    ws.write(3, col, rec[IDX_COL_HAPASSOC_CHISQ], dflt_cell_fmt)
    ws.write(4, col, rec[IDX_COL_HAPASSOC_OR], dflt_cell_fmt)
    ws.write(5, col, rec[IDX_COL_HAPASSOC_P_VALUE], dflt_cell_fmt)
    ws.set_row(1, 45, None, {})
    ws.set_row(2, 45, None, {})
    ws.set_row(3, 30, None, {})
    ws.set_row(4, 40, None, {})
    ws.set_row(5, 55, None, {})

def add_indv_info_to_ws(ws,
                        cell_fmt_mg,
                        adding_indv_info,
                        col_idx,
                        snps_rows_mapping,
                        ref_indv_info=None,
                        ):
    dflt_cell_fmt = cell_fmt_mg.default_format
    # Write individuals haplotypes header
    header_row = HAPLO_INFO_SIZE
    adding_indv_id = adding_indv_info.indv_id
    n_ploid = adding_indv_info.n_ploid
    adding_indv_gts = adding_indv_info.gts
    adding_colors = adding_indv_info.colors
    if n_ploid == 1:
        ws.write(header_row,
                 col_idx,
                 adding_indv_id,
                 cell_fmt_mg.stat_fmts[adding_colors[0]])
    else:
        ws.write(header_row,
                 col_idx,
                 adding_indv_id+"(shared)",
                 cell_fmt_mg.stat_fmts[adding_colors[0]])
        ws.write(header_row,
                 col_idx+1,
                 adding_indv_id+"(unshared)",
                 cell_fmt_mg.stat_fmts[adding_colors[1]])
    if ref_indv_info is not None:
        comment("adding: "+adding_indv_info.indv_id+"\tref: "+ref_indv_info.indv_id)
        ref_indv_gts = ref_indv_info.gts
        ref_colors = ref_indv_info.colors
    else:
        ref_indv_gts = {}
    for ploid_idx in xrange(n_ploid):
        for snp_code in snps_rows_mapping:
            if snp_code in adding_indv_gts:
                bp = adding_indv_gts[snp_code].split(" ")[ploid_idx]
                if bp != "0":
                    row = snps_rows_mapping[snp_code]
                    col = col_idx+ploid_idx
                    fmt = cell_fmt_mg.bp_fmts[adding_indv_info.colors[ploid_idx]]
                    ws.write(row, col, bp, fmt)
    ws.set_column(col_idx, col_idx+n_ploid-1, 1.3)
    add_run_no_to_ws(ws, dflt_cell_fmt, col_idx, col_idx+n_ploid-1)

def get_uniq_snps_from_assoc_hap(haplos_info):
    tmp_snps_dict = {}
    for haplo_info in haplos_info:
        for snp in haplo_info.snps:
            tmp_snps_dict[snp] = 1
    return tmp_snps_dict.keys()

def add_report_haplos_sheet(wb,
                            cell_fmt_mg,
                            sheet_name,
                            report_assoc_hap_mg,
                            snps_info_mg,
                            ):
    ws = add_sheet(wb, sheet_name)
    dflt_cell_fmt = cell_fmt_mg.default_format
    uniq_snps = get_uniq_snps_from_assoc_hap(report_assoc_hap_mg.haplos_info)
    (snps_rows_mapping, n_snps_col) = add_snp_info_to_ws(ws,
                                                         dflt_cell_fmt,
                                                         snps_info_mg,
                                                         uniq_snps)
    add_assoc_hap_header_to_ws(ws,
                               dflt_cell_fmt,
                               report_assoc_hap_mg.header,
                               n_snps_col-1)
    # Add haplos information
    color_idx = 0
    haplo_idx = 0
    for haplo_info in report_assoc_hap_mg.haplos_info:
        col = haplo_idx + n_snps_col
        if haplo_info.p_value < float(p_value_sig_ratio) :
            if color_idx >= cell_fmt_mg.n_colors:
                stat_fmt = cell_fmt_mg.stat_fmts[0]
                bp_fmt = cell_fmt_mg.bp_fmts[0]
            else:
                stat_fmt = cell_fmt_mg.stat_fmts[color_idx]
                bp_fmt = cell_fmt_mg.bp_fmts[color_idx]
                color_idx += 1
        else:
            stat_fmt = cell_fmt_mg.default_stat_format
            bp_fmt = cell_fmt_mg.default_bp_format
        add_haplo_stat_to_ws(ws,
                             cell_fmt_mg,
                             col,
                             haplo_info,
                             stat_fmt)
        # Map haplo to the corresponding markers
        bps_list = haplo_info.haplotype
        snps_list = haplo_info.snps
        for bp_idx in xrange(len(bps_list)):
            bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if snp_code in snps_rows_mapping:
                ws.write(snps_rows_mapping[snp_code], col, bp, bp_fmt)
        haplo_idx += 1
    haplos_count = report_assoc_hap_mg.haplos_count
    ws.set_column(n_snps_col, haplos_count+n_snps_col-1, 1.3)
    ws.freeze_panes(HAPLO_INFO_SIZE+1, n_snps_col)

def add_indv_haplos_sheets(wb,
                           cell_fmt_mg,
                           plink_gt_mg,
                           fltred_assoc_hap_mg,
                           snps_info_mg,
                           show_individual_sheet=False,
                           ):
    special_indv_ids = plink_gt_mg.special_indv_ids
    for indv_id in special_indv_ids:
        add_compact_indv_haplos_sheet(wb,
                                      cell_fmt_mg,
                                      plink_gt_mg,
                                      indv_id,
                                      fltred_haplos_mg,
                                      snps_info_mg,
                                      special=True,
                                      )
    other_indvs = filter(lambda x: x not in special_indv_ids,
                          plink_gt_mg.indv_ids)
    for indv_id in other_indvs:
        add_compact_indv_haplos_sheet(wb,
                                      cell_fmt_mg,
                                      plink_gt_mg,
                                      indv_id,
                                      fltred_assoc_hap_mg,
                                      snps_info_mg,
                                      special=False,
                                      )
        if not dev_mode:
            add_full_indv_haplos_sheet(wb,
                                       cell_fmt_mg,
                                       plink_gt_mg,
                                       indv_id,
                                       fltred_assoc_hap_mg,
                                       snps_info_mg,
                                       )

def compare_haplos(indv_info, assoc_hap_info):
    # The idea is to check if any of filtered haplotypes are similar to
    # one of the two individual(family) haplotypes.
    # With the above idea, the program has to check
    # 1 - If each bp at the same marker is similar, which has an exception
    #     in case that there is no bp info from the indv
    # 2 - With the exception from above, the comparison has to check that
    #     it has been compared at least once
    # Start the comparison bp-wise
    assoc_hap_bps = assoc_hap_info.haplotype
    assoc_hap_snps = assoc_hap_info.snps
    indv_gts = indv_info.gts
    for haplo_idx in xrange(indv_info.n_ploid):
        is_compared = False
        haplo_matched = haplo_idx
        for bp_idx in xrange(len(assoc_hap_bps)):
            assoc_hap_bp = assoc_hap_bps[bp_idx]
            assoc_hap_snp_code = assoc_hap_snps[bp_idx]
            # Only compare the snp which present in individual,
            # otherwise, exception will occur
            if assoc_hap_snp_code in indv_gts :
                indv_bps = indv_gts[assoc_hap_snp_code]
                indv_bp = indv_bps.split(" ")[haplo_idx]
                if indv_bp == "0":
                    continue
                # Compare !!!
                is_compared = True
                if assoc_hap_bp != indv_bp:
                    haplo_matched = -1
                    break
        if (haplo_matched != -1) and is_compared:
            return haplo_matched
    if not is_compared:
        return -1
    else:
        return haplo_matched

def get_matched_haplos_info(indv_info, assoc_haps_info):
    matched_haplos_info = []
    for assoc_hap_info in assoc_haps_info:
        matched_idx = compare_haplos(indv_info, assoc_hap_info)
        if matched_idx != -1:
            info = {'assoc_info': assoc_hap_info,
                    'color_idx': matched_idx,
                   }
            matched_haplos_info.append(info)
    return matched_haplos_info

def add_compact_indv_haplos_sheet(wb,
                                  cell_fmt_mg,
                                  plink_gt_mg,
                                  main_indv_id,
                                  fltred_assoc_hap_mg,
                                  snps_info_mg,
                                  special=False,
                                  ):
    ws = add_sheet(wb, main_indv_id)
    dflt_cell_fmt = cell_fmt_mg.default_format
    main_indv_info = plink_gt_mg.get_indv_info(main_indv_id)
    fltred_haplos_info = fltred_haplos_mg.haplos_info
    matched_haplos_info = get_matched_haplos_info(main_indv_info,
                                                  fltred_haplos_info)
    raw_haplos_info = map(lambda x: x['assoc_info'], matched_haplos_info)
    uniq_snps = get_uniq_snps_from_assoc_hap(raw_haplos_info)
    (snps_rows_mapping, n_snps_col) = add_snp_info_to_ws(ws,
                                                         dflt_cell_fmt,
                                                         snps_info_mg,
                                                         uniq_snps)
    last_col_idx = n_snps_col
    add_indv_info_to_ws(ws,
                        cell_fmt_mg,
                        main_indv_info,
                        last_col_idx,
                        snps_rows_mapping)
    last_col_idx += main_indv_info.n_ploid
    if special:
        other_indv_ids = filter(lambda x: x != main_indv_id,
                                plink_gt_mg.indv_ids)
        for other_indv_id in other_indv_ids:
            other_indv_info = plink_gt_mg.get_indv_info(other_indv_id)
            add_indv_info_to_ws(ws,
                                cell_fmt_mg,
                                other_indv_info,
                                last_col_idx,
                                snps_rows_mapping,
                                ref_indv_info=main_indv_info)
            last_col_idx += other_indv_info.n_ploid
    add_assoc_hap_header_to_ws(ws,
                               dflt_cell_fmt,
                               fltred_assoc_hap_mg.header,
                               n_snps_col-1)
    # Add haplotypes information
    start_haplos_col_idx = last_col_idx
    for haplo_idx in xrange(len(matched_haplos_info)):
        col = haplo_idx + start_haplos_col_idx
        haplo_info_dict = matched_haplos_info[haplo_idx]
        assoc_info = haplo_info_dict['assoc_info']
        color_idx = haplo_info_dict['color_idx']
        stat_fmt = cell_fmt_mg.stat_fmts[color_idx]
        bp_fmt = cell_fmt_mg.bp_fmts[color_idx]
        add_haplo_stat_to_ws(ws, cell_fmt_mg, col, assoc_info, stat_fmt)
        bps_list = assoc_info.haplotype
        snps_list = assoc_info.snps
        for bp_idx in xrange(len(bps_list)):
            fltred_bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if snp_code in snps_rows_mapping:
                row = snps_rows_mapping[snp_code]
                ws.write(row, col, fltred_bp, bp_fmt)
    # Set columns width
    end_col_idx = start_haplos_col_idx + len(matched_haplos_info) - 1
    col_width = 1.3
    ws.set_column(start_haplos_col_idx, end_col_idx, col_width)
    ws.freeze_panes(HAPLO_INFO_SIZE+1, start_haplos_col_idx)

def add_full_indv_haplos_sheet(wb,
                               cell_fmt_mg,
                               plink_gt_mg,
                               indv_id,
                               fltred_assoc_hap_mg,
                               snps_info_mg,
                               ):
    ws = add_sheet(wb, indv_id+"(full")
    dflt_cell_fmt = cell_fmt_mg.default_format
    target_indv_info = plink_gt_mg.get_indv_haplos(indv_id)
    uniq_snps = get_uniq_snps_from_assoc_hap(fltred_assoc_hap_mg.haplos_info)
    (snps_rows_mapping, n_snps_col) = add_snp_info_to_ws(ws,
                                                         dflt_cell_fmt,
                                                         snps_info_mg,
                                                         uniq_snps)
    add_assoc_hap_header_to_ws(ws,
                               dflt_cell_fmt,
                               fltred_assoc_hap_mg.header,
                               n_snps_col-1)
    add_indv_info_to_ws(ws,
                        cell_fmt_mg,
                        target_indv_info,
                        n_snps_col,
                        snps_rows_mapping,
                        OTH_INDV_COLORS,
                        )
    # Add haplotypes information
    start_haplos_col_idx = n_snps_col + target_indv_info.n_ploid
    haplo_idx = 0
    for haplo_info in fltred_assoc_hap_mg.haplos_info:
        col = haplo_idx + start_haplos_col_idx
        # get cell format
        matched_idx = compare_haplos(target_indv_info, haplo_info)
        if matched_idx != -1:
            stat_fmt = cell_fmt_mg.stat_fmts[matched_idx]
            bp_fmt = cell_fmt_mg.bp_fmts[matched_idx]
        else:
            stat_fmt = cell_fmt_mg.stat_fmts[DFLT_FMT]
            bp_fmt = cell_fmt_mg.bp_fmts[DFLT_FMT]
        add_haplo_stat_to_ws(ws, cell_fmt_mg, col, haplo_info, stat_fmt)
        # Map haplo to the corresponding markers
        bps_list = haplo_info.haplotype
        snps_list = haplo_info.snps
        for bp_idx in xrange(len(bps_list)):
            bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if snp_code in snps_rows_mapping:
                ws.write(snps_rows_mapping[snp_code], col, bp, bp_fmt)
        haplo_idx += 1
    haplos_count = fltred_assoc_hap_mg.haplos_count
    end_col_idx = start_haplos_col_idx + haplos_count - 1
    col_width = 1.3
    ws.set_column(start_haplos_col_idx, end_col_idx, col_width)
    ws.freeze_panes(HAPLO_INFO_SIZE+1, start_haplos_col_idx)

# ****************************** main codes ******************************
wb = xlsxwriter.Workbook(out_file)

if plink_indvs_haplos_file_prefix is not None:
    plink_gt_mg = PlinkGTManager(plink_indvs_haplos_file_prefix,
                                 special_indv_infos)
snps_info_mg = SnpsInfoManager(snps_info_file)
report_haplos_mg = PlinkAssocHapManager(report_haplos_file)
fltred_haplos_mg = PlinkAssocHapManager(fltred_haplos_file)
cell_fmt_mg = CellFormatManager(wb, COLOR_RGB)
dflt_cell_fmt = cell_fmt_mg.default_format
if plink_indvs_haplos_file_prefix is not None:
    add_indv_haplos_sheets(wb,
                           cell_fmt_mg,
                           plink_gt_mg,
                           fltred_haplos_mg,
                           snps_info_mg)
add_report_haplos_sheet(wb,
                        cell_fmt_mg,
                        'significant haplos',
                        report_haplos_mg,
                        snps_info_mg,
                        )

add_addn_csv_sheet(wb, dflt_cell_fmt, "filtered haplotypes", fltred_haplos_file)
add_addn_csv_sheet(wb, dflt_cell_fmt, "input", report_haplos_file)
for i in xrange(len(addn_csvs_list)):
    add_addn_csv_sheet(wb, addn_sheet_names[i], addn_sheet_csvs[i])

wb.close()

comment("************************************************** F I N I S H <" + script_name + "> **************************************************")
