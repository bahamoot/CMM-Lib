from collections import OrderedDict
from collections import defaultdict
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
IDX_COL_SNP_POS = 4

HAPLO_COL_WIDTH = 1.6

COLOR_RGB = OrderedDict()
COLOR_RGB['GREEN_ANNIKA'] = '#CCFFCC'
COLOR_RGB['PINK_ANNIKA'] = '#E6B9B8'
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
COLOR_RGB['GOLD'] = '#FFD700'
COLOR_RGB['LIME'] = '#00FF00'
COLOR_RGB['MAGENTA'] = '#FF00FF'
COLOR_RGB['ICEBLUE'] = '#A5F2F3'
COLOR_RGB['LIGHT_BLUE'] = '#ADD8E6'

OTH_INDV_COLORS = ['ICEBLUE', 'ROYAL_BLUE']
#OTH_INDV_COLORS = ['ICEBLUE', 'LIGHT_BLUE']
DFLT_FMT = 'default_format'

script_name = ntpath.basename(sys.argv[0])

# ****************************** define classes ******************************
class PlinkBase(object):
    """ A base object of PLINK class """

    def __init__(self):
        pass

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return '<' + self.__class__.__name__ + ' Object> ' + str(self.get_raw_repr())

    def get_raw_repr(self):
        return "!!! < Base Class > !!!"

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
        self.__dflt_hash_fmt = {'font_name': 'Arial', 'font_size': 9}
        self.__dflt_fmt = self.__add_fmt(self.__dflt_hash_fmt)
        self.__init_colors_formats()

    def get_raw_repr(self):
        return {"color dict": self.__color_dict,
                "number of color": self.n_colors,
                }

    def __add_fmt(self, fmt_dict):
        return self.__wb.add_format(fmt_dict)

    @property
    def default_format(self):
        return self.__dflt_fmt

    def __init_colors_format(self, default_hash_format):
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

    def __init_colors_formats(self):
        dflt_bp_hash_fmt = self.__dflt_hash_fmt.copy()
        dflt_bp_hash_fmt['align'] = 'center'
        self.__bp_fmts = self.__init_colors_format(dflt_bp_hash_fmt)
        dflt_stat_hash_fmt = self.__dflt_hash_fmt.copy()
        dflt_stat_hash_fmt['rotation'] = 90
        self.__stat_fmts = self.__init_colors_format(dflt_stat_hash_fmt)
        dflt_snp_hash_fmt = self.__dflt_hash_fmt.copy()
        self.__snp_fmts = self.__init_colors_format(dflt_snp_hash_fmt)

    @property
    def n_colors(self):
        return len(self.__color_dict)

    @property
    def bp_fmts(self):
        return self.__bp_fmts

    @property
    def stat_fmts(self):
        return self.__stat_fmts

    @property
    def snp_fmts(self):
        return self.__snp_fmts

class PlinkPedRecord(PlinkBase):
    """ A class to parse information for each record in Pedigree file """

    def __init__(self, data):
        self.__data = data
        self.__gts = None

    def get_raw_repr(self):
        return {"raw data": self.__data,
                "family ID": self.fam_id,
                "displayed ID": self.displayed_id,
                "individual ID": self.indv_id,
                "ploidy": self.n_ploid,
                }

    @property
    def fam_id(self):
        return self.__data[IDX_COL_PED_FAM_ID]

    @property
    def displayed_id(self):
        return "family " + self.fam_id

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

    @property
    def n_color_regions(self):
        return self.color_regions.n_regions

    @gts.setter
    def gts(self, value):
        self.__gts = value

    def info_color_regions(self):
        info_fmt = ">>>>{chrom:>3}:{start_pos:>10} - {end_pos:>9} : {color}"
        info(">> There are " + str(self.n_color_regions) + " color region(s)")
        for color_region in self.color_regions:
            info(info_fmt.format(chrom=color_region.chrom,
                                 start_pos=color_region.start_pos,
                                 end_pos=color_region.end_pos,
                                 color=color_region.color))

