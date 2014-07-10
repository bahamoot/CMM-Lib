from collections import OrderedDict
from collections import defaultdict
import sys
import csv
import xlsxwriter
import ntpath

import argparse

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

DFLT_FMT = 'default_format'

ZYGO_WT_CODE = 'wt'
ZYGO_NA_CODE = '.'

HORIZONTAL_SPLIT_IDX=1

script_name = ntpath.basename(sys.argv[0])

# ****************************** define classes ******************************
def isFloat(string):
    try:
        float(string)
        return True
    except ValueError:
        return False

class MutationsReportBase(object):
    """ A base object of mutations report class """

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

class CellFormatManager(MutationsReportBase):
    """ A class to define cell format property """

    def __init__(self, work_book, color_dict):
        self.__wb = work_book
        self.__color_dict = color_dict
        self.__dflt_hash_fmt = {'font_name': 'Arial', 'font_size': 10}
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
        dflt_cell_hash_fmt = self.__dflt_hash_fmt.copy()
        self.__cell_fmts = self.__init_colors_format(dflt_cell_hash_fmt)

    @property
    def n_colors(self):
        return len(self.__color_dict)

    @property
    def cell_fmts(self):
        return self.__cell_fmts

class PredictionTranslator(MutationsReportBase):
    """
    A class to translate codes from effect predictors by using informaiton
    from http://www.openbioinformatics.org/annovar/annovar_filter.html#ljb23
    """

    def get_raw_repr(self):
        return {"PhyloP code explanation ": self.pl_expl,
                "SIFT code explanation": self.sift_expl,
                "Polyphen2 code explanation": self.pp_expl,
                "LRT code explanation": self.lrt_expl,
                "MT code explanation": self.mt_expl,
                }

    def __init__(self):
        self.pl_expl = {}
        self.pl_expl['C'] = 'conserved'
        self.pl_expl['N'] = 'not conserved'
        self.sift_expl = {}
        self.sift_expl['T'] = 'tolerated'
        self.sift_expl['D'] = 'deleterious'
        self.pp_expl = {}
        self.pp_expl['D'] = 'probably damaging'
        self.pp_expl['P'] = 'possibly damaging'
        self.pp_expl['B'] = 'benign'
        self.lrt_expl = {}
        self.lrt_expl['D'] = 'tolerated'
        self.lrt_expl['N'] = 'neutral'
        self.lrt_expl['U'] = 'unknown'
        self.mt_expl = {}
        self.mt_expl['A'] = 'disease causing automatic'
        self.mt_expl['D'] = 'disease causing'
        self.mt_expl['N'] = 'polymorphism'
        self.mt_expl['P'] = 'polymorphism automatic'

