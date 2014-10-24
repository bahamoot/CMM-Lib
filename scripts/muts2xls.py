from collections import OrderedDict
from collections import defaultdict
import sys
import csv
import xlsxwriter
import ntpath
import datetime

import argparse

ATTRIB_RARE = 'rare'
ATTRIB_HAS_SHARED = 'has_shared'
ATTRIB_HAS_MUTATION = 'has_mutation'
ATTRIB_STUDY = 'study'
ATTRIB_CASES_GE_CTRLS = 'cases_ge_ctrls'

CELL_TYPE_RARE = 'RARE'
CELL_TYPE_HARMFUL = 'HARMFUL'
CELL_TYPE_SHARED = 'SHARED'
CELL_TYPE_HOM_SHARED = 'HOM_SHARED'

INC_SHARED_MUTATION = 'S'

#DFLT_COLOR_RARE = 'YELLOW'
#DFLT_COLOR_HARMFUL = 'LIGHT_BLUE'
#DFLT_COLOR_SHARED = 'SILVER'

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

ZYGO_WT_KEY = 'WT'
ZYGO_NA_KEY = 'NA'
ZYGO_HOM_KEY = 'HOM'
ZYGO_HET_KEY = 'HET'
ZYGO_OTH_KEY = 'OTH'
ZYGO_CODES = OrderedDict()
ZYGO_CODES[ZYGO_HOM_KEY] = 'hom'
ZYGO_CODES[ZYGO_HET_KEY] = 'het'
ZYGO_CODES[ZYGO_WT_KEY] = 'wt'
ZYGO_CODES[ZYGO_NA_KEY] = '.'
ZYGO_CODES[ZYGO_OTH_KEY] = 'oth'

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
        self.pl_harmful = {}
        self.pl_harmful['C'] = True
        self.pl_harmful['N'] = False
        self.sift_expl = {}
        self.sift_expl['T'] = 'tolerated'
        self.sift_expl['D'] = 'deleterious'
        self.sift_harmful = {}
        self.sift_harmful['T'] = False
        self.sift_harmful['D'] = True
        self.pp_expl = {}
        self.pp_expl['D'] = 'probably damaging'
        self.pp_expl['P'] = 'possibly damaging'
        self.pp_expl['B'] = 'benign'
        self.pp_harmful = {}
        self.pp_harmful['D'] = True
        self.pp_harmful['P'] = True
        self.pp_harmful['B'] = False
        self.lrt_expl = {}
        self.lrt_expl['D'] = 'deleterious'
        self.lrt_expl['N'] = 'neutral'
        self.lrt_expl['U'] = 'unknown'
        self.lrt_harmful = {}
        self.lrt_harmful['D'] = True
        self.lrt_harmful['N'] = False
        self.lrt_harmful['U'] = False
        self.mt_expl = {}
        self.mt_expl['A'] = 'disease causing automatic'
        self.mt_expl['D'] = 'disease causing'
        self.mt_expl['N'] = 'polymorphism'
        self.mt_expl['P'] = 'polymorphism automatic'
        self.mt_harmful = {}
        self.mt_harmful['A'] = True
        self.mt_harmful['D'] = True
        self.mt_harmful['N'] = False
        self.mt_harmful['P'] = False

class Patient_Zygosity(MutationsReportBase):
    """ A class to parse and translate a mutation record """

    def __init__(self, zygo):
        self.__zygo = zygo
        self.shared_mutation = None

    @property
    def zygo(self):
        return self.__zygo

    @property
    def is_het(self):
        return self.__is_het

    @property
    def is_hom(self):
        return self.__is_hom

    @property
    def is_mutated(self):
        return self.__is_mutated

    @property
    def maf(self):
        return self.__maf

    @maf.setter
    def maf(self, value):
        self.__maf = value
        het = ZYGO_CODES[ZYGO_HET_KEY]
        hom = ZYGO_CODES[ZYGO_HOM_KEY]
        wt = ZYGO_CODES[ZYGO_WT_KEY]
        if self.__zygo == het:
            self.__is_het = True
        else:
            self.__is_het = False
        if (self.__zygo == hom) and ((value == '') or (value < 0.5)):
            self.__is_hom = True
        elif (self.__zygo == wt) and ((value != '') and (value >= 0.5)):
            self.__is_hom = True
        else:
            self.__is_hom = False
        if self.__is_het or self.__is_hom:
            self.__is_mutated = True
        else:
            self.__is_mutated = False

class MutationRecord(MutationsReportBase):
    """ A class to parse and translate a mutation record """

    def __init__(self,
                 data,
                 n_master_cols,
                 col_idx_mg,
                 ):
        self.__data = data
        self.__n_master_cols = n_master_cols
#        for item in data:
#            self.__data.append(item)
        self.__col_idx_mg = col_idx_mg

    def __getitem__(self, key):
        return self.__data[key]

    def __len__(self):
        return len(self.__data)

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
        return self[self.__col_idx_mg.IDX_OAF]

    @property
    def maf(self):
        return self[self.__col_idx_mg.IDX_1000G]

    @property
    def esp6500(self):
        return self[self.__col_idx_mg.IDX_ESP6500]

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
        return self[self.__col_idx_mg.IDX_PLPRED]

    @property
    def sift(self):
        return self[self.__col_idx_mg.IDX_SIFT]

    @property
    def sift_pred(self):
        return self[self.__col_idx_mg.IDX_SIFTPRED]

    @property
    def pp(self):
        return self[self.__col_idx_mg.IDX_PL]

    @property
    def pp_pred(self):
        return self[self.__col_idx_mg.IDX_PPPRED]


    @property
    def lrt(self):
        return self[self.__col_idx_mg.IDX_LRT]

    @property
    def lrt_pred(self):
        return self[self.__col_idx_mg.IDX_LRTPRED]

    @property
    def mt(self):
        return self[self.__col_idx_mg.IDX_MT]

    @property
    def mt_pred(self):
        return self[self.__col_idx_mg.IDX_MTPRED]

    @property
    def dan_freq(self):
        if self.__col_idx_mg.IDX_DAN_DB is not None:
            return self[self.__col_idx_mg.IDX_DAN_DB]
        else:
            return ""

    @property
    def others(self):
        return self.__data[self.__col_idx_mg.IDX_MTPRED+1: self.__n_master_cols]

    @property
    def patients(self):
        return self.__data[self.__n_master_cols: len(self.__data)]

    @property
    def n_master_cols(self):
        return self.__n_master_cols

