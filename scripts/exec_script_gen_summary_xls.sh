#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

cmd="$SCRIPT_GEN_SUMMARY_XLS -k $SUMMARY_XLS_RUNNING_KEY -O $SUMMARY_XLS_OAF_IN_FILE -S $SUMMARY_XLS_SA_IN_FILE -w $SUMMARY_XLS_WORKING_DIR -o $SUMMARY_XLS_OUT_DIR"
if [ ! -z "$SUMMARY_XLS_GT_VCF_GT_IN_FILE" ]; then
    cmd+=" -G $SUMMARY_XLS_GT_VCF_GT_IN_FILE"
fi
if [ ! -z "$SUMMARY_XLS_MT_VCF_GT_IN_FILE" ]; then
    cmd+=" -M $SUMMARY_XLS_MT_VCF_GT_IN_FILE"
fi
if [ ! -z "$SUMMARY_XLS_VCF_REGION" ]; then
    cmd+=" -R $SUMMARY_XLS_VCF_REGION"
fi
if [ "$SUMMARY_XLS_EXONIC_FILTERING" = "On" ]; then
    cmd+=" -e"
fi
if [ "$SUMMARY_XLS_MISSENSE_FILTERING" = "On" ]; then
    cmd+=" -m"
fi
if [ "$SUMMARY_XLS_DELETERIOUS_FILTERING" = "On" ]; then
    cmd+=" -d"
fi
#if [ "$SUMMARY_XLS_RARE_FILTERING" = "On" ]; then
#    cmd+=" -r"
#fi
if [ ! -z "$SUMMARY_XLS_OAF_RATIO" ]; then
    cmd+=" -A $SUMMARY_XLS_OAF_RATIO"
fi
if [ ! -z "$SUMMARY_XLS_MAF_RATIO" ]; then
    cmd+=" -F $SUMMARY_XLS_MAF_RATIO"
fi
eval $cmd