class MutationRecord(MutationsReportBase):
    """ A class to parse and translate a mutation record """

    def __init__(self,
                 data,
                 col_idx_mg,
                 pred_tran,
                 freq_ratios=[]):
        self.__data = []
        for item in data:
            self.__data.append(item)
        self.__col_idx_mg = col_idx_mg
        self.__pred_tran = pred_tran
        self.__freq_ratios = freq_ratios
        self.__annotate_rarity()

    def get_raw_repr(self):
        return {"raw data": self.__data,
                "key": self.key,
                "func": self.func,
                "gene": self.gene,
                "exonic function": self.ex_func,
                "AA change": self.aa_change,
                "OAF": self.oaf,
                "MAF": self.maf,
                "DBSNP": self.dbsnp,
                "chromosome": self.chrom,
                "start position": self.start,
                "end position": self.end,
                "ref": self.ref,
                "obs": self.obs,
                "PhyloP": self.pl,
                "PhyloP prediction": self.pl_pred,
                "SIFT": self.sift,
                "SIFT prediction": self.sift_pred,
                "Polyphen2": self.pp,
                "Polyphen2 prediction": self.pp_pred,
                "LRT": self.lrt,
                "LRT prediction": self.lrt_pred,
                "MT": self.mt,
                "MT prediction": self.mt_pred,
                }

    def __getitem__(self, key):
        return self.__data[key]
      
    @property
    def key(self):
        return self[self.__col_idx_mg.IDX_KEY]

    @property
    def func(self):
        return self[self.__col_idx_mg.IDX_FUNC]

    @property
    def gene(self):
        return self[self.__col_idx_mg.IDX_GENE]

    @property
    def ex_func(self):
        return self[self.__col_idx_mg.IDX_EXFUNC]

    @property
    def aa_change(self):
        return self[self.__col_idx_mg.IDX_AACHANGE]

    @property
    def oaf(self):
        return float(self[self.__col_idx_mg.IDX_OAF])

    @property
    def maf(self):
        maf = self[self.__col_idx_mg.IDX_MAF]
        if isFloat(maf):
            return float(maf)
        else:
            return maf

    @property
    def dbsnp(self):
        return self[self.__col_idx_mg.IDX_DBSNP]

    @property
    def chrom(self):
        return self[self.__col_idx_mg.IDX_CHR]

    @property
    def start(self):
        return self[self.__col_idx_mg.IDX_START]

    @property
    def end(self):
        return self[self.__col_idx_mg.IDX_END]

    @property
    def ref(self):
        return self[self.__col_idx_mg.IDX_REF]

    @property
    def obs(self):
        return self[self.__col_idx_mg.IDX_OBS]

    @property
    def pl(self):
        return self[self.__col_idx_mg.IDX_PL]

    @property
    def pl_pred(self):
        pred_code = self[self.__col_idx_mg.IDX_PLPRED]
        if pred_code in self.__pred_tran.pl_expl:
            return self.__pred_tran.pl_expl[pred_code]
        else:
            return pred_code

    @property
    def sift(self):
        return self[self.__col_idx_mg.IDX_SIFT]

    @property
    def sift_pred(self):
        pred_code = self[self.__col_idx_mg.IDX_SIFTPRED]
        if pred_code in self.__pred_tran.sift_expl:
            return self.__pred_tran.sift_expl[pred_code]
        else:
            return pred_code

    @property
    def pp(self):
        return self[self.__col_idx_mg.IDX_PL]

    @property
    def pp_pred(self):
        pred_code = self[self.__col_idx_mg.IDX_PPPRED]
        if pred_code in self.__pred_tran.pp_expl:
            return self.__pred_tran.pp_expl[pred_code]
        else:
            return pred_code


    @property
    def lrt(self):
        return self[self.__col_idx_mg.IDX_LRT]

    @property
    def lrt_pred(self):
        pred_code = self[self.__col_idx_mg.IDX_LRTPRED]
        if pred_code in self.__pred_tran.lrt_expl:
            return self.__pred_tran.lrt_expl[pred_code]
        else:
            return pred_code

    @property
    def mt(self):
        return self[self.__col_idx_mg.IDX_MT]

    @property
    def mt_pred(self):
        pred_code = self[self.__col_idx_mg.IDX_MTPRED]
        if pred_code in self.__pred_tran.mt_expl:
            return self.__pred_tran.mt_expl[pred_code]
        else:
            return pred_code

    @property
    def zygosities(self):
        return self.__data[self.__col_idx_mg.IDX_MTPRED+1:
                           len(self.__data)]

    def __annotate_rarity(self):
        if len(self.__freq_ratios) == 0:
            self.__is_rare = False
        else:
            for freq_ratio in self.__freq_ratios:
                (col_name, ratio) = freq_ratio.split(':')
                if col_name == 'MAF':
                    maf = self.maf
                    if maf == "":
                        continue
                    if maf < float(ratio):
                        continue
                    if maf > (1-float(ratio)):
                        continue
                    self.__is_rare = False
                    return
                if col_name == 'OAF':
                    oaf = self.oaf
                    if oaf == "":
                        continue
                    if oaf < float(ratio):
                        continue
                    if oaf > (1-float(ratio)):
                        continue
                    self.__is_rare = False
                    return
            self.__is_rare = True

    @property
    def is_rare(self):
        return self.__is_rare