class MutationContentRecord(MutationRecord):
    """ A class to parse and translate the content of a mutation record """

    def __init__(self,
                 data,
                 n_master_cols,
                 col_idx_mg,
                 pred_tran,
                 freq_ratios=[],
                 pat_grp_idxs=[]):
        MutationRecord.__init__(self, data, n_master_cols, col_idx_mg)
        self.__pred_tran = pred_tran
        self.__freq_ratios = freq_ratios
        self.__pat_grp_idxs = pat_grp_idxs
        self.__init_pat_zygos()
        self.__annotate_rarity()
        self.__check_zygosities()

    def get_raw_repr(self):
        return {"raw data": self.raw_data,
                "key": self.key,
                "func": self.func,
                "gene": self.gene,
                "exonic function": self.ex_func,
                "AA change": self.aa_change,
                "OAF": self.oaf,
                "1000G": self.maf,
                "ESP6500": self.esp6500,
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
                "Daniel DB": self.dan_freq,
                }

    @property
    def oaf(self):
        oaf = super(MutationContentRecord, self).oaf
        if isFloat(oaf):
            return float(oaf)
        else:
            return oaf

    @property
    def maf(self):
        maf = super(MutationContentRecord, self).maf
        if isFloat(maf):
            return float(maf)
        else:
            return maf

    @property
    def esp6500(self):
        esp6500 = super(MutationContentRecord, self).esp6500
        if isFloat(esp6500):
            return float(esp6500)
        else:
            return esp6500

    @property
    def pl_pred(self):
        pred_code = super(MutationContentRecord, self).pl_pred
        #pred_code = self[self.__col_idx_mg.IDX_PLPRED]
        if pred_code in self.__pred_tran.pl_expl:
            return self.__pred_tran.pl_expl[pred_code]
        else:
            return pred_code

    @property
    def pl_harmful(self):
        pred_code = super(MutationContentRecord, self).pl_pred
        #pred_code = self[self.__col_idx_mg.IDX_PLPRED]
        if pred_code in self.__pred_tran.pl_harmful:
            return self.__pred_tran.pl_harmful[pred_code]
        else:
            return False

    @property
    def sift_pred(self):
        pred_code = super(MutationContentRecord, self).sift_pred
        if pred_code in self.__pred_tran.sift_expl:
            return self.__pred_tran.sift_expl[pred_code]
        else:
            return pred_code

    @property
    def sift_harmful(self):
        pred_code = super(MutationContentRecord, self).sift_pred
        if pred_code in self.__pred_tran.sift_harmful:
            return self.__pred_tran.sift_harmful[pred_code]
        else:
            return False

    @property
    def pp_pred(self):
        pred_code = super(MutationContentRecord, self).pp_pred
        if pred_code in self.__pred_tran.pp_expl:
            return self.__pred_tran.pp_expl[pred_code]
        else:
            return pred_code

    @property
    def pp_harmful(self):
        pred_code = super(MutationContentRecord, self).pp_pred
        if pred_code in self.__pred_tran.pp_harmful:
            return self.__pred_tran.pp_harmful[pred_code]
        else:
            return False

    @property
    def lrt_pred(self):
        pred_code = super(MutationContentRecord, self).lrt_pred
        if pred_code in self.__pred_tran.lrt_expl:
            return self.__pred_tran.lrt_expl[pred_code]
        else:
            return pred_code

    @property
    def lrt_harmful(self):
        pred_code = super(MutationContentRecord, self).lrt_pred
        if pred_code in self.__pred_tran.lrt_harmful:
            return self.__pred_tran.lrt_harmful[pred_code]
        else:
            return False

    @property
    def mt_pred(self):
        pred_code = super(MutationContentRecord, self).mt_pred
        if pred_code in self.__pred_tran.mt_expl:
            return self.__pred_tran.mt_expl[pred_code]
        else:
            return pred_code

    @property
    def mt_harmful(self):
        pred_code = super(MutationContentRecord, self).mt_pred
        if pred_code in self.__pred_tran.mt_harmful:
            return self.__pred_tran.mt_harmful[pred_code]
        else:
            return False

    @property
    def dan_freq(self):
        dan_freq = super(MutationContentRecord, self).dan_freq
        if isFloat(dan_freq):
            return float(dan_freq)
        else:
            return dan_freq

    def __init_pat_zygos(self):
        pat_zygos = map(lambda x:Patient_Zygosity(x),
                         self.patients)
        for pat_zygo in pat_zygos:
            pat_zygo.maf = self.maf
        for grp in self.__pat_grp_idxs:
            shared_mutation = True
            for pat_idx in grp:
                if not pat_zygos[pat_idx].is_mutated:
                    shared_mutation = False
                    break
