#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

if [ ! -z "$MUTATIONS_REPORTS_CACHE_DIR" ]; then
    project_data_out_dir="$MUTATIONS_REPORTS_PROJECT_DIR/data_out"
    if [ ! -d "$project_data_out_dir" ]; then
        mkdir "$project_data_out_dir"
    fi
    cp $MUTATIONS_REPORTS_CACHE_DIR/* "$project_data_out_dir"
    #cp $MUTATIONS_REPORTS_CACHE_DIR/* $MUTATIONS_REPORTS_WORKING_DIR
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
if [ ! -z "$MUTATIONS_REPORTS_VCF_REGION" ]; then
    cmd+=" -R \"$MUTATIONS_REPORTS_VCF_REGION\""
fi
if [ ! -z "$MUTATIONS_REPORTS_COL_NAMES" ]; then
    cmd+=" -c \"$MUTATIONS_REPORTS_COL_NAMES\""
fi
if [ ! -z "$MUTATIONS_REPORTS_OAF_RATIO" ]; then
    cmd+=" -W $MUTATIONS_REPORTS_OAF_RATIO"
fi
if [ ! -z "$MUTATIONS_REPORTS_MAF_RATIO" ]; then
    cmd+=" -F $MUTATIONS_REPORTS_MAF_RATIO"
fi
if [ ! -z "$MUTATIONS_REPORTS_FAMILIES_INFO" ]; then
    cmd+=" -f \"$MUTATIONS_REPORTS_FAMILIES_INFO\""
fi
if [ "$MUTATIONS_REPORTS_EXONIC_FILTERING" = "On" ]; then
    cmd+=" -e"
fi
if [ "$MUTATIONS_REPORTS_MISSENSE_FILTERING" = "On" ]; then
    cmd+=" -m"
fi
if [ "$MUTATIONS_REPORTS_DELETERIOUS_FILTERING" = "On" ]; then
    cmd+=" -d"
fi
if [ "$MUTATIONS_REPORTS_RARE_FILTERING" = "On" ]; then
    cmd+=" -r"
fi
if [ ! -z "$MUTATIONS_REPORTS_CACHE_DIR" ]; then
    if [ -z "$MUTATIONS_REPORTS_PROJECT_CODE" ]; then
        cmd+=" -C"
    fi
fi
cmd+=" -A $MUTATIONS_REPORTS_ANNOVAR_ROOT_DIR"
#cmd+=" -w $MUTATIONS_REPORTS_WORKING_DIR"
cmd+=" -o $MUTATIONS_REPORTS_PROJECT_DIR"
cmd+=" -l $MUTATIONS_REPORTS_LOG_DIR"
eval $cmd