class MutationRecordIndexManager(MutationsReportBase):
    """ A class to handle a mutations report """

    COL_NAME_KEY = '#Key'
    COL_NAME_FUNC = 'Func'
    COL_NAME_GENE = 'Gene'
    COL_NAME_EXFUNC = 'ExonicFunc'
    COL_NAME_AACHANGE = 'AAChange'
    COL_NAME_OAF = 'OAF'
    COL_NAME_MAF = '1000g2012apr_ALL'
    COL_NAME_DBSNP = 'dbSNP137'
    COL_NAME_CHR = 'Chr'
    COL_NAME_START = 'Start'
    COL_NAME_END = 'End'
    COL_NAME_REF = 'Ref'
    COL_NAME_OBS = 'Obs'
    COL_NAME_PL = 'PhyloP'
    COL_NAME_PLPRED = 'PhyloP prediction'
    COL_NAME_SIFT = 'SIFT'
    COL_NAME_SIFTPRED = 'SIFT prediction'
    COL_NAME_PP = 'PolyPhen2'
    COL_NAME_PPPRED = 'PolyPhen2 prediction'
    COL_NAME_LRT = 'LRT'
    COL_NAME_LRTPRED = 'LRT prediction'
    COL_NAME_MT = 'MT'
    COL_NAME_MTPRED = 'MT prediction'

    def __init__(self, header):
        self.__raw_header = header
        self.__init_col_idx(header)

    def get_raw_repr(self):
        col_idx_fmt = "\n\t{col_name:<20}: {idx}"
        repr = "raw header: " + str(self.__raw_header)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_FUNC,
                                   idx=self.IDX_FUNC)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_GENE,
                                   idx=self.IDX_GENE)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_EXFUNC,
                                   idx=self.IDX_EXFUNC)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_AACHANGE,
                                   idx=self.IDX_AACHANGE)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_OAF,
                                   idx=self.IDX_OAF)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_MAF,
                                   idx=self.IDX_MAF)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_DBSNP,
                                   idx=self.IDX_DBSNP)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_CHR,
                                   idx=self.IDX_CHR)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_START,
                                   idx=self.IDX_START)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_END,
                                   idx=self.IDX_END)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_REF,
                                   idx=self.IDX_REF)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_OBS,
                                   idx=self.IDX_OBS)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_PL,
                                   idx=self.IDX_PL)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_PLPRED,
                                   idx=self.IDX_PLPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_SIFT,
                                   idx=self.IDX_SIFT)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_SIFTPRED,
                                   idx=self.IDX_SIFTPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_PP,
                                   idx=self.IDX_PP)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_PPPRED,
                                   idx=self.IDX_PPPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_LRT,
                                   idx=self.IDX_LRT)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_LRTPRED,
                                   idx=self.IDX_LRTPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_MT,
                                   idx=self.IDX_MT)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_MTPRED,
                                   idx=self.IDX_MTPRED)
        return repr
    
    def __init_col_idx(self, header):
        self.__col_idx = {}
        for idx in xrange(len(header)):
            self.__col_idx[header[idx]] = idx

    @property
    def IDX_KEY(self):
        return self.__col_idx[self.COL_NAME_KEY]

    @property
    def IDX_FUNC(self):
        return self.__col_idx[self.COL_NAME_FUNC]

    @property
    def IDX_GENE(self):
        return self.__col_idx[self.COL_NAME_GENE]

    @property
    def IDX_EXFUNC(self):
        return self.__col_idx[self.COL_NAME_EXFUNC]

    @property
    def IDX_AACHANGE(self):
        return self.__col_idx[self.COL_NAME_AACHANGE]

    @property
    def IDX_OAF(self):
        return self.__col_idx[self.COL_NAME_OAF]

    @property
    def IDX_MAF(self):
        return self.IDX_CHR - 2

    @property
    def IDX_DBSNP(self):
        return self.IDX_CHR - 1

    @property
    def IDX_CHR(self):
        return self.__col_idx[self.COL_NAME_CHR]

    @property
    def IDX_START(self):
        return self.__col_idx[self.COL_NAME_START]

    @property
    def IDX_END(self):
        return self.__col_idx[self.COL_NAME_END]

    @property
    def IDX_REF(self):
        return self.__col_idx[self.COL_NAME_REF]

    @property
    def IDX_OBS(self):
        return self.__col_idx[self.COL_NAME_OBS]

    @property
    def IDX_PL(self):
        return self.__col_idx[self.COL_NAME_PL]

    @property
    def IDX_PLPRED(self):
        return self.__col_idx[self.COL_NAME_PLPRED]

    @property
    def IDX_SIFT(self):
        return self.__col_idx[self.COL_NAME_SIFT]

    @property
    def IDX_SIFTPRED(self):
        return self.__col_idx[self.COL_NAME_SIFTPRED]

    @property
    def IDX_PP(self):
        return self.__col_idx[self.COL_NAME_PP]

    @property
    def IDX_PPPRED(self):
        return self.__col_idx[self.COL_NAME_PPPRED]

    @property
    def IDX_LRT(self):
        return self.__col_idx[self.COL_NAME_LRT]

    @property
    def IDX_LRTPRED(self):
        return self.__col_idx[self.COL_NAME_LRTPRED]

    @property
    def IDX_MT(self):
        return self.__col_idx[self.COL_NAME_MT]

    @property
    def IDX_MTPRED(self):
        return self.__col_idx[self.COL_NAME_MTPRED]

    def __getattr__(self, name):
        warn("attribute " + name + " cannot be found anywhere !!!")
        return -1