#            if len(grp) > 1:
#                shared_mutation = True
#                for pat_idx in grp:
#                    if not pat_zygos[pat_idx].is_mutated:
#                        shared_mutation = False
#                        break
#            else:
#                shared_mutation = False
            for pat_idx in grp:
                pat_zygos[pat_idx].shared_mutation = shared_mutation
        self.__pat_zygos = pat_zygos

    @property
    def pat_zygos(self):
        return self.__pat_zygos

    def __annotate_rarity(self):
        if len(self.__freq_ratios) == 0:
            self.__is_rare = False
        else:
            for freq_ratio in self.__freq_ratios:
                (col_name, ratio) = freq_ratio.split(':')
                if col_name == '1000G':
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
                if col_name == 'Daniel_DB':
                    dan_freq = self.dan_freq
                    if dan_freq == "":
                        continue
                    if dan_freq < float(ratio):
                        continue
                    if dan_freq > (1-float(ratio)):
                        continue
                    self.__is_rare = False
                    return
            self.__is_rare = True

    @property
    def is_rare(self):
        return self.__is_rare

    @property
    def cases_ge_ctrls(self):
        oaf = self.oaf
        if oaf == "":
            oaf = 1
        dan_freq = self.dan_freq
        if dan_freq == "":
            dan_freq = 0
        maf = self.maf
        if maf == "":
            maf = 0
        if (maf < 0.5) and (maf > oaf):
            return False
        if (maf >= 0.5) and (maf < oaf):
            return False
        if (dan_freq < 0.5) and (dan_freq > oaf):
            return False
        if (dan_freq >= 0.5) and (dan_freq < oaf):
            return False
        return True

#    def __is_mutated(self, zygo):
#        het = ZYGO_CODES[ZYGO_HET_KEY]
#        hom = ZYGO_CODES[ZYGO_HOM_KEY]
#        wt = ZYGO_CODES[ZYGO_WT_KEY]
#        maf = self.maf
#        if ((maf == '') or (maf < 0.5)) and ((zygo == het) or (zygo == hom)):
#            return True
#        if ((maf != '') and (maf >= 0.5)) and ((zygo == het) or (zygo == wt)):
#            return True
#        return False

    def __check_zygosities(self):
        self.__all_mutated = True
        self.__has_shared_mutation = False
        self.__has_mutation = False
        for pat_zygo in self.pat_zygos:
            if pat_zygo.is_mutated:
                self.__has_mutation = True
                break
        for pat_zygo in self.pat_zygos:
            if not pat_zygo.is_mutated:
                self.__all_mutated = False
                break
        for pat_zygo in self.pat_zygos:
            if pat_zygo.shared_mutation:
                self.__has_shared_mutation = True
                break

    @property
    def all_mutated(self):
        return self.__all_mutated

    @property
    def has_shared_mutation(self):
        return self.__has_shared_mutation

    @property
    def has_mutation(self):
        return self.__has_mutation

class MutationHeaderRecord(MutationRecord):
    """ A class to parse and translate the content of a mutation record """

    def __init__(self,
                 data,
                 n_master_cols,
                 col_idx_mg,
                 ):
        MutationRecord.__init__(self, data, n_master_cols, col_idx_mg)

    @property
    def patient_codes(self):
        return self.patients

class MutationRecordIndexManager(MutationsReportBase):
    """ A class to handle a mutations report """

    COL_NAME = {}
    COL_NAME['KEY'] = '#Key'
    COL_NAME['FUNC'] = 'Func'
    COL_NAME['GENE'] = 'Gene'
    COL_NAME['EXFUNC'] = 'ExonicFunc'
    COL_NAME['AACHANGE'] = 'AAChange'
    COL_NAME['OAF'] = 'OAF'
    COL_NAME['1000G'] = '1000g2012apr_ALL'
    COL_NAME['ESP6500'] = 'ESP6500_ALL'
    COL_NAME['DBSNP'] = 'dbSNP137'
    COL_NAME['CHR'] = 'Chr'
    COL_NAME['START'] = 'Start'
    COL_NAME['END'] = 'End'
    COL_NAME['REF'] = 'Ref'
    COL_NAME['OBS'] = 'Obs'
    COL_NAME['PL'] = 'PhyloP'
    COL_NAME['PLPRED'] = 'PhyloP prediction'
    COL_NAME['SIFT'] = 'SIFT'
    COL_NAME['SIFTPRED'] = 'SIFT prediction'
    COL_NAME['PP'] = 'PolyPhen2'
    COL_NAME['PPPRED'] = 'PolyPhen2 prediction'
    COL_NAME['LRT'] = 'LRT'
    COL_NAME['LRTPRED'] = 'LRT prediction'
    COL_NAME['MT'] = 'MT'
    COL_NAME['MTPRED'] = 'MT prediction'
    COL_NAME['DAN_DB'] = 'Daniel_DB'

    def __init__(self, header):
        self.__raw_header = header
        self.__init_col_idx(header)

    def get_raw_repr(self):
        col_idx_fmt = "\n\t{col_name:<20}: {idx}"
        repr = "raw header: " + str(self.__raw_header)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['FUNC'],
                                   idx=self.IDX_FUNC)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['GENE'],
                                   idx=self.IDX_GENE)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['EXFUNC'],
                                   idx=self.IDX_EXFUNC)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['AACHANGE'],
                                   idx=self.IDX_AACHANGE)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['OAF'],
                                   idx=self.IDX_OAF)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['1000G'],
                                   idx=self.IDX_1000G)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['ESP6500'],
                                   idx=self.IDX_ESP6500)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['DBSNP'],
                                   idx=self.IDX_DBSNP)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['CHR'],
                                   idx=self.IDX_CHR)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['START'],
                                   idx=self.IDX_START)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['END'],
                                   idx=self.IDX_END)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['REF'],
                                   idx=self.IDX_REF)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['OBS'],
                                   idx=self.IDX_OBS)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['PL'],
                                   idx=self.IDX_PL)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['PLPRED'],
                                   idx=self.IDX_PLPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['SIFT'],
                                   idx=self.IDX_SIFT)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['SIFTPRED'],
                                   idx=self.IDX_SIFTPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['PP'],
                                   idx=self.IDX_PP)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['PPPRED'],
                                   idx=self.IDX_PPPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['LRT'],
                                   idx=self.IDX_LRT)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['LRTPRED'],
                                   idx=self.IDX_LRTPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['MT'],
                                   idx=self.IDX_MT)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['MTPRED'],
                                   idx=self.IDX_MTPRED)
        repr += col_idx_fmt.format(col_name=self.COL_NAME['DAN_DB'],
                                   idx=self.IDX_DAN_DB)
        return repr
    
    def __init_col_idx(self, header):
        self.__col_idx = {}
        for key in self.COL_NAME:
            self.__col_idx[self.COL_NAME[key]] = None
        for idx in xrange(len(header)):
            self.__col_idx[header[idx]] = idx

    @property
    def IDX_KEY(self):
        return self.__col_idx[self.COL_NAME['KEY']]

    @property
    def IDX_FUNC(self):
        return self.__col_idx[self.COL_NAME['FUNC']]

    @property
    def IDX_GENE(self):
        return self.__col_idx[self.COL_NAME['GENE']]

    @property
    def IDX_EXFUNC(self):
        return self.__col_idx[self.COL_NAME['EXFUNC']]

    @property
    def IDX_AACHANGE(self):
        return self.__col_idx[self.COL_NAME['AACHANGE']]

    @property
    def IDX_OAF(self):
        return self.__col_idx[self.COL_NAME['OAF']]

    @property
    def IDX_1000G(self):
        return self.IDX_CHR - 3

    @property
    def IDX_ESP6500(self):
        return self.IDX_CHR - 2

    @property
    def IDX_DBSNP(self):
        return self.IDX_CHR - 1

    @property
    def IDX_CHR(self):
        return self.__col_idx[self.COL_NAME['CHR']]

    @property
    def IDX_START(self):
        return self.__col_idx[self.COL_NAME['START']]

    @property
    def IDX_END(self):
        return self.__col_idx[self.COL_NAME['END']]

    @property
    def IDX_REF(self):
        return self.__col_idx[self.COL_NAME['REF']]

    @property
    def IDX_OBS(self):
        return self.__col_idx[self.COL_NAME['OBS']]

    @property
    def IDX_PL(self):
        return self.__col_idx[self.COL_NAME['PL']]

    @property
    def IDX_PLPRED(self):
        return self.__col_idx[self.COL_NAME['PLPRED']]

    @property
    def IDX_SIFT(self):
        return self.__col_idx[self.COL_NAME['SIFT']]

    @property
    def IDX_SIFTPRED(self):
        return self.__col_idx[self.COL_NAME['SIFTPRED']]

    @property
    def IDX_PP(self):
        return self.__col_idx[self.COL_NAME['PP']]

    @property
    def IDX_PPPRED(self):
        return self.__col_idx[self.COL_NAME['PPPRED']]

    @property
    def IDX_LRT(self):
        return self.__col_idx[self.COL_NAME['LRT']]

    @property
    def IDX_LRTPRED(self):
        return self.__col_idx[self.COL_NAME['LRTPRED']]

    @property
    def IDX_MT(self):
        return self.__col_idx[self.COL_NAME['MT']]

    @property
    def IDX_MTPRED(self):
        return self.__col_idx[self.COL_NAME['MTPRED']]

    @property
    def IDX_DAN_DB(self):
        return self.__col_idx[self.COL_NAME['DAN_DB']]

    def __getattr__(self, name):
        warn("attribute " + name + " cannot be found anywhere !!!")
        return -1

