#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

if [ ! -z "$PLINK_REPORTS_PROJECT_CODE" ]; then
    cmd="$SCRIPT_GEN_PLINK_REPORTS -p $PLINK_REPORTS_PROJECT_CODE"
else
    cmd="$SCRIPT_GEN_PLINK_REPORT"
fi
if [ ! -z "$PLINK_REPORTS_TOTAL_RUN_TIME" ]; then
    cmd+=" -t $PLINK_REPORTS_TOTAL_RUN_TIME"
fi
cmd+=" -k $PLINK_REPORTS_RUNNING_KEY"
cmd+=" -b $PLINK_REPORTS_PLINK_BIN_FILE_PREFIX"
cmd+=" -W $PLINK_REPORTS_PLINK_HAP_WINDOW_SIZES"
cmd+=" -w $PLINK_REPORTS_WORKING_DIR"
cmd+=" -o $PLINK_REPORTS_OUT_DIR"
cmd+=" -l $PLINK_REPORTS_LOG_DIR"

if [ "$PLINK_REPORTS_USE_CACHED_PLINK_HAP_ASSOC" = "On" ]; then
    cmd+=" -a"
fi
if [ "$PLINK_REPORTS_USE_CACHED_PLINK_EXTRA_INFO" = "On" ]; then
    cmd+=" -r"
fi
if [ ! -z "$PLINK_REPORTS_PLINK_PHENO_FILE" ]; then
    cmd+=" -P $PLINK_REPORTS_PLINK_PHENO_FILE"
fi
if [ ! -z "$PLINK_REPORTS_PLINK_REGION" ]; then
    cmd+=" -R \"$PLINK_REPORTS_PLINK_REGION\""
fi
if [ ! -z "$PLINK_REPORTS_PVALUE_SIGNIFICANCE_RATIO" ]; then
    cmd+=" -S $PLINK_REPORTS_PVALUE_SIGNIFICANCE_RATIO"
fi

eval $cmd