class MutationsReport(MutationsReportBase):
    """ A class to handle a mutations report """

    def __init__(self,
                 file_name,
                 sheet_name,
                 color_region_infos=[],
                 freq_ratios=[]):
        self.__file_name = file_name
        self.__sheet_name = sheet_name
        self.__freq_ratios = freq_ratios
        self.__col_idx_mg = MutationRecordIndexManager(self.header_rec)
        self.__pred_tran = PredictionTranslator()
        self.__load_color_region_infos(color_region_infos)
        self.record_size = len(self.header_rec)
        debug(self.__col_idx_mg)

    def get_raw_repr(self):
        return {"file name": self.__file_name,
                "sheet name": self.__sheet_name,
                "header": self.header_rec,
                "record size": self.record_size,
                "number of color regions": len(self.__color_regions),
                "predition translator": self.__pred_tran,
                }

    def __load_color_region_infos(self, color_region_infos):
        self.__color_regions = ColorRegions()
        for color_region_info in color_region_infos:
            self.__color_regions.append(color_region_info)
        self.__color_regions.sort_regions()

    @property
    def sheet_name(self):
        return self.__sheet_name

    @property
    def col_idx_mg(self):
        return self.__col_idx_mg

    @property
    def header_rec(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            header_rec = csv_reader.next()
            csvfile.close()
        return header_rec

    @property
    def mut_recs(self):
        self.__color_regions.init_comparison()
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            csv_reader.next()
            for raw_rec in csv_reader:
                mut_rec = MutationRecord(raw_rec,
                                         self.__col_idx_mg,
                                         self.__pred_tran,
                                         freq_ratios=self.__freq_ratios)
                mut_rec.marked_color = self.__color_regions.get_color(mut_rec.key)
                yield(mut_rec)
            csvfile.close()

    @property
    def mut_regs(self):
        return self.__color_regions

class ColorRegionRecord(MutationsReportBase):
    """ A class to parse coloring region infomation """

    KEY_FMT = "{chrom}_{pos}"

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
    def start_key(self):
        return self.KEY_FMT.format(chrom=self.__info[2].zfill(2),
                                   pos=self.__info[3].split('-')[0].zfill(12))

    @property
    def end_pos(self):
        return int(self.__info[3].split('-')[1])

    @property
    def end_key(self):
        return self.KEY_FMT.format(chrom=self.__info[2].zfill(2),
                                   pos=self.__info[3].split('-')[1].zfill(12))

class ColorRegions(MutationsReportBase):
    """ A manager class to handle coloring regions of each family """

    def __init__(self):
        self.__regions = []
        self.__active_region_idx = 0

    def get_raw_repr(self):
        reg_fmt = "\n\t{start_key} - {end_key}: {color}"
        repr = "number of regions: " + str(self.n_regions)
        for region in self.__regions:
            repr += reg_fmt.format(start_key=region.start_key,
                                   end_key=region.end_key,
                                   color=region.color)
        return repr

    def __len__(self):
        return len(self.__regions)

    @property
    def n_regions(self):
        return len(self)

    def __update_comparison_info(self):
        if self.n_regions > self.__active_region_idx:
            color_region = self.__regions[self.__active_region_idx]
            self.__active_chrom = color_region.chrom
            self.__active_start_key = color_region.start_key
            self.__active_end_key = color_region.end_key
            self.__active_color = color_region.color
        else:
            self.__active_chrom = None
            self.__active_start_key = 'zz_999999999999'
            self.__active_end_key = 'zz_999999999999'
            self.__active_color = None

    def init_comparison(self):
        self.__active_region_idx = 0
        self.__update_comparison_info()

    def get_color(self, position):
        while position > self.__active_end_key:
#            debug("No !! position : " + str(position) + "\tactive start key : " + str(self.__active_start_key) + "\tactive end key : " + str(self.__active_end_key))
            self.__active_region_idx += 1
            self.__update_comparison_info()
        if position >= self.__active_start_key:
#            debug("Yes !! position : " + str(position) + "\tactive start key : " + str(self.__active_start_key) + "\tactive end key : " + str(self.__active_end_key))
            return self.__active_color
        else:
#            debug("No !! position : " + str(position) + "\tactive start key : " + str(self.__active_start_key) + "\tactive end key : " + str(self.__active_end_key))
            return None

    def sort_regions(self):
        self.__regions.sort(key=lambda x:x.start_key, reverse=False)

    def append(self, item):
        self.__regions.append(item)

# ****************************** get arguments ******************************
argp = argparse.ArgumentParser(description="A script to manipulate csv files and group them into one xls")
tmp_help=[]
tmp_help.append("output xls file name")
argp.add_argument('-o', dest='out_file', help='output xls file name', required=True)
argp.add_argument('-s', dest='csvs', metavar='CSV INFO', help='list of csv files together with their name in comma and colon separators format', required=True)
argp.add_argument('-R', dest='marked_key_range', metavar='KEY RANGE', help='region to be marked <start_key,end_key> (for example, -R 9|000000123456,9|000000789012)', default=None)
argp.add_argument('-F', dest='frequency_ratios', metavar='NAME-FREQUENCY PAIR', help='Name of columns to be filtered and their frequencies <name_1:frequency_1,name_2:frequency_2,..> (for example, -F OAF:0.2,MAF:0.1)', default=None)
argp.add_argument('-C', dest='color_region_infos',
                        metavar='COLOR_REGION_INFOS',
                        help='color information of each region of interest',
                        default=None)
argp.add_argument('-D', dest='dev_mode',
                        action='store_true',
                        help='To enable development mode, this will effect the debuggin message and how the result is shown up',
                        default=False)
argp.add_argument('-l', dest='log_file',
                        metavar='FILE',
                        help='log file',
                        default=None)
#argp.add_argument('--coding_only', dest='coding_only', action='store_true', default=False, help='specified if the result should display non-coding mutations (default: display all mutations)')
args = argp.parse_args()

## ****************************************  parse arguments into local global variables  ****************************************
out_file = args.out_file
sheet_names = []
sheet_csvs = []
csvs_list = args.csvs.split(':')
for i in xrange(len(csvs_list)):
    sheet_info = csvs_list[i].split(',')
    sheet_names.append(sheet_info[0])
    sheet_csvs.append(sheet_info[1])
marked_key_range = args.marked_key_range
if marked_key_range is not None :
    marked_keys = marked_key_range.split(',')
    marked_start_key = marked_keys[0]
    marked_end_key = marked_keys[1]
if args.frequency_ratios is not None:
    frequency_ratios = args.frequency_ratios.split(',')
else:
    frequency_ratios = []
color_region_infos = []
if args.color_region_infos is not None:
    for info in args.color_region_infos.split(','):
        color_region_infos.append(ColorRegionRecord(info))
dev_mode = args.dev_mode
log_file = open(args.log_file, "a+")
#coding_only = args.coding_only

## **************  defining basic functions  **************
def write_log(msg):
    print >> log_file, msg

def output_msg(msg):
    print >> sys.stderr, msg
    write_log(msg)

def info(msg):
    info_fmt = "## [INFO] {msg}"
    formated_msg=info_fmt.format(msg=msg)
    output_msg(formated_msg)

def warn(msg):
    warn_fmt = "## [WARNING] {msg}"
    formated_msg=warn_fmt.format(msg=msg)
    output_msg(formated_msg)

def debug(msg):
    if dev_mode:
        debug_fmt = "## [DEBUG] {msg}"
        formated_msg=debug_fmt.format(msg=msg)
        output_msg(formated_msg)

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
new_section_txt(" S T A R T <" + script_name + "> ")
info("")
disp_header("parameters")
info("  " + " ".join(sys.argv[1:]))
info("")

## display required configuration
disp_header("required configuration")
disp_param("xls output file (-o)", out_file)
info("")

## display csvs configuration
disp_header("csvs configuration (-s)(" + str(len(csvs_list)) + " sheet(s))")
for i in xrange(len(csvs_list)):
    disp_param("sheet name #"+str(i+1), sheet_names[i])
    disp_param("sheet csv  #"+str(i+1), sheet_csvs[i])
info("")

## display optional configuration
disp_header("optional configuration")
if marked_key_range is not None :
    disp_subheader("marked key range")
    disp_subparam("start key", marked_start_key)
    disp_subparam("end key", marked_end_key)
if len(frequency_ratios) > 0:
    disp_subheader("frequency_ratios (-F)")
    for i in xrange(len(frequency_ratios)):
	(col_name, freq) = frequency_ratios[i].split(':')
        disp_subparam(col_name, freq)
if len(color_region_infos) > 0:
    disp_subheader("color regions information (-C)")
    for i in xrange(len(color_region_infos)):
        color_region_info = color_region_infos[i]
        disp_subparam("color info #"+str(i+1), color_region_info.raw_info)
if dev_mode:
    disp_param("developer mode (-D)", "ON")
#disp_param("hide non-coding mutations (--coding_only)", coding_only)


## ****************************************  executing  ****************************************
def set_layout(ws, col_idx_mg):
    # hide key, end postion and effect predictors columns
    ws.set_column(col_idx_mg.IDX_KEY, col_idx_mg.IDX_KEY, None, None, {'hidden': True})
    ws.set_column(col_idx_mg.IDX_END, col_idx_mg.IDX_END, None, None, {'hidden': True})
    ws.set_column(col_idx_mg.IDX_PL, col_idx_mg.IDX_MTPRED, None, None, {'hidden': True})
    # set column width
    ws.set_column(col_idx_mg.IDX_FUNC, col_idx_mg.IDX_FUNC, 6)
    ws.set_column(col_idx_mg.IDX_GENE, col_idx_mg.IDX_GENE, 6)
    ws.set_column(col_idx_mg.IDX_OAF, col_idx_mg.IDX_MAF, 5)
    ws.set_column(col_idx_mg.IDX_CHR, col_idx_mg.IDX_CHR, 2)
    ws.set_column(col_idx_mg.IDX_REF, col_idx_mg.IDX_OBS, 6)
    # freeze panes
    ws.freeze_panes(HORIZONTAL_SPLIT_IDX, col_idx_mg.IDX_PL)

def write_header(ws, cell_fmt_mg, header_rec, rec_size, col_idx_mg):
    cell_fmt = cell_fmt_mg.cell_fmts[DFLT_FMT]
    for col_idx in xrange(rec_size):
        ws.write(0, col_idx, header_rec[col_idx], cell_fmt)
    ws.write(0, col_idx_mg.IDX_MAF, 'MAF', cell_fmt)
    ws.write(0, col_idx_mg.IDX_DBSNP, 'dbSNP', cell_fmt)
    ws.write(0, col_idx_mg.IDX_START, 'start position', cell_fmt)
    ws.write(0, col_idx_mg.IDX_END, 'end position', cell_fmt)

def write_content(ws, cell_fmt_mg, row, content_rec, rec_size, col_idx_mg):
    rare = content_rec.is_rare
    if rare:
        cell_fmt = cell_fmt_mg.cell_fmts['YELLOW']
    else:
        cell_fmt = cell_fmt_mg.cell_fmts[DFLT_FMT]
    marked_color = content_rec.marked_color
    if marked_color is not None:
        marked_fmt = cell_fmt_mg.cell_fmts[marked_color]
#        debug(content_rec.marked_color)
    else:
        marked_fmt = cell_fmt
#        debug("marked color is None at " + content_rec.key)
    ws.write(row, col_idx_mg.IDX_KEY, content_rec.key, cell_fmt)
    ws.write(row, col_idx_mg.IDX_FUNC, content_rec.func, marked_fmt)
    ws.write(row, col_idx_mg.IDX_GENE, content_rec.gene, cell_fmt)
    ws.write(row, col_idx_mg.IDX_EXFUNC, content_rec.ex_func, cell_fmt)
    ws.write(row, col_idx_mg.IDX_AACHANGE, content_rec.aa_change, cell_fmt)
    ws.write(row, col_idx_mg.IDX_OAF, str(content_rec.oaf), cell_fmt)
    ws.write(row, col_idx_mg.IDX_MAF, str(content_rec.maf), cell_fmt)
    ws.write(row, col_idx_mg.IDX_DBSNP, content_rec.dbsnp, cell_fmt)
    ws.write(row, col_idx_mg.IDX_CHR, content_rec.chrom, cell_fmt)
    ws.write(row, col_idx_mg.IDX_START, content_rec.start, cell_fmt)
    ws.write(row, col_idx_mg.IDX_END, content_rec.end, cell_fmt)
    ws.write(row, col_idx_mg.IDX_REF, content_rec.ref, cell_fmt)
    ws.write(row, col_idx_mg.IDX_OBS, content_rec.obs, cell_fmt)
    ws.write(row, col_idx_mg.IDX_PL, content_rec.pl, cell_fmt)
    ws.write(row, col_idx_mg.IDX_PLPRED, content_rec.pl_pred, cell_fmt)
    ws.write(row, col_idx_mg.IDX_SIFT, content_rec.sift, cell_fmt)
    ws.write(row, col_idx_mg.IDX_SIFTPRED, content_rec.sift_pred, cell_fmt)
    ws.write(row, col_idx_mg.IDX_PP, content_rec.pp, cell_fmt)
    ws.write(row, col_idx_mg.IDX_PPPRED, content_rec.pp_pred, cell_fmt)
    ws.write(row, col_idx_mg.IDX_LRT, content_rec.lrt, cell_fmt)
    ws.write(row, col_idx_mg.IDX_LRTPRED, content_rec.lrt_pred, cell_fmt)
    ws.write(row, col_idx_mg.IDX_MT, content_rec.mt, cell_fmt)
    ws.write(row, col_idx_mg.IDX_MTPRED, content_rec.mt_pred, cell_fmt)
    zygo_col_idx = col_idx_mg.IDX_MTPRED
    # get cell format for zysities
    if rare:
        zygo_fmt = cell_fmt_mg.cell_fmts['LIGHT_BLUE']
        for zygo in content_rec.zygosities:
#            if zygo == '.':
#                zygo_fmt = cell_fmt
#                break
            if ((content_rec.maf == '') or (content_rec.maf < 0.2)) and (zygo == '.'):
                zygo_fmt = cell_fmt
                break
            if (content_rec.maf > 0.8) and (zygo == 'hom'):
                zygo_fmt = cell_fmt
                break
    else:
        zygo_fmt = cell_fmt
    for zygo in content_rec.zygosities:
        zygo_col_idx += 1
        ws.write(row, zygo_col_idx, zygo, zygo_fmt)
    if (marked_color is None):
        ws.set_row(row, None, None, {'hidden': True})
        return
#    if (not rare):
#        ws.set_row(row, None, None, {'hidden': True})
#        return
#    no_zygo_info = True
#    for zygo in content_rec.zygosities:
#        if zygo != '.':
#            no_zygo_info = False
#            break
#    if (no_zygo_info) and (content_rec.maf < 0.8):
#        ws.set_row(row, None, None, {'hidden': True})
#        return

def add_muts_sheet(wb, cell_fmt_mg, muts_rep):
    ws = wb.add_worksheet(muts_rep.sheet_name)
    ws.set_default_row(12)
    mut_rec_size = muts_rep.record_size
    write_header(ws,
                 cell_fmt_mg,
                 muts_rep.header_rec,
                 mut_rec_size,
                 muts_rep.col_idx_mg)
    # write content
    row = 1
    for mut_rec in muts_rep.mut_recs:
        write_content(ws,
                      cell_fmt_mg,
                      row,
                      mut_rec,
                      mut_rec_size,
                      muts_rep.col_idx_mg)
        row += 1
    set_layout(ws, muts_rep.col_idx_mg) 

        
# ****************************** main codes ******************************
new_section_txt(" Generating report ")

wb = xlsxwriter.Workbook(out_file)
cell_fmt_mg = CellFormatManager(wb, COLOR_RGB)
debug(cell_fmt_mg)

for i in xrange(len(csvs_list)):
    sheet_name = sheet_names[i]
    sheet_csv = sheet_csvs[i]
    muts_rep = MutationsReport(file_name=sheet_csvs[i],
                               sheet_name=sheet_names[i],
                               color_region_infos=color_region_infos,
                               freq_ratios=frequency_ratios)
    debug(muts_rep)
    debug(muts_rep.mut_regs)
    info("adding mutations sheet: " + sheet_name)
    add_muts_sheet(wb, cell_fmt_mg, muts_rep)

wb.close()

new_section_txt(" F I N I S H <" + script_name + "> ")