class FamilyInfo(MutationsReportBase):
    """ A structure to keep Information of one family """

    def __init__(self, family_code):
        self.__family_code = family_code
        self.__members = []

    def get_raw_repr(self):
        return {"family code": self.fam_code,
                "members": self.__members,
                }

    @property
    def fam_code(self):
        return self.__family_code

    def append(self, full_patient_code):
        self.__members.append(full_patient_code)

    @property
    def members(self):
        return self.__members

class FamilyInfos(MutationsReportBase):
    """ A structure to keep Information of many families """

    def __init__(self):
        self.__fam_infos = {}
        self.__patient_idxs = {}

    def get_raw_repr(self):
        return {"number of families": self.n_families,
                "infos": self.__fam_infos,
                }

    @property
    def n_families(self):
        return len(self.__fam_infos)

    @property
    def patient_group_idxs(self):
        idxs = []
        for fam_code in self.__fam_infos:
            fam_info = self.__fam_infos[fam_code]
            tmp_idxs = []
            for member_code in fam_info.members:
                tmp_idxs.append(self.__patient_idxs[member_code])
            idxs.append(tmp_idxs)
        return idxs

    def append(self, full_patient_code):
        self.__patient_idxs[full_patient_code] = len(self.__patient_idxs)
        fam_code = full_patient_code.split('-')[0]
        if fam_code not in self.__fam_infos:
            self.__fam_infos[fam_code] = FamilyInfo(fam_code)
        self.__fam_infos[fam_code].append(full_patient_code)

