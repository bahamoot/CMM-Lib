#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

if [ ! -z "$MUTATIONS_REPORTS_CACHE_DIR" ]; then
    project_data_out_dir="$MUTATIONS_REPORTS_PROJECT_OUT_DIR/data_out"
    if [ ! -d "$project_data_out_dir" ]; then
        mkdir "$project_data_out_dir"
    fi
    cp $MUTATIONS_REPORTS_CACHE_DIR/* "$project_data_out_dir"
fi
if [ ! -z "$MUTATIONS_REPORTS_PROJECT_CODE" ]; then
    cmd="$SCRIPT_GEN_MUTATIONS_REPORTS -p $MUTATIONS_REPORTS_PROJECT_CODE"
else
    cmd="$SCRIPT_GEN_MUTATIONS_REPORT"
fi
cmd+=" -k $MUTATIONS_REPORTS_RUNNING_KEY"
if [ ! -z "$MUTATIONS_REPORTS_TOTAL_RUN_TIME" ]; then
    cmd+=" -T $MUTATIONS_REPORTS_TOTAL_RUN_TIME"
fi
cmd+=" -t $MUTATIONS_REPORTS_TABIX_FILE"
if [ ! -z "$MUTATIONS_REPORTS_TABIX_VCF_REGION" ]; then
    cmd+=" -R \"$MUTATIONS_REPORTS_TABIX_VCF_REGION\""
fi
if [ ! -z "$MUTATIONS_REPORTS_COL_NAMES" ]; then
    cmd+=" -P \"$MUTATIONS_REPORTS_COL_NAMES\""
fi
if [ ! -z "$MUTATIONS_REPORTS_STAT_CONFIG" ]; then
    cmd+=" -S \"$MUTATIONS_REPORTS_STAT_CONFIG\""
fi
if [ ! -z "$MUTATIONS_REPORTS_FREQUENCY_RATIOS" ]; then
    cmd+=" -F $MUTATIONS_REPORTS_FREQUENCY_RATIOS"
fi
if [ ! -z "$MUTATIONS_REPORTS_CUSTOM_ZYGO_CODES" ]; then
    cmd+=" -Z $MUTATIONS_REPORTS_CUSTOM_ZYGO_CODES"
fi
if [ ! -z "$MUTATIONS_REPORTS_FAMILIES_INFO" ]; then
    cmd+=" -f \"$MUTATIONS_REPORTS_FAMILIES_INFO\""
fi
if [ ! -z "$MUTATIONS_REPORTS_EXTRA_ATTRIBUTES" ]; then
    cmd+=" -E "$MUTATIONS_REPORTS_EXTRA_ATTRIBUTES""
fi
if [ ! -z "$MUTATIONS_REPORTS_COLOR_REGION" ]; then
    cmd+=" -C $MUTATIONS_REPORTS_COLOR_REGION"
fi
if [ ! -z "$MUTATIONS_REPORTS_MODIFY_HEADER" ]; then
    cmd+=" -M $MUTATIONS_REPORTS_MODIFY_HEADER"
fi
if [ ! -z "$MUTATIONS_REPORTS_EXCLUSION_CRITERIAS" ]; then
    cmd+=" -e $MUTATIONS_REPORTS_EXCLUSION_CRITERIAS"
fi
if [ ! -z "$MUTATIONS_REPORTS_CACHE_DIR" ]; then
    if [ -z "$MUTATIONS_REPORTS_PROJECT_CODE" ]; then
        cmd+=" -c"
    fi
fi
if [ "$MUTATIONS_REPORTS_DEVELOPER_MODE" = "On" ]; then
    cmd+=" -D"
fi
cmd+=" -A $MUTATIONS_REPORTS_ANNOVAR_ROOT_DIR"
cmd+=" -o $MUTATIONS_REPORTS_PROJECT_OUT_DIR"
cmd+=" -l $MUTATIONS_REPORTS_SLURM_LOG_DIR"
eval $cmd
