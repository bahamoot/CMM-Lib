from collections import defaultdict
import sys
import csv
import xlsxwriter
import ntpath

import argparse

HORIZONTAL_SPLIT_IDX=1

script_name = ntpath.basename(sys.argv[0])

# ****************************** define classes ******************************
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

class PredictionTranslator(MutationsReportBase):
    """
    A class to translate codes from effect predictors by using informaiton
    from http://www.openbioinformatics.org/annovar/annovar_filter.html#ljb23
    """

    def get_raw_repr(self):
        return {"PhyloP code explanation ": self.phylop_expl,
                "SIFT code explanation": self.sift_expl,
                "Polyphen2 code explanation": self.pp_expl,
                "LRT code explanation": self.lrt_expl,
                "MT code explanation": self.mt_expl,
                }

    def __init__(self):
        self.phylop_expl = {}
        self.phylop_expl['C'] = 'conserved'
        self.phylop_expl['N'] = 'not conserved'
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

    def __init__(self, data, col_idx_mgr, pred_tran):
        self.__data = []
        for item in data:
            self.__data.append(item)
        self.__col_idx_mgr = col_idx_mgr
        self.__pred_tran = pred_tran

    def get_raw_repr(self):
        return {"raw data": self.__data,
                "key": self.key,
                "func": self.func,
                "gene": self.gene,
                "exonic function": self.exonic_func,
                "AA change": self.aa_change,
                "OAF": self.oaf,
                "MAF": self.maf,
                "DBSNP": self.dbsnp,
                "chromosome": self.chrom,
                "start position": self.start,
                "end position": self.end,
                "ref": self.ref,
                "obs": self.obs,
                "PhyloP": self.phylop,
                "PhyloP prediction": self.phylop_pred,
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
        return self[self.__col_idx_mgr.IDX_KEY]

    @property
    def func(self):
        return self[self.__col_idx_mgr.IDX_FUNC]

    @property
    def gene(self):
        return self[self.__col_idx_mgr.IDX_GENE]

    @property
    def exonic_func(self):
        return self[self.__col_idx_mgr.IDX_EXONICFUNC]

    @property
    def aa_change(self):
        return self[self.__col_idx_mgr.IDX_AACHANGE]

    @property
    def oaf(self):
        return self[self.__col_idx_mgr.IDX_OAF]

    @property
    def maf(self):
        return self[self.__col_idx_mgr.IDX_MAF]

    @property
    def dbsnp(self):
        return self[self.__col_idx_mgr.IDX_DBSNP]

    @property
    def chrom(self):
        return self[self.__col_idx_mgr.IDX_CHR]

    @property
    def start(self):
        return self[self.__col_idx_mgr.IDX_START]

    @property
    def end(self):
        return self[self.__col_idx_mgr.IDX_END]

    @property
    def ref(self):
        return self[self.__col_idx_mgr.IDX_REF]

    @property
    def obs(self):
        return self[self.__col_idx_mgr.IDX_OBS]

    @property
    def phylop(self):
        return self[self.__col_idx_mgr.IDX_PHYLOP]

    @property
    def phylop_pred(self):
        pred_code = self[self.__col_idx_mgr.IDX_PHYLOPPRED]
        if pred_code in self.__pred_tran.phylop_expl:
            return self.__pred_tran.phylop_expl[pred_code]
        else:
            return pred_code

    @property
    def sift(self):
        return self[self.__col_idx_mgr.IDX_SIFT]

    @property
    def sift_pred(self):
        pred_code = self[self.__col_idx_mgr.IDX_SIFTPRED]
        if pred_code in self.__pred_tran.sift_expl:
            return self.__pred_tran.sift_expl[pred_code]
        else:
            return pred_code

    @property
    def pp(self):
        return self[self.__col_idx_mgr.IDX_PHYLOP]

    @property
    def pp_pred(self):
        pred_code = self[self.__col_idx_mgr.IDX_PPPRED]
        if pred_code in self.__pred_tran.pp_expl:
            return self.__pred_tran.pp_expl[pred_code]
        else:
            return pred_code


    @property
    def lrt(self):
        return self[self.__col_idx_mgr.IDX_LRT]

    @property
    def lrt_pred(self):
        pred_code = self[self.__col_idx_mgr.IDX_LRTPRED]
        if pred_code in self.__pred_tran.lrt_expl:
            return self.__pred_tran.lrt_expl[pred_code]
        else:
            return pred_code

    @property
    def mt(self):
        return self[self.__col_idx_mgr.IDX_MT]

    @property
    def mt_pred(self):
        pred_code = self[self.__col_idx_mgr.IDX_MTPRED]
        if pred_code in self.__pred_tran.mt_expl:
            return self.__pred_tran.mt_expl[pred_code]
        else:
            return pred_code

    def is_rare(self, ratio):
        maf = self.maf
        if  (maf == "") or (float(maf) < ratio):
            return True
        else:
            return False

class MutationRecordIndexManager(MutationsReportBase):
    """ A class to handle a mutations report """

    COL_NAME_KEY = '#Key'
    COL_NAME_FUNC = 'Func'
    COL_NAME_GENE = 'Gene'
    COL_NAME_EXONICFUNC = 'ExonicFunc'
    COL_NAME_AACHANGE = 'AAChange'
    COL_NAME_OAF = 'OAF'
    COL_NAME_MAF = '1000g2012apr_ALL'
    COL_NAME_DBSNP = 'dbSNP137'
    COL_NAME_CHR = 'Chr'
    COL_NAME_START = 'Start'
    COL_NAME_END = 'End'
    COL_NAME_REF = 'Ref'
    COL_NAME_OBS = 'Obs'
    COL_NAME_PHYLOP = 'PhyloP'
    COL_NAME_PHYLOPPRED = 'PhyloP prediction'
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
        repr += col_idx_fmt.format(col_name=self.COL_NAME_EXONICFUNC,
                                   idx=self.IDX_EXONICFUNC)
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
        repr += col_idx_fmt.format(col_name=self.COL_NAME_PHYLOP,
                                   idx=self.IDX_PHYLOP)
        repr += col_idx_fmt.format(col_name=self.COL_NAME_PHYLOPPRED,
                                   idx=self.IDX_PHYLOPPRED)
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
    def IDX_EXONICFUNC(self):
        return self.__col_idx[self.COL_NAME_EXONICFUNC]

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
    def IDX_PHYLOP(self):
        return self.__col_idx[self.COL_NAME_PHYLOP]

    @property
    def IDX_PHYLOPPRED(self):
        return self.__col_idx[self.COL_NAME_PHYLOPPRED]

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

    def __init__(self, file_name, sheet_name):
        self.__file_name = file_name
        self.__sheet_name = sheet_name
        self.__col_idx_mgr = MutationRecordIndexManager(self.header_rec)
        self.__pred_tran = PredictionTranslator()
        self.record_size = len(self.header_rec)
        debug(self.__col_idx_mgr)

    def get_raw_repr(self):
        return {"file name": self.__file_name,
                "sheet name": self.__sheet_name,
                "header": self.header_rec,
                "record size": self.record_size,
                "predition translator": self.__pred_tran,
                }

    @property
    def sheet_name(self):
        return self.__sheet_name

    @property
    def col_idx_mgr(self):
        return self.__col_idx_mgr

    @property
    def header_rec(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            header_rec = csv_reader.next()
            csvfile.close()
        return header_rec

    @property
    def mut_recs(self):
        with open(self.__file_name, 'rb') as csvfile:
            csv_reader = csv.reader(csvfile, delimiter='\t')
            csv_reader.next()
            for mut_rec in csv_reader:
                yield(MutationRecord(mut_rec,
                                     self.__col_idx_mgr,
                                     self.__pred_tran))
            csvfile.close()

# ****************************** get arguments ******************************
argp = argparse.ArgumentParser(description="A script to manipulate csv files and group them into one xls")
tmp_help=[]
tmp_help.append("output xls file name")
argp.add_argument('-o', dest='out_file', help='output xls file name', required=True)
argp.add_argument('-s', dest='csvs', metavar='CSV INFO', help='list of csv files together with their name in comma and colon separators format', required=True)
argp.add_argument('-R', dest='marked_key_range', metavar='KEY RANGE', help='region to be marked <start_key,end_key> (for example, -R 9|000000123456,9|000000789012)', default=None)
argp.add_argument('-F', dest='filter_frequencies', metavar='IDX-FREQUENCY PAIR', help='indexes of columns be filtered and their frequencies <idx_1:frequency_1,idx2:frequency_2,..> (for example, -F 3:0.2,4:0.1)', default=None)
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
sheet_name = []
sheet_csv = []
csvs_list = args.csvs.split(':')
for i in xrange(len(csvs_list)):
    sheet_info = csvs_list[i].split(',')
    sheet_name.append(sheet_info[0])
    sheet_csv.append(sheet_info[1])
marked_key_range = args.marked_key_range
if marked_key_range is not None :
    marked_keys = marked_key_range.split(',')
    marked_start_key = marked_keys[0]
    marked_end_key = marked_keys[1]
if args.filter_frequencies is not None:
    filter_frequencies = args.filter_frequencies.split(',')
else:
    filter_frequencies = []
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
    disp_param("sheet name #"+str(i+1), sheet_name[i])
    disp_param("sheet csv  #"+str(i+1), sheet_csv[i])
info("")

## display optional configuration
disp_header("optional configuration")
if marked_key_range is not None :
    disp_subheader("marked key range")
    disp_subparam("start key", marked_start_key)
    disp_subparam("end key", marked_end_key)
if len(filter_frequencies) > 0:
    disp_subheader("filter_frequencies (-F)")
    for i in xrange(len(filter_frequencies)):
	(filter_idx, filter_ratio) = filter_frequencies[i].split(':')
        disp_subparam("idx   #"+str(i+1), filter_idx)
        disp_subparam("ratio #"+str(i+1), filter_ratio)
if dev_mode:
    disp_param("developer mode (-D)", "ON")
#disp_param("hide non-coding mutations (--coding_only)", coding_only)


## ****************************************  executing  ****************************************
def isFloat(string):
    try:
        float(string)
        return True
    except ValueError:
        return False

def set_layout(ws, col_idx_mgr):
    # hide key, end postion and effect predictors columns
    ws.set_column(col_idx_mgr.IDX_KEY, col_idx_mgr.IDX_KEY, None, None, {'hidden': True})
    ws.set_column(col_idx_mgr.IDX_END, col_idx_mgr.IDX_END, None, None, {'hidden': True})
    ws.set_column(col_idx_mgr.IDX_PHYLOP, col_idx_mgr.IDX_MTPRED, None, None, {'hidden': True})
    # set column width
    ws.set_column(col_idx_mgr.IDX_FUNC, col_idx_mgr.IDX_FUNC, 6)
    ws.set_column(col_idx_mgr.IDX_GENE, col_idx_mgr.IDX_GENE, 6)
    ws.set_column(col_idx_mgr.IDX_OAF, col_idx_mgr.IDX_MAF, 5)
    ws.set_column(col_idx_mgr.IDX_CHR, col_idx_mgr.IDX_CHR, 2)
    ws.set_column(col_idx_mgr.IDX_REF, col_idx_mgr.IDX_OBS, 4)
    # freeze panes
    ws.freeze_panes(HORIZONTAL_SPLIT_IDX, col_idx_mgr.IDX_PHYLOP)

def write_header(ws, header_rec, rec_size, col_idx_mgr):
    for col_idx in xrange(rec_size):
        ws.write(0, col_idx, header_rec[col_idx], st['normal'])
    ws.write(0, col_idx_mgr.IDX_MAF, 'MAF', st['normal'])
    ws.write(0, col_idx_mgr.IDX_DBSNP, 'dbSNP', st['normal'])
    ws.write(0, col_idx_mgr.IDX_START, 'start position', st['normal'])
    ws.write(0, col_idx_mgr.IDX_END, 'end position', st['normal'])

def write_content(ws, row, content_rec, rec_size, col_idx_mgr):
    if content_rec.is_rare(0.2):
        rec_st = st['rare']
    else:
        rec_st = st['normal']
    ws.write(row, col_idx_mgr.IDX_KEY, content_rec.key, rec_st)
    ws.write(row, col_idx_mgr.IDX_FUNC, content_rec.func, rec_st)
    ws.write(row, col_idx_mgr.IDX_GENE, content_rec.gene, rec_st)
    ws.write(row, col_idx_mgr.IDX_EXONICFUNC, content_rec.exonic_func, rec_st)
    ws.write(row, col_idx_mgr.IDX_AACHANGE, content_rec.aa_change, rec_st)
    ws.write(row, col_idx_mgr.IDX_OAF, content_rec.oaf, rec_st)
    ws.write(row, col_idx_mgr.IDX_MAF, content_rec.maf, rec_st)
    ws.write(row, col_idx_mgr.IDX_DBSNP, content_rec.dbsnp, rec_st)
    ws.write(row, col_idx_mgr.IDX_CHR, content_rec.chrom, rec_st)
    ws.write(row, col_idx_mgr.IDX_START, content_rec.start, rec_st)
    ws.write(row, col_idx_mgr.IDX_END, content_rec.end, rec_st)
    ws.write(row, col_idx_mgr.IDX_REF, content_rec.ref, rec_st)
    ws.write(row, col_idx_mgr.IDX_OBS, content_rec.obs, rec_st)
    ws.write(row, col_idx_mgr.IDX_PHYLOP, content_rec.phylop, rec_st)
    ws.write(row, col_idx_mgr.IDX_PHYLOPPRED, content_rec.phylop_pred, rec_st)
    ws.write(row, col_idx_mgr.IDX_SIFT, content_rec.sift, rec_st)
    ws.write(row, col_idx_mgr.IDX_SIFTPRED, content_rec.sift_pred, rec_st)
    ws.write(row, col_idx_mgr.IDX_PP, content_rec.pp, rec_st)
    ws.write(row, col_idx_mgr.IDX_PPPRED, content_rec.pp_pred, rec_st)
    ws.write(row, col_idx_mgr.IDX_LRT, content_rec.lrt, rec_st)
    ws.write(row, col_idx_mgr.IDX_LRTPRED, content_rec.lrt_pred, rec_st)
    ws.write(row, col_idx_mgr.IDX_MT, content_rec.mt, rec_st)
    ws.write(row, col_idx_mgr.IDX_MTPRED, content_rec.mt_pred, rec_st)
    for col_idx in xrange(col_idx_mgr.IDX_MTPRED, rec_size):
        ws.write(row, col_idx, content_rec[col_idx], rec_st)

def add_muts_sheet(wb, muts_rep, st):
    ws = wb.add_worksheet(muts_rep.sheet_name)
    ws.set_default_row(10)
    mut_rec_size = muts_rep.record_size
    write_header(ws, muts_rep.header_rec, mut_rec_size, muts_rep.col_idx_mgr)
    # write content
    row = 1
    for mut_rec in muts_rep.mut_recs:
        write_content(ws, row, mut_rec, mut_rec_size, muts_rep.col_idx_mgr)
        row += 1
    set_layout(ws, muts_rep.col_idx_mgr) 

        
#    with open(csv_file, 'rb') as csvfile:
#        csv_recs = list(csv.reader(csvfile, delimiter='\t'))
#        csv_row = 0
#        for xls_row in xrange(len(csv_recs)):
#            csv_rec = csv_recs[xls_row]
#            csv_rec = explain_annotation(csv_rec)
#            it_is_common_mutations = False
#            if common_mut_col_idx_range is not None:
#    	        it_is_common_mutations = True
#    	        for col_idx in xrange(common_mut_start_col_idx, common_mut_end_col_idx):
#    	            if (csv_rec[col_idx] != 'het') and (csv_rec[col_idx] != 'hom'):
#    		            it_is_common_mutations = False
#            else:
#    	        it_is_common_mutations = False
#            for col in xrange(len(csv_rec)):
#    	        # mark common mutations
#    	        if (it_is_common_mutations) and (col in range(common_mut_start_col_idx, common_mut_end_col_idx)):
#                    ws.write(csv_row, col, csv_rec[col], st['common'])
#    	        # mark region of interest
#    	        elif (marked_key_range is not None) and (col == 1) and (csv_rec[IDX_MUTS_REPS_KEY] > marked_start_key) and (csv_rec[IDX_MUTS_REPS_KEY] < marked_end_key) :
#                    ws.write(csv_row, col, csv_rec[col], st['interest'])
#    	        elif len(filter_frequencies) > 0:
#        	        # mark rare mutations
#    	            rare_mutation = True
#    	            for item in filter_frequencies:
#    		            (filter_idx, filter_ratio) = item.split(':')
#    		            if not ((isFloat(csv_rec[int(filter_idx)]) and (float(csv_rec[int(filter_idx)])<=float(filter_ratio))) or (csv_rec[int(filter_idx)]=='')):
#    		                rare_mutation = False
#    		                break
#                    #elif (len(csv_rec) > IDX_COL_OAF) and ((((isFloat(csv_rec[IDX_COL_OAF]) and (float(csv_rec[IDX_COL_OAF])<=0.1)) or (csv_rec[IDX_COL_OAF]=='')) and ((isFloat(csv_rec[IDX_COL_MAF]) and (float(csv_rec[IDX_COL_MAF])<0.1)) or (csv_rec[IDX_COL_MAF]==''))) and (csv_rec[IDX_COL_MAF] != 'nonsynonymous SNV')):
#    	            if rare_mutation:
#    		            ws.write(csv_row, col, csv_rec[col], st['rare'])
#                    else:
#                        ws.write(csv_row, col, csv_rec[col], st['normal'])
#    	        else:
#                    ws.write(csv_row, col, csv_rec[col], st['normal'])
#            csv_row += 1
#    hide_cols_idx_list = hide_cols_idx.split(',')
#    for i in xrange(len(hide_cols_idx_list)):
#        ws.set_column(int(hide_cols_idx_list[i]), int(hide_cols_idx_list[i]), None, None, {'hidden': True})
#    ws.freeze_panes(hor_split_idx, ver_split_idx)

# ****************************** main codes ******************************
new_section_txt(" Generating report ")

wb = xlsxwriter.Workbook(out_file)
st = {}
st['normal'] = wb.add_format({'font_name': 'Arial', 'font_size': 10})
st['common'] = wb.add_format({'font_name': 'Arial', 'font_size': 10, 'bg_color': 'lime'})
st['interest'] = wb.add_format({'font_name': 'Arial', 'font_size': 10, 'bg_color': 'pale_blue'})
st['rare'] = wb.add_format({'font_name': 'Arial', 'font_size': 10, 'bg_color': 'yellow'})

for i in xrange(len(csvs_list)):
    muts_rep = MutationsReport(file_name=sheet_csv[i],
                               sheet_name=sheet_name[i])
    debug(muts_rep)
    add_muts_sheet(wb, muts_rep, st)

wb.close()

new_section_txt(" F I N I S H <" + script_name + "> ")