class MutationsReport(MutationsReportBase):
    """ A class to handle a mutations report """

    def __init__(self,
                 file_name,
                 n_master_cols,
                 sheet_name,
                 color_region_infos=[],
                 freq_ratios=[]):
        self.__file_name = file_name
        self.__n_master_cols = n_master_cols
        self.__sheet_name = sheet_name
        self.__freq_ratios = freq_ratios
        self.__col_idx_mg = MutationRecordIndexManager(self.raw_header_rec)
        self.__pred_tran = PredictionTranslator()
        self.__load_color_region_infos(color_region_infos)
        self.__parse_families_info(self.header_rec)
        self.record_size = len(self.header_rec)
        debug(self.__col_idx_mg)

    def get_raw_repr(self):
        return {"file name": self.__file_name,
                "sheet name": self.__sheet_name,
                "header": self.header_rec,
                "record size": self.record_size,
                "number of color regions": len(self.__priority_regions),
                "predition translator": self.__pred_tran,
                }

    def __parse_families_info(self, header):
        self.__fam_infos = FamilyInfos()
        for patient_code in header.patient_codes:
            self.__fam_infos.append(patient_code)
        self.__pat_grp_idxs = self.__fam_infos.patient_group_idxs

    def __load_color_region_infos(self, color_region_infos):
        self.__priority_regions = PriorityRegions()
        for color_region_info in color_region_infos:
            self.__priority_regions.append(color_region_info)
        self.__priority_regions.sort_regions()

    @property
    def sheet_name(self):
        return self.__sheet_name

    @property
    def col_idx_mg(self):
        return self.__col_idx_mg

    @property
    def header_rec(self):
        return MutationHeaderRecord(self.raw_header_rec, self.__n_master_cols, self.__col_idx_mg)

    @property
    def raw_header_rec(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            raw_header_rec = csv_reader.next()
            csvfile.close()
        return raw_header_rec

    @property
    def mut_recs(self):
        self.__priority_regions.init_comparison()
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            csv_reader.next()
            for raw_rec in csv_reader:
                mut_rec = MutationContentRecord(raw_rec,
                                                n_master_cols,
                                                self.__col_idx_mg,
                                                pred_tran=self.__pred_tran,
                                                freq_ratios=self.__freq_ratios,
                                                pat_grp_idxs=self.__pat_grp_idxs)
                mut_rec.marked_color = self.__priority_regions.get_color(mut_rec.key)
                yield(mut_rec)
            csvfile.close()

    @property
    def mut_regs(self):
        return self.__priority_regions

class ColorRegionRecord(MutationsReportBase):
    """ A class to parse coloring region infomation """

    KEY_FMT = "{chrom}_{pos}"
    FAM_IDX = 0
    PRIORITY_IDX = 1
    COLOR_IDX = 2
    CHROM_IDX = 3
    POS_IDX = 4

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
        return self.__info[self.FAM_IDX]

    @property
    def priority(self):
        return self.__info[self.PRIORITY_IDX]

    @property
    def color(self):
        return self.__info[self.COLOR_IDX]

    @property
    def chrom(self):
        return self.__info[self.CHROM_IDX]

    @property
    def start_pos(self):
        return int(self.__info[self.POS_IDX].split('-')[0])

    @property
    def start_key(self):
        chrom_str = self.__info[self.CHROM_IDX].zfill(2)
        start_pos_str = self.__info[self.POS_IDX].split('-')[0].zfill(12)
        return self.KEY_FMT.format(chrom=chrom_str,
                                   pos=start_pos_str)

    @property
    def end_pos(self):
        return int(self.__info[self.POS_IDX].split('-')[1])

    @property
    def end_key(self):
        chrom_str = self.__info[self.CHROM_IDX].zfill(2)
        end_pos_str = self.__info[self.POS_IDX].split('-')[1].zfill(12)
        return self.KEY_FMT.format(chrom=chrom_str,
                                   pos=end_pos_str)

class ColorRegions(MutationsReportBase):
    """ A manager class to handle regions of each color """

    def __init__(self):
        self.__color_regions = []
        self.__active_region_idx = 0

    def get_raw_repr(self):
        reg_fmt = "\n\t{start_key} - {end_key}: {color}"
        repr = "number of regions: " + str(self.n_regions)
        for region in self.__color_regions:
            repr += reg_fmt.format(start_key=region.start_key,
                                   end_key=region.end_key,
                                   color=region.color)
        return repr

    def __getitem__(self, key):
        return self.__color_regions[key]

    def __len__(self):
        return len(self.__color_regions)

    @property
    def n_regions(self):
        return len(self)

    def __update_comparison_info(self):
        if self.n_regions > self.__active_region_idx:
            color_region = self.__color_regions[self.__active_region_idx]
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

    def get_color(self, current_rec_key):
        while current_rec_key > self.__active_end_key:
#            debug("No !! current_rec_key : " + str(current_rec_key) + "\tactive start key : " + str(self.__active_start_key) + "\tactive end key : " + str(self.__active_end_key))
            self.__active_region_idx += 1
            self.__update_comparison_info()
        if current_rec_key >= self.__active_start_key:
#            debug("Yes !! current_rec_key : " + str(current_rec_key) + "\tactive start key : " + str(self.__active_start_key) + "\tactive end key : " + str(self.__active_end_key))
            return self.__active_color
        else:
#            debug("No !! current_rec_key : " + str(current_rec_key) + "\tactive start key : " + str(self.__active_start_key) + "\tactive end key : " + str(self.__active_end_key))
            return None

    def sort_regions(self):
        self.__color_regions.sort(key=lambda x:x.start_key, reverse=False)

    def append(self, item):
        self.__color_regions.append(item)

class PriorityRegions(MutationsReportBase):
    """ A manager class to handle coloring regions"""

    def __init__(self):
        self.__priority_regions = defaultdict(ColorRegions)
        self.__active_region_idx = 0

    def get_raw_repr(self):
        reg_fmt = "\n\t{priority}: {start_key} - {end_key}: {color}"
        repr = "number of priorities: " + str(self.n_priorities)
        repr += "\n\tnumber of regions: " + str(self.n_regions)
        for priority in self.__priority_regions:
            color_regions = self.__priority_regions[priority]
            for region in color_regions:
                repr += reg_fmt.format(priority=priority,
                                       start_key=region.start_key,
                                       end_key=region.end_key,
                                       color=region.color)
        return repr

    def __len__(self):
        return len(self.__priority_regions)

    @property
    def n_priorities(self):
        return len(self)

    @property
    def n_regions(self):
        pri_regs = self.__priority_regions
        return sum(map(lambda x:pri_regs[x].n_regions, pri_regs))

    def init_comparison(self):
        for priority in self.__priority_regions:
            self.__priority_regions[priority].init_comparison()

    def get_color(self, current_rec_key):
        color = None
        for priority in self.__priority_regions:
            color_regions = self.__priority_regions[priority]
            color = color_regions.get_color(current_rec_key)
            if color is not None:
                break
        return color

    def sort_regions(self):
        tmp_dict = OrderedDict(sorted(self.__priority_regions.items(),
                                      reverse=True))
        self.__priority_regions = tmp_dict
        for priority in self.__priority_regions:
            self.__priority_regions[priority].sort_regions()

    def append(self, item):
        priority = item.priority
        self.__priority_regions[priority].append(item)

# ****************************** get arguments ******************************
argp = argparse.ArgumentParser(description="A script to manipulate csv files and group them into one xls")
tmp_help=[]
tmp_help.append("output xls file name")
argp.add_argument('-o', dest='out_file', help='output xls file name', required=True)
argp.add_argument('-A', dest='addn_csvs',
                        metavar='ADDITIONAL_CSVS',
                        help='list of addn informaion csv-format file in together with their name in comma and colon separators format',
                        default=None)
argp.add_argument('-s', dest='csvs', metavar='CSV INFO', help='list of csv files together with their name in comma and colon separators format', required=True)
argp.add_argument('-N', dest='n_master_cols', type=int, metavar='COLUMN COUNT', help='number of master data columns', required=True)
argp.add_argument('-R', dest='marked_key_range', metavar='KEY RANGES', help='regions to be marked', default=None)
argp.add_argument('-F', dest='frequency_ratios', metavar='NAME-FREQ PAIRS', help='name of columns to be filtered and their frequencies <name_1:frequency_1,name_2:frequency_2,..> (for example, -F OAF:0.2,1000G:0.1)', default=None)
argp.add_argument('-i', dest='inclusion_criteria', metavar='INCLUSION_CRITERIA', help='conditions of mutations to be ruled in (S: shared mutation)', default=None)
argp.add_argument('-E', dest='xtra_attribs', metavar='EXTRA ATTRIBUTES', help='list of extra attributes that will be in the columns after patient zygosities', default='')
argp.add_argument('-Z', dest='custom_zygo_codes', metavar='ZYGOSITY CODE', help='custom zygosity codes (default: '+str(ZYGO_CODES)+')', default=None)
argp.add_argument('-K', dest='cell_colors', metavar='CELL COLORS', help='custom cell colors (to replace the default ones)', default=None)
argp.add_argument('-C', dest='color_region_infos',
                        metavar='COLOR REGIONS',
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
if args.addn_csvs is not None:
    addn_csvs_list = args.addn_csvs.split(':')
else:
    addn_csvs_list = []
csvs_list = args.csvs.split(':')
n_master_cols = args.n_master_cols
marked_key_range = args.marked_key_range
if marked_key_range is not None :
    marked_keys = marked_key_range.split(',')
    marked_start_key = marked_keys[0]
    marked_end_key = marked_keys[1]
if args.frequency_ratios is not None:
    frequency_ratios = args.frequency_ratios.split(',')
else:
    frequency_ratios = []
if args.inclusion_criteria is not None:
    inc_criteria = args.inclusion_criteria.split(',')
else:
    inc_criteria = []
if len(args.xtra_attribs) != 0:
    xtra_attribs = args.xtra_attribs.split(',')
else:
    xtra_attribs = []
if args.custom_zygo_codes is not None:
    custom_zygo_codes = args.custom_zygo_codes.split(',')
    for custom_zygo_code in custom_zygo_codes:
        (key, code) = custom_zygo_code.split(':')
        ZYGO_CODES[key] = code
cell_colors = {}
cell_colors[CELL_TYPE_RARE] = DFLT_FMT
cell_colors[CELL_TYPE_SHARED] = DFLT_FMT
cell_colors[CELL_TYPE_HARMFUL] = DFLT_FMT
cell_colors[CELL_TYPE_HOM_SHARED] = DFLT_FMT
if args.cell_colors is not None:
    for cell_color in args.cell_colors.split(','):
        (cell_type, color_code) = cell_color.split(':')
        cell_colors[cell_type] = color_code
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
    debug_fmt = "## [DEBUG] {msg}"
    formated_msg=debug_fmt.format(msg=msg)
    if dev_mode:
        output_msg(formated_msg)
    else:
        write_log(formated_msg)

def throw(err_msg):
    error_fmt = "## [ERROR] {msg}"
    formated_msg=error_fmt.format(msg=err_msg)
    write_log(formated_msg)
    raise Exception(formated_msg)

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
disp_header("script configuration")
disp_param("parameters", " ".join(sys.argv[1:]))
disp_param("timestamp", datetime.datetime.now())
info("")

## display required configuration
disp_header("required configuration")
disp_param("xls output file (-o)", out_file)
disp_param("master columns count (-o)", n_master_cols)
info("")

## display csvs configuration
disp_header("csvs configuration (-s)(" + str(len(csvs_list)) + " sheet(s))")
for i in xrange(len(csvs_list)):
    (sheet_name, sheet_csv) = csvs_list[i].split(',')
    disp_param("sheet name #"+str(i+1), sheet_name)
    disp_param("sheet csv  #"+str(i+1), sheet_csv)
info("")

## display optional configuration
disp_header("optional configuration")
if len(addn_csvs_list) > 0:
    n_addn_sheet = len(addn_csvs_list)
    header_txt = "additional csv sheets configuration (-A)"
    header_txt += "(" + str(n_addn_sheet) + " sheet(s))"
    disp_subheader(header_txt)
    for i in xrange(len(addn_csvs_list)):
        (sheet_name, sheet_csv) = addn_csvs_list[i].split(',')
        disp_subparam("sheet name #"+str(i+1), sheet_name)
        disp_subparam("sheet csv  #"+str(i+1), sheet_csv)
if marked_key_range is not None :
    disp_subheader("marked key range")
    disp_subparam("start key", marked_start_key)
    disp_subparam("end key", marked_end_key)
if len(frequency_ratios) > 0:
    disp_subheader("frequency_ratios (-F)")
    for i in xrange(len(frequency_ratios)):
	(col_name, freq) = frequency_ratios[i].split(':')
        disp_subparam(col_name, freq)
if len(inc_criteria) > 0:
    disp_param("inclusion criteria", ",".join(inc_criteria))
if len(xtra_attribs) > 0:
    disp_subheader("extra attributes (-E)")
    for i in xrange(len(xtra_attribs)):
        disp_subparam("extra attributes #"+str(i+1), xtra_attribs[i])
disp_subheader("zygosity codes (-Z)")
for zygo_key in ZYGO_CODES:
    disp_subparam(zygo_key, ZYGO_CODES[zygo_key])
if args.cell_colors is not None:
    disp_param("cell colors (-K)", args.cell_colors)
if len(color_region_infos) > 0:
    disp_subheader("color regions information (-C)")
    for i in xrange(len(color_region_infos)):
        color_region_info = color_region_infos[i]
        disp_subparam("color info #"+str(i+1), color_region_info.raw_info)
if dev_mode:
    disp_param("developer mode (-D)", "ON")


## ****************************************  executing  ****************************************
def set_layout(ws, record_size, col_idx_mg):
    # hide key, end postion and effect predictors columns
    ws.set_column(col_idx_mg.IDX_KEY, col_idx_mg.IDX_KEY, None, None, {'hidden': True})
    ws.set_column(col_idx_mg.IDX_END, col_idx_mg.IDX_END, None, None, {'hidden': True})
#    ws.set_column(col_idx_mg.IDX_PL, col_idx_mg.IDX_MTPRED, None, None, {'hidden': True})
    # set column width
    ws.set_column(col_idx_mg.IDX_FUNC, col_idx_mg.IDX_FUNC, 12)
    ws.set_column(col_idx_mg.IDX_GENE, col_idx_mg.IDX_GENE, 10)
    ws.set_column(col_idx_mg.IDX_OAF, col_idx_mg.IDX_1000G, 7)
    ws.set_column(col_idx_mg.IDX_DBSNP, col_idx_mg.IDX_DBSNP, 10)
    ws.set_column(col_idx_mg.IDX_CHR, col_idx_mg.IDX_CHR, 2)
    ws.set_column(col_idx_mg.IDX_START, col_idx_mg.IDX_START, 10)
    ws.set_column(col_idx_mg.IDX_REF, col_idx_mg.IDX_OBS, 6)
    # freeze panes
    ws.freeze_panes(HORIZONTAL_SPLIT_IDX, col_idx_mg.IDX_PL)
    # set auto filter
    ws.autofilter(0, 0, 0, record_size-1)

def write_header(ws,
                 cell_fmt_mg,
                 header_rec,
                 rec_size,
                 col_idx_mg,
                 xtra_attribs,
                 ):
    cell_fmt = cell_fmt_mg.cell_fmts[DFLT_FMT]
    for col_idx in xrange(rec_size):
        ws.write(0, col_idx, header_rec[col_idx], cell_fmt)
    ws.write(0, col_idx_mg.IDX_1000G, '1000G', cell_fmt)
    ws.write(0, col_idx_mg.IDX_ESP6500, 'ESP6500', cell_fmt)
    ws.write(0, col_idx_mg.IDX_DBSNP, 'dbSNP', cell_fmt)
    ws.write(0, col_idx_mg.IDX_START, 'start position', cell_fmt)
    ws.write(0, col_idx_mg.IDX_END, 'end position', cell_fmt)
    for attrib_idx in xrange(len(xtra_attribs)):
        ws.write(0, rec_size + attrib_idx, xtra_attribs[attrib_idx], cell_fmt)

def write_content(ws,
                  cell_fmt_mg,
                  row,
                  content_rec,
                  rec_size,
                  col_idx_mg,
                  xtra_attribs,
                  ):
    dflt_cell_fmt = cell_fmt_mg.cell_fmts[DFLT_FMT]
    rare = content_rec.is_rare
    if rare:
        cell_fmt = cell_fmt_mg.cell_fmts['YELLOW']
    else:
        cell_fmt = dflt_cell_fmt
    marked_color = content_rec.marked_color
    if marked_color is not None:
        marked_fmt = cell_fmt_mg.cell_fmts[marked_color]
    else:
        marked_fmt = cell_fmt
    ws.write(row, col_idx_mg.IDX_KEY, content_rec.key, cell_fmt)
    ws.write(row, col_idx_mg.IDX_FUNC, content_rec.func, marked_fmt)
    ws.write(row, col_idx_mg.IDX_GENE, content_rec.gene, cell_fmt)
    ws.write(row, col_idx_mg.IDX_EXFUNC, content_rec.ex_func, cell_fmt)
    ws.write(row, col_idx_mg.IDX_AACHANGE, content_rec.aa_change, cell_fmt)
    ws.write(row, col_idx_mg.IDX_OAF, str(content_rec.oaf), cell_fmt)
    ws.write(row, col_idx_mg.IDX_1000G, str(content_rec.maf), cell_fmt)
    ws.write(row, col_idx_mg.IDX_ESP6500, str(content_rec.esp6500), cell_fmt)
    ws.write(row, col_idx_mg.IDX_DBSNP, content_rec.dbsnp, cell_fmt)
    ws.write(row, col_idx_mg.IDX_CHR, content_rec.chrom, cell_fmt)
    ws.write(row, col_idx_mg.IDX_START, content_rec.start, cell_fmt)
    ws.write(row, col_idx_mg.IDX_END, content_rec.end, cell_fmt)
    ws.write(row, col_idx_mg.IDX_REF, content_rec.ref, cell_fmt)
    ws.write(row, col_idx_mg.IDX_OBS, content_rec.obs, cell_fmt)
    ws.write(row, col_idx_mg.IDX_PL, content_rec.pl, dflt_cell_fmt)
    if content_rec.pl_harmful:
        harmful_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_HARMFUL]]
    else:
        harmful_fmt = dflt_cell_fmt
    ws.write(row, col_idx_mg.IDX_PLPRED, content_rec.pl_pred, harmful_fmt)
    ws.write(row, col_idx_mg.IDX_SIFT, content_rec.sift, dflt_cell_fmt)
    if content_rec.sift_harmful:
        harmful_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_HARMFUL]]
    else:
        harmful_fmt = dflt_cell_fmt
    ws.write(row, col_idx_mg.IDX_SIFTPRED, content_rec.sift_pred, harmful_fmt)
    ws.write(row, col_idx_mg.IDX_PP, content_rec.pp, dflt_cell_fmt)
    if content_rec.pp_harmful:
        harmful_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_HARMFUL]]
    else:
        harmful_fmt = dflt_cell_fmt
    ws.write(row, col_idx_mg.IDX_PPPRED, content_rec.pp_pred, harmful_fmt)
    ws.write(row, col_idx_mg.IDX_LRT, content_rec.lrt, dflt_cell_fmt)
    if content_rec.lrt_harmful:
        harmful_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_HARMFUL]]
    else:
        harmful_fmt = dflt_cell_fmt
    ws.write(row, col_idx_mg.IDX_LRTPRED, content_rec.lrt_pred, harmful_fmt)
    ws.write(row, col_idx_mg.IDX_MT, content_rec.mt, dflt_cell_fmt)
    if content_rec.mt_harmful:
        harmful_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_HARMFUL]]
    else:
        harmful_fmt = dflt_cell_fmt
    ws.write(row, col_idx_mg.IDX_MTPRED, content_rec.mt_pred, harmful_fmt)
    # write 'others' information
    others_col_idx = col_idx_mg.IDX_MTPRED
    for item in content_rec.others:
        others_col_idx += 1
        ws.write(row, others_col_idx, item, dflt_cell_fmt)
    # get cell format and write zygosities
    zygo_col_idx = content_rec.n_master_cols - 1
    for pat_zygo in content_rec.pat_zygos:
        zygo_col_idx += 1
        if rare and content_rec.all_mutated:
            zygo_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_HARMFUL]]
        elif pat_zygo.shared_mutation and pat_zygo.is_hom:
            zygo_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_HOM_SHARED]]
        elif pat_zygo.shared_mutation:
            zygo_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_SHARED]]
        elif rare and pat_zygo.is_mutated:
            zygo_fmt = cell_fmt_mg.cell_fmts[cell_colors[CELL_TYPE_RARE]]
