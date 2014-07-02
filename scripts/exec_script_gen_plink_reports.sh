#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

if [ ! -z "$PLINK_REPORTS_CACHE_DIR" ]; then
    project_working_dir="$PLINK_REPORTS_PROJECT_OUT_DIR/tmp"
    if [ ! -d "$project_working_dir" ]; then
        mkdir "$project_working_dir"
    fi
    cp $PLINK_REPORTS_CACHE_DIR/* "$project_working_dir"
fi
if [ ! -z "$PLINK_REPORTS_PROJECT_CODE" ]; then
    cmd="$SCRIPT_GEN_PLINK_REPORTS -p $PLINK_REPORTS_PROJECT_CODE"
else
    cmd="$SCRIPT_GEN_PLINK_REPORT"
fi
if [ ! -z "$PLINK_REPORTS_TOTAL_RUN_TIME" ]; then
    cmd+=" -T $PLINK_REPORTS_TOTAL_RUN_TIME"
fi
cmd+=" -k $PLINK_REPORTS_RUNNING_KEY"
cmd+=" -b $PLINK_REPORTS_PLINK_BIN_FILE_PREFIX"
cmd+=" -W $PLINK_REPORTS_PLINK_HAP_WINDOW_SIZES"
if [ ! -z "$PLINK_REPORTS_PLINK_PHENO_FILE" ]; then
    cmd+=" -P $PLINK_REPORTS_PLINK_PHENO_FILE"
fi
if [ ! -z "$PLINK_REPORTS_FAMILIES_HAPLOTYPES_PLINK_TFILE_PREFIX" ]; then
    cmd+=" -f $PLINK_REPORTS_FAMILIES_HAPLOTYPES_PLINK_TFILE_PREFIX"
fi
if [ ! -z "$PLINK_REPORTS_TFAM_FAMILY_IDS" ]; then
    cmd+=" -I $PLINK_REPORTS_TFAM_FAMILY_IDS"
fi
if [ ! -z "$PLINK_REPORTS_SPECIAL_FAMILIES_INFO" ]; then
    cmd+=" -s $PLINK_REPORTS_SPECIAL_FAMILIES_INFO"
fi
if [ ! -z "$PLINK_REPORTS_PLINK_REGION" ]; then
    cmd+=" -R \"$PLINK_REPORTS_PLINK_REGION\""
fi
if [ ! -z "$PLINK_REPORTS_PVALUE_SIGNIFICANCE_RATIO" ]; then
    cmd+=" -S $PLINK_REPORTS_PVALUE_SIGNIFICANCE_RATIO"
fi
if [ ! -z "$PLINK_REPORTS_COLOR_REGION" ]; then
    cmd+=" -C $PLINK_REPORTS_COLOR_REGION"
fi
if [ ! -z "$PLINK_REPORTS_CACHE_DIR" ]; then
    if [ -z "$PLINK_REPORTS_PROJECT_CODE" ]; then
        cmd+=" -a"
    fi
fi
if [ "$PLINK_REPORTS_USE_CACHED_PLINK_EXTRA_INFO" = "On" ]; then
    cmd+=" -r"
fi
if [ "$PLINK_REPORTS_DEVELOPER_MODE" = "On" ]; then
    cmd+=" -D"
fi
cmd+=" -o $PLINK_REPORTS_PROJECT_OUT_DIR"
cmd+=" -l $PLINK_REPORTS_LOG_DIR"
eval $cmd