class PlinkPedManager(PlinkBase):
    """ A manager class to handle PLINK pedigree file """

    def __init__(self, file_name):
        self.__file_name = file_name
        self.__fam_ids = map(lambda x: x.fam_id, self.fam_infos)

    def get_raw_repr(self):
        return {"ped file name": self.__file_name,
                }
    @property
    def fam_infos(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            for raw_fam_info in csv_reader:
                yield(PlinkPedRecord(raw_fam_info))
            csvfile.close()

    def get_fam_info(self, fam_id):
        for fam_info in self.fam_infos:
            if fam_info.fam_id == fam_id:
                return fam_info

    @property
    def fam_ids(self):
        return self.__fam_ids

class PlinkMapManager(PlinkBase):
    """ A manager class to handle PLINK map file """

    def __init__(self, file_name):
        self.__file_name = file_name
        self.__markers = []
        self.__load_markers()

    def get_raw_repr(self):
        return {"map file name": self.__file_name,
                "number of markers": len(self.__markers),
                }

    def __len__(self):
        return len(self.__markers)

    def __getitem__(self, key):
        return self.__markers[key]

    def __load_markers(self):
        del self.__markers[:]
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            for marker_info in csv_reader:
                self.__markers.append(marker_info[IDX_COL_MAP_MARKER])
            csvfile.close()

class PlinkGTManager(PlinkBase):
    """ A manager class to handle PLINK genotyping data """

    def __init__(self,
                 gt_file_prefix,
                 special_fam_infos=[],
                 color_region_infos=[]):
        self.__gt_file_prefix = gt_file_prefix
        self.__map_mg = PlinkMapManager(gt_file_prefix + '.map')
        self.__ped_mg = PlinkPedManager(gt_file_prefix + '.ped')
        self.__load_special_fam_infos(special_fam_infos)
        self.__load_color_region_infos(color_region_infos)

    def get_raw_repr(self):
        return {"genotyping file prefix": self.__gt_file_prefix,
                "family IDs": self.fam_ids,
                }

    @property
    def fam_ids(self):
        return self.__ped_mg.fam_ids

    @property
    def special_fam_ids(self):
        return self.__special_fam_infos.keys()

    def __load_special_fam_infos(self, special_fam_infos):
        self.__special_fam_infos = {}
        for special_fam_info in special_fam_infos:
            fam_id = special_fam_info.fam_id
            self.__special_fam_infos[fam_id] = special_fam_info

    def __load_color_region_infos(self, color_region_infos):
        self.__color_region_infos = defaultdict(ColorRegions)
        for color_region_info in color_region_infos:
            fam_id = color_region_info.fam_id
            self.__color_region_infos[fam_id].append(color_region_info)
        for fam_id in self.__color_region_infos:
            color_regions = self.__color_region_infos[fam_id]
            color_regions.sort_regions()

    def map_gts_to_snps(self, fam_haplos, markers):
        gts = {}
        for idx in xrange(len(markers)):
            gts[markers[idx]] = fam_haplos.gts[idx]
        return gts

    def get_fam_info(self, fam_id):
        fam_info = self.__ped_mg.get_fam_info(fam_id)
        fam_info.gts = self.map_gts_to_snps(fam_info, self.__map_mg)
        if fam_id in self.__special_fam_infos:
            fam_info.colors = self.__special_fam_infos[fam_id].colors
        else:
            fam_info.colors = OTH_INDV_COLORS
        if fam_id in self.__color_region_infos:
            fam_info.color_regions = self.__color_region_infos[fam_id]
        else:
            fam_info.color_regions = ColorRegions()
        return fam_info

class PlinkAssocHapRecord(PlinkBase):
    """ A class to parse each record of haplotype association study result """

    def __init__(self, data):
        self.__data = data

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

class SnpRecord(PlinkBase):
    """ A class to parse SNP information """

    def __init__(self, data):
        self.__data = data

    def get_raw_repr(self):
        return {"raw data ": self.__data,
                "snp code ": self.snp_code,
                "F_MISS_A": self.f_miss_a,
                "F_MISS_U": self.f_miss_u,
                "chromosome ": self.chrom,
                "position ": self.pos,
                }

    @property
    def snp_code(self):
        return self.__data[IDX_COL_SNP_CODE]

    @property
    def f_miss_a(self):
        return self.__data[IDX_COL_SNP_F_MISS_A]

    @property
    def f_miss_u(self):
        return self.__data[IDX_COL_SNP_F_MISS_U]

    @property
    def chrom(self):
        return self.__data[IDX_COL_SNP_CHROM]

    @property
    def pos(self):
        return int(self.__data[IDX_COL_SNP_POS])

class SnpsInfoManager(PlinkBase):
    """ A class to handle SNPs information """

    def __init__(self, snps_info_file):
        self.__file_name = snps_info_file
        self.__snp_list = map(lambda x:x.snp_code, self.snps_info)

    def get_raw_repr(self):
        return {"snps infomation file name": self.__file_name,
                "header": self.header,
                "record size": self.record_size,
                "number of snps": len(list(self.snps_info)),
                }

    @property
    def snp_list(self):
        return self.__snp_list

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
                yield(SnpRecord(snp_info))
            csvfile.close()

    @property
    def record_size(self):
        return len(self.header)

class SpecialStudyFamilyRecord(PlinkBase):
    """ A class to parse information for each record in Pedigree file """

    def __init__(self, raw_info):
        self.__raw_info = raw_info
        self.__info = raw_info.split(':')
        if len(self.__info) < 3:
            self.__colors = [self.__info[1], self.__info[1]]
        else:
            self.__colors = [self.__info[1], self.__info[2]]

    def get_raw_repr(self):
        return {"raw info": self.__raw_info,
                "family ID": self.fam_id,
                "color 0": self.colors[0],
                "color 1": self.colors[1],
                }

    @property
    def fam_id(self):
        return self.__info[0].replace('_shared_only', '')

    @property
    def colors(self):
        return self.__colors

class ColorRegionRecord(PlinkBase):
    """ A class to parse coloring region infomation """

    def __init__(self, raw_info):
        self.__raw_info = raw_info
        self.__info = raw_info.split(':')

    def get_raw_repr(self):
        return {"raw info": self.__raw_info,
                "family ID": self.fam_id,
                "color": self.color,
                "chromosome": self.chrom,
                "start position": self.start_pos,
                "end position": self.end_pos,
                }

    @property
    def raw_info(self):
        return self.__raw_info

    @property
    def fam_id(self):
        return self.__info[0]

    @property
    def color(self):
        return self.__info[1]

    @property
    def chrom(self):
        return self.__info[2]

    @property
    def start_pos(self):
        return int(self.__info[3].split('-')[0])

    @property
    def end_pos(self):
        return int(self.__info[3].split('-')[1])

class ColorRegions(list, PlinkBase):
    """ A manager class to handle coloring regions of each family """

    def __init__(self):
        self.__active_region_idx = 0

    def get_raw_repr(self):
        return {"number of regions": self.n_regions,
                }

    @property
    def n_regions(self):
        return len(self)

    def __update_comparison_info(self):
        if self.n_regions > self.__active_region_idx:
            color_region = self[self.__active_region_idx]
            self.__active_chrom = color_region.chrom
            self.__active_start_pos = color_region.start_pos
            self.__active_end_pos = color_region.end_pos
            self.__active_color = color_region.color
        else:
            self.__active_chrom = None
            self.__active_start_pos = 999999999999
            self.__active_end_pos = 999999999999
            self.__active_color = None

    def init_comparison(self):
        self.__active_region_idx = 0
        self.__update_comparison_info()

    def get_color(self, position):
        while position > self.__active_end_pos:
            self.__active_region_idx += 1
            self.__update_comparison_info()
        if position >= self.__active_start_pos:
            return self.__active_color
        else:
            return None

    def sort_regions(self):
        self.sort(key=lambda x:x.start_pos, reverse=False)

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
argp.add_argument('-f', dest='plink_fams_haplos_file_prefix',
                        metavar='FILE_PREFIX',
                        help='PLINK families haplos file prefix',
                        default=None)
argp.add_argument('-s', dest='special_fam_infos',
                        metavar='INDIVIDUAL_CODES',
                        help='information of individual(s) to be specially studied, in this version all haplotypes from other individuals will be align with them to see who common the haplotypes in question in the population ',
                        default=None)
argp.add_argument('-C', dest='color_region_infos',
                        metavar='COLOR_REGION_INFOS',
                        help='color information of each region of interest',
                        default=None)
argp.add_argument('-p', dest='p_value_sig_ratio',
                        metavar='P_VALUE',
                        help='P-value significant ratio',
                        default=0)
argp.add_argument('-D', dest='dev_mode',
                        action='store_true',
                        help='To enable development mode, this will effect the debuggin message and how the result is shown up',
                        default=False)
argp.add_argument('-I', dest='show_fam_haplo_sheets',
                        action='store_true',
                        help='To enable showing sheets, one for each individual, which map individual haplotype(s) with filtered assoc.hap ',
                        default=False)
argp.add_argument('-l', dest='log_file',
                        metavar='FILE',
                        help='log file',
                        default=None)
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
if args.plink_fams_haplos_file_prefix is not None:
    plink_fams_haplos_file_prefix = args.plink_fams_haplos_file_prefix
else:
    plink_fams_haplos_file_prefix = None
snps_info_file = args.snps_info_file
report_haplos_file = args.report_haplos_file
p_value_sig_ratio = args.p_value_sig_ratio
dev_mode = args.dev_mode
show_fam_haplo_sheets = args.show_fam_haplo_sheets
special_fam_infos = []
if args.special_fam_infos is not None:
    for info in args.special_fam_infos.split(','):
        special_fam_infos.append(SpecialStudyFamilyRecord(info))
color_region_infos = []
if args.color_region_infos is not None:
    for info in args.color_region_infos.split(','):
        color_region_infos.append(ColorRegionRecord(info))
log_file = open(args.log_file, "a+")

## **************  define basic functions  **************
def write_log(msg):
    print >> log_file, msg

def output_msg(msg):
    print >> sys.stderr, msg
    write_log(msg)

def info(msg):
    info_fmt = "## [INFO] {msg}"
    formated_msg=info_fmt.format(msg=msg)
    output_msg(formated_msg)

def debug(msg):
    debug_fmt = "## [DEBUG] {msg}"
    formated_msg=debug_fmt.format(msg=msg)
    if dev_mode:
        output_msg(formated_msg)
    else:
        write_log(formated_msg)

def throw(err_msg):
    error_fmt = "## [ERROR] {msg}"
    formated_msg=error_fmt.format(msg=err_msg)
    raise Exception(err_msg)

def new_section_txt(txt):
    info("")
    info(txt.center(140,"*"))

def disp_header(header_txt):
    info(header_txt)

def disp_subheader(subheader_txt):
    info("  " + subheader_txt)

def disp_param(param_name, param_value):
    fmt = "  {name:<45}{value}"
    info(fmt.format(name=param_name+":", value=param_value))

def disp_subparam(subparam_name, subparam_value):
    disp_param("  "+subparam_name, subparam_value)

## ****************************************  display configuration  ****************************************
## display required configuration
new_section_txt(" S T A R T <" + script_name + "> ")
info("")
disp_header("parameters")
info("  " + " ".join(sys.argv[1:]))
info("")

## display required configuration
disp_header("required configuration")
disp_param("xls output file (-o)", out_file)
disp_param("SNPs information file (-S)", snps_info_file)
disp_param("selected haplotypes file (-H)", report_haplos_file)
disp_param("filtered haplos file (-F)", fltred_haplos_file)
if plink_fams_haplos_file_prefix is not None:
    disp_param("families haplos file prefix (-f)",
               plink_fams_haplos_file_prefix)
info("")

if args.addn_csvs is not None:
    ## display additional csvs configuration
    n_addn_sheet = len(addn_csvs_list)
    header_txt = "additional csv sheets configuration (-A)"
    header_txt += "(" + str(n_addn_sheet) + " sheet(s))"
    disp_header(header_txt)
    for i in xrange(n_addn_sheet):
        disp_param("additional sheet name #"+str(i+1), addn_sheet_names[i])
        disp_param("additional sheet csv  #"+str(i+1), addn_sheet_csvs[i])
    info("")

## display optional configuration
disp_header("optional configuration")
disp_param("P-value significant ratio (-p)", p_value_sig_ratio)
if dev_mode:
    disp_param("developer mode (-D)", "ON")
disp_param("show family haplotypes mapping (-I)", show_fam_haplo_sheets)
if len(special_fam_infos) > 0:
    disp_subheader("special studies on families (-s)")
    for i in xrange(len(special_fam_infos)):
        fam_info = special_fam_infos[i]
        disp_subparam("family code #"+str(i+1), fam_info.fam_id)
        disp_subparam("haplotype color 0 #"+str(i+1), fam_info.colors[0])
        disp_subparam("haplotype color 1 #"+str(i+1), fam_info.colors[1])
    pass
if len(color_region_infos) > 0:
    disp_subheader("color regions information (-C)")
    for i in xrange(len(color_region_infos)):
        color_region_info = color_region_infos[i]
        disp_subparam("color info #"+str(i+1), color_region_info.raw_info)
info("")

# ****************************** define functions ******************************
def add_sheet(wb, sheet_name):
    ws = wb.add_worksheet(sheet_name)
    ws.set_default_row(12)
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

def add_snp_to_ws(ws, row_idx, snp_info, cell_format):
    ws.write(row_idx, IDX_COL_SNP_CODE, snp_info.snp_code, cell_format)
    ws.write(row_idx, IDX_COL_SNP_F_MISS_A, snp_info.f_miss_a, cell_format)
    ws.write(row_idx, IDX_COL_SNP_F_MISS_U, snp_info.f_miss_u, cell_format)
    ws.write(row_idx, IDX_COL_SNP_CHROM, snp_info.chrom, cell_format)
    ws.write(row_idx, IDX_COL_SNP_POS, snp_info.pos, cell_format)

def add_snps_to_ws(ws,
                   cell_fmt_mg,
                   snps_info_mg,
                   snps_list,
                   color_regions=ColorRegions()
                   ):
    n_snps_col = snps_info_mg.record_size
    color_regions.init_comparison()
    # Add SNPs information
    snps_rows_map = {}
    row_idx = HAPLO_INFO_SIZE
    for snp_info in snps_info_mg.snps_info:
        snp_code = snp_info.snp_code
        if snp_code not in snps_list:
            continue
        snp_color = color_regions.get_color(snp_info.pos)
        if snp_color is None:
            snp_cell_fmt = cell_fmt_mg.default_format
        else:
            snp_cell_fmt = cell_fmt_mg.snp_fmts[snp_color]
        row_idx += 1
        snps_rows_map[snp_code] = row_idx
        add_snp_to_ws(ws, row_idx, snp_info, snp_cell_fmt)
    add_snp_header_to_ws(ws,
                         dflt_cell_fmt,
                         HAPLO_INFO_SIZE,
                         snps_info_mg.header)
    add_run_no_to_ws(ws, dflt_cell_fmt, 0, n_snps_col-1)
    ws.set_column(IDX_COL_SNP_CODE, IDX_COL_SNP_CODE, 7)
    ws.set_column(IDX_COL_SNP_F_MISS_A, IDX_COL_SNP_F_MISS_U, 6)
    ws.set_column(IDX_COL_SNP_CHROM, IDX_COL_SNP_CHROM, 0.8)
    ws.set_column(IDX_COL_SNP_POS, IDX_COL_SNP_POS, 10)
    return (snps_rows_map, n_snps_col)

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
    ws.set_row(1, 35, None, {})
    ws.set_row(2, 35, None, {})
    ws.set_row(3, 30, None, {})
    ws.set_row(4, 35, None, {})
    ws.set_row(5, 55, None, {})

def add_fam_info_to_ws(ws,
                       cell_fmt_mg,
                       adding_fam_info,
                       col_idx,
                       snps_rows_map,
                       ref_fam_infos=[],
                       ):
    dflt_cell_fmt = cell_fmt_mg.default_format
    bp_fmts = cell_fmt_mg.bp_fmts
    # Write families haplotypes header
    header_row = HAPLO_INFO_SIZE
    adding_fam_id = adding_fam_info.fam_id
    n_ploid = adding_fam_info.n_ploid
    adding_fam_gts = adding_fam_info.gts
    adding_colors = adding_fam_info.colors
    if n_ploid == 1:
        ws.write(header_row,
                 col_idx,
                 adding_fam_id,
                 cell_fmt_mg.stat_fmts[adding_colors[0]])
    else:
        ws.write(header_row,
                 col_idx,
                 adding_fam_id+" (shared)",
                 cell_fmt_mg.stat_fmts[adding_colors[0]])
        ws.write(header_row,
                 col_idx+1,
                 adding_fam_id+" (unshared)",
                 cell_fmt_mg.stat_fmts[adding_colors[1]])
    for adding_ploid_idx in xrange(adding_fam_info.n_ploid):
        for snp_code in snps_rows_map:
            if snp_code not in adding_fam_gts:
                continue
            adding_bp = adding_fam_gts[snp_code].split(" ")[adding_ploid_idx]
            if adding_bp == "0":
                continue
            # defining format
            bp_fmt = bp_fmts[adding_fam_info.colors[adding_ploid_idx]]
            for ref_fam_info in ref_fam_infos:
                is_compared = False
                ref_fam_gts = ref_fam_info.gts
                ref_colors = ref_fam_info.colors
                if snp_code not in ref_fam_gts:
                    continue
                for ref_ploid_idx in xrange(ref_fam_info.n_ploid):
                    ref_bp = ref_fam_gts[snp_code].split(" ")[ref_ploid_idx]
                    if adding_bp == ref_bp:
                        bp_fmt = bp_fmts[ref_fam_info.colors[ref_ploid_idx]]
                        is_compared = True
                        break
                if is_compared:
                    break
            row = snps_rows_map[snp_code]
            col = col_idx+adding_ploid_idx
            ws.write(row, col, adding_bp, bp_fmt)
    ws.set_column(col_idx, col_idx+n_ploid-1, 1.3)
    add_run_no_to_ws(ws, dflt_cell_fmt, col_idx, col_idx+n_ploid-1)

def get_uniq_snps_from_assoc_hap(haplos_info):
    tmp_snps_dict = {}
    for haplo_info in haplos_info:
        for snp in haplo_info.snps:
            tmp_snps_dict[snp] = 1
    return tmp_snps_dict.keys()

def get_uniq_snps_from_family_gts(family_info):
    return family_info.gts.keys()

def add_report_haplos_sheet(wb,
                            cell_fmt_mg,
                            sheet_name,
                            report_assoc_hap_mg,
                            snps_info_mg,
                            ):
    ws = add_sheet(wb, sheet_name)
    dflt_cell_fmt = cell_fmt_mg.default_format
    uniq_snps = get_uniq_snps_from_assoc_hap(report_assoc_hap_mg.haplos_info)
    (snps_rows_map, n_snps_col) = add_snps_to_ws(ws,
                                                 cell_fmt_mg,
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
            stat_fmt = cell_fmt_mg.stat_fmts[DFLT_FMT]
            bp_fmt = cell_fmt_mg.bp_fmts[DFLT_FMT]
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
            if snp_code in snps_rows_map:
                ws.write(snps_rows_map[snp_code], col, bp, bp_fmt)
        haplo_idx += 1
    haplos_count = report_assoc_hap_mg.haplos_count
    ws.set_column(n_snps_col, haplos_count+n_snps_col-1, 1.3)
    ws.freeze_panes(HAPLO_INFO_SIZE+1, n_snps_col)

def add_fam_haplos_sheets(wb,
                          cell_fmt_mg,
                          plink_gt_mg,
                          fltred_assoc_hap_mg,
                          snps_info_mg,
                          ):
    special_fam_ids = plink_gt_mg.special_fam_ids
    # Adding family of interest first
    for fam_id in special_fam_ids:
        info("adding special haplotype sheet for family " + fam_id)
        add_compact_fam_haplos_sheet(wb,
                                     cell_fmt_mg,
                                     plink_gt_mg,
                                     fam_id,
                                     fltred_assoc_hap_mg,
                                     snps_info_mg,
                                     )
        info("adding normal full haplotype sheet for family " + fam_id)
        add_full_fam_haplos_sheet(wb,
                                  cell_fmt_mg,
                                  plink_gt_mg,
                                  fam_id,
                                  fltred_assoc_hap_mg,
                                  snps_info_mg,
                                  )
    other_fams = filter(lambda x: x not in special_fam_ids,
                          plink_gt_mg.fam_ids)
    for fam_id in other_fams:
        info("adding normal compact haplotype sheet for family " + fam_id)
        add_compact_fam_haplos_sheet(wb,
                                     cell_fmt_mg,
                                     plink_gt_mg,
                                     fam_id,
                                     fltred_assoc_hap_mg,
                                     snps_info_mg,
                                     )
        info("adding normal full haplotype sheet for family " + fam_id)
        add_full_fam_haplos_sheet(wb,
                                  cell_fmt_mg,
                                  plink_gt_mg,
                                  fam_id,
                                  fltred_assoc_hap_mg,
                                  snps_info_mg,
                                  )

def compare_haplos(fam_info, assoc_hap_info):
    # The idea is to check if any of filtered haplotypes are similar to
    # one of the two family haplotypes.
    # With the above idea, the program has to check
    # 1 - If each bp at the same marker is similar, which has an exception
    #     in case that there is no bp info from the family
    # 2 - With the exception from above, the comparison has to check that
    #     it has been compared at least once
    # Start the comparison bp-wise
    assoc_hap_bps = assoc_hap_info.haplotype
    assoc_hap_snps = assoc_hap_info.snps
    fam_gts = fam_info.gts
    for haplo_idx in xrange(fam_info.n_ploid):
        is_compared = False
        haplo_matched = haplo_idx
        for bp_idx in xrange(len(assoc_hap_bps)):
            assoc_hap_bp = assoc_hap_bps[bp_idx]
            assoc_hap_snp_code = assoc_hap_snps[bp_idx]
            # Only compare the snp which present in family,
            # otherwise, exception will occur
            if assoc_hap_snp_code in fam_gts :
                fam_bps = fam_gts[assoc_hap_snp_code]
                fam_bp = fam_bps.split(" ")[haplo_idx]
                if fam_bp == "0":
                    continue
                # Compare !!!
                is_compared = True
                if assoc_hap_bp != fam_bp:
                    haplo_matched = -1
                    break
        if (haplo_matched != -1) and is_compared:
            return haplo_matched
    if not is_compared:
        return -1
    else:
        return haplo_matched

def get_matched_haplos_info(fam_info, assoc_haps_info):
    matched_haplos_info = []
    for assoc_hap_info in assoc_haps_info:
        matched_idx = compare_haplos(fam_info, assoc_hap_info)
        if matched_idx != -1:
            info = {'assoc_info': assoc_hap_info,
                    'color_idx': matched_idx,
                   }
            matched_haplos_info.append(info)
    return matched_haplos_info

def add_full_all_fams_haplos_sheet(wb,
                                   cell_fmt_mg,
                                   plink_gt_mg,
                                   fltred_assoc_hap_mg,
                                   snps_info_mg,
                                   ):
    pass
#    ws = add_sheet(wb, 'all families')
#    (snps_rows_map, n_snps_col) = add_snps_to_ws(ws,
#                                                 cell_fmt_mg,
#                                                 snps_info_mg,
#                                                 snps_info_mg.snp_list)

def add_compact_fam_haplos_sheet(wb,
                                 cell_fmt_mg,
                                 plink_gt_mg,
                                 main_fam_id,
                                 fltred_assoc_hap_mg,
                                 snps_info_mg,
                                 ):
    main_fam_info = plink_gt_mg.get_fam_info(main_fam_id)
    main_fam_info.info_color_regions()
    ws = add_sheet(wb, main_fam_info.displayed_id)
    dflt_cell_fmt = cell_fmt_mg.default_format
    fltred_haplos_info = fltred_haplos_mg.haplos_info
    matched_haplos_info = get_matched_haplos_info(main_fam_info,
                                                  fltred_haplos_info)
    raw_haplos_info = map(lambda x: x['assoc_info'], matched_haplos_info)
    uniq_snps = get_uniq_snps_from_assoc_hap(raw_haplos_info)
    color_regions = main_fam_info.color_regions
    (snps_rows_map, n_snps_col) = add_snps_to_ws(ws,
                                                 cell_fmt_mg,
                                                 snps_info_mg,
                                                 uniq_snps,
                                                 color_regions=color_regions)
    last_col_idx = n_snps_col
    add_fam_info_to_ws(ws,
                       cell_fmt_mg,
                       main_fam_info,
                       last_col_idx,
                       snps_rows_map)
    last_col_idx += main_fam_info.n_ploid
    special_fam_ids = plink_gt_mg.special_fam_ids
    if main_fam_id in special_fam_ids:
        other_fam_ids = filter(lambda x: x != main_fam_id,
                               plink_gt_mg.fam_ids)
        for other_fam_id in other_fam_ids:
            other_fam_info = plink_gt_mg.get_fam_info(other_fam_id)
            info("-- adding haplotypes of family " + other_fam_id)
            add_fam_info_to_ws(ws,
                               cell_fmt_mg,
                               other_fam_info,
                               last_col_idx,
                               snps_rows_map,
                               ref_fam_infos=[main_fam_info])
            last_col_idx += other_fam_info.n_ploid
    else:
        for special_fam_id in special_fam_ids:
            special_fam_info = plink_gt_mg.get_fam_info(special_fam_id)
            info("-- adding haplotypes of family " + special_fam_id)
            add_fam_info_to_ws(ws,
                               cell_fmt_mg,
                               special_fam_info,
                               last_col_idx,
                               snps_rows_map,
                               ref_fam_infos=[main_fam_info])
            last_col_idx += special_fam_info.n_ploid
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
        color_code = main_fam_info.colors[haplo_info_dict['color_idx']]
        stat_fmt = cell_fmt_mg.stat_fmts[color_code]
        bp_fmt = cell_fmt_mg.bp_fmts[color_code]
        add_haplo_stat_to_ws(ws, cell_fmt_mg, col, assoc_info, stat_fmt)
        bps_list = assoc_info.haplotype
        snps_list = assoc_info.snps
        for bp_idx in xrange(len(bps_list)):
            fltred_bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if snp_code in snps_rows_map:
                row = snps_rows_map[snp_code]
                ws.write(row, col, fltred_bp, bp_fmt)
    # Set columns width
    end_col_idx = start_haplos_col_idx + len(matched_haplos_info) - 1
    ws.set_column(start_haplos_col_idx, end_col_idx, HAPLO_COL_WIDTH)
    ws.freeze_panes(HAPLO_INFO_SIZE+1, start_haplos_col_idx)

def add_full_fam_haplos_sheet(wb,
                              cell_fmt_mg,
                              plink_gt_mg,
                              fam_id,
                              fltred_assoc_hap_mg,
                              snps_info_mg,
                              ):
    fam_info = plink_gt_mg.get_fam_info(fam_id)
    ws = add_sheet(wb, fam_info.displayed_id+" (full)")
    dflt_cell_fmt = cell_fmt_mg.default_format
    (snps_rows_map, n_snps_col) = add_snps_to_ws(ws,
                                                 cell_fmt_mg,
                                                 snps_info_mg,
                                                 snps_info_mg.snp_list)
    add_assoc_hap_header_to_ws(ws,
                               dflt_cell_fmt,
                               fltred_assoc_hap_mg.header,
                               n_snps_col-1)
    add_fam_info_to_ws(ws,
                       cell_fmt_mg,
                       fam_info,
                       n_snps_col,
                       snps_rows_map,
                       )
    # Add haplotypes information
    start_haplos_col_idx = n_snps_col + fam_info.n_ploid
    haplo_idx = 0
    for haplo_info in fltred_assoc_hap_mg.haplos_info:
        col = haplo_idx + start_haplos_col_idx
        # get cell format
        matched_idx = compare_haplos(fam_info, haplo_info)
        if matched_idx != -1:
            color_code = fam_info.colors[matched_idx]
            stat_fmt = cell_fmt_mg.stat_fmts[color_code]
            bp_fmt = cell_fmt_mg.bp_fmts[color_code]
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
            if snp_code in snps_rows_map:
                ws.write(snps_rows_map[snp_code], col, bp, bp_fmt)
        haplo_idx += 1
    haplos_count = fltred_assoc_hap_mg.haplos_count
    end_col_idx = start_haplos_col_idx + haplos_count - 1
    ws.set_column(start_haplos_col_idx, end_col_idx, HAPLO_COL_WIDTH)
    ws.freeze_panes(HAPLO_INFO_SIZE+1, start_haplos_col_idx)

def add_full_master_haplos_sheet(wb,
                                 cell_fmt_mg,
                                 fltred_assoc_hap_mg,
                                 snps_info_mg,
                                 ):
    ws = add_sheet(wb, "master")
    dflt_cell_fmt = cell_fmt_mg.default_format
    (snps_rows_map, n_snps_col) = add_snps_to_ws(ws,
                                                 cell_fmt_mg,
                                                 snps_info_mg,
                                                 snps_info_mg.snp_list)
    add_assoc_hap_header_to_ws(ws,
                               dflt_cell_fmt,
                               fltred_assoc_hap_mg.header,
                               n_snps_col-1)
    # Add haplotypes information
    start_haplos_col_idx = n_snps_col
    haplo_idx = 0
    stat_fmt = cell_fmt_mg.stat_fmts[DFLT_FMT]
    bp_fmt = cell_fmt_mg.bp_fmts[DFLT_FMT]
    for haplo_info in fltred_assoc_hap_mg.haplos_info:
        col = haplo_idx + start_haplos_col_idx
        add_haplo_stat_to_ws(ws, cell_fmt_mg, col, haplo_info, stat_fmt)
        # Map haplo to the corresponding markers
        bps_list = haplo_info.haplotype
        snps_list = haplo_info.snps
        for bp_idx in xrange(len(bps_list)):
            bp = bps_list[bp_idx]
            snp_code = snps_list[bp_idx]
            if snp_code in snps_rows_map:
                ws.write(snps_rows_map[snp_code], col, bp, bp_fmt)
        haplo_idx += 1
    haplos_count = fltred_assoc_hap_mg.haplos_count
    end_col_idx = start_haplos_col_idx + haplos_count - 1
    ws.set_column(start_haplos_col_idx, end_col_idx, HAPLO_COL_WIDTH)
    ws.freeze_panes(HAPLO_INFO_SIZE+1, start_haplos_col_idx)

# ****************************** main codes ******************************
new_section_txt(" Generating reports ")
wb = xlsxwriter.Workbook(out_file)

if plink_fams_haplos_file_prefix is not None:
    plink_gt_mg = PlinkGTManager(plink_fams_haplos_file_prefix,
                                 special_fam_infos=special_fam_infos,
                                 color_region_infos=color_region_infos)
    debug(plink_gt_mg)
snps_info_mg = SnpsInfoManager(snps_info_file)
debug(snps_info_mg)
report_haplos_mg = PlinkAssocHapManager(report_haplos_file)
debug(report_haplos_mg)
fltred_haplos_mg = PlinkAssocHapManager(fltred_haplos_file)
debug(fltred_haplos_mg)
cell_fmt_mg = CellFormatManager(wb, COLOR_RGB)
debug(cell_fmt_mg)
dflt_cell_fmt = cell_fmt_mg.default_format
add_full_master_haplos_sheet(wb,
                             cell_fmt_mg,
                             fltred_haplos_mg,
                             snps_info_mg,
                             )
if plink_fams_haplos_file_prefix is not None:
    add_full_all_fams_haplos_sheet(wb,
                                   cell_fmt_mg,
                                   plink_gt_mg,
                                   fltred_haplos_mg,
                                   snps_info_mg)
    if plink_fams_haplos_file_prefix is not None:
        add_fam_haplos_sheets(wb,
                              cell_fmt_mg,
                              plink_gt_mg,
                              fltred_haplos_mg,
                              snps_info_mg)
        info("done adding haplotypes sheet for each family")
add_report_haplos_sheet(wb,
                        cell_fmt_mg,
                        'significant haplos',
                        report_haplos_mg,
                        snps_info_mg,
                        )
info("done adding report for haplotypes with significant p value")

add_addn_csv_sheet(wb, dflt_cell_fmt, "filtered haplotypes", fltred_haplos_file)
add_addn_csv_sheet(wb, dflt_cell_fmt, "input", report_haplos_file)
for i in xrange(len(addn_csvs_list)):
    add_addn_csv_sheet(wb, addn_sheet_names[i], addn_sheet_csvs[i])

wb.close()

new_section_txt(" F I N I S H <" + script_name + "> ")