#        elif pat_zygo.is_mutated:
#            zygo_fmt = cell_fmt
        else:
            zygo_fmt = dflt_cell_fmt
        ws.write(row, zygo_col_idx, pat_zygo.zygo, zygo_fmt)
    # add extra attributes
    for attrib_idx in xrange(len(xtra_attribs)):
        attrib = xtra_attribs[attrib_idx]
        cell_attrib = None
        if attrib == ATTRIB_RARE:
            if rare:
                cell_attrib = "yes"
            else:
                cell_attrib = "no"
        if attrib == ATTRIB_HAS_SHARED:
            if content_rec.has_shared_mutation:
                cell_attrib = "yes"
            else:
                cell_attrib = "no"
        if attrib == ATTRIB_STUDY:
            if marked_color is not None:
                cell_attrib = "yes"
            else:
                cell_attrib = "no"
        if attrib == ATTRIB_CASES_GE_CTRLS:
            if content_rec.cases_ge_ctrls:
                cell_attrib = "yes"
            else:
                cell_attrib = "no"
        if attrib == ATTRIB_HAS_MUTATION:
            if content_rec.has_mutation:
                cell_attrib = "yes"
            else:
                cell_attrib = "no"
        ws.write(row, rec_size+attrib_idx, cell_attrib, dflt_cell_fmt)
        
def add_sheet(wb, sheet_name):
    ws = wb.add_worksheet(sheet_name)
    ws.set_default_row(12)
    return ws

def add_muts_sheet(wb, cell_fmt_mg, muts_rep, xtra_attribs):
    ws = add_sheet(wb, muts_rep.sheet_name)
    #ws = wb.add_worksheet(muts_rep.sheet_name)
    ws.set_default_row(12)
    mut_rec_size = muts_rep.record_size
    write_header(ws,
                 cell_fmt_mg,
                 muts_rep.header_rec,
                 mut_rec_size,
                 muts_rep.col_idx_mg,
                 xtra_attribs)
    # write content
    row = 1
    for mut_rec in muts_rep.mut_recs:
        including = True
        for criterian in inc_criteria:
            if (criterian == INC_SHARED_MUTATION) and ( not mut_rec.has_shared_mutation):
                including = False
                break
        if including:
            write_content(ws,
                          cell_fmt_mg,
                          row,
                          mut_rec,
                          mut_rec_size,
                          muts_rep.col_idx_mg,
                          xtra_attribs)
            row += 1
    set_layout(ws, mut_rec_size+len(xtra_attribs), muts_rep.col_idx_mg) 
        
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

# ****************************** main codes ******************************
new_section_txt(" Generating report ")

wb = xlsxwriter.Workbook(out_file)
cell_fmt_mg = CellFormatManager(wb, COLOR_RGB)
dflt_cell_fmt = cell_fmt_mg.default_format
debug(cell_fmt_mg)

for main_csv in csvs_list:
    (sheet_name, sheet_csv) = main_csv.split(',')
    muts_rep = MutationsReport(file_name=sheet_csv,
                               n_master_cols=n_master_cols,
                               sheet_name=sheet_name,
                               color_region_infos=color_region_infos,
                               freq_ratios=frequency_ratios)
    debug(muts_rep)
    info("adding mutations sheet: " + sheet_name)
    add_muts_sheet(wb, cell_fmt_mg, muts_rep, xtra_attribs)

for addn_csv in addn_csvs_list:
    (sheet_name, sheet_csv) = addn_csv.split(',')
    add_addn_csv_sheet(wb, dflt_cell_fmt, sheet_name, sheet_csv)

wb.close()

new_section_txt(" F I N I S H <" + script_name + "> ")
