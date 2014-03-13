#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

cmd="$SCRIPT_GEN_FAMILY_XLS -k $FAMILY_XLS_RUNNING_KEY -O $FAMILY_XLS_OAF_IN_FILE -S $FAMILY_XLS_SA_IN_FILE -M $FAMILY_XLS_MT_VCF_GT_IN_FILE -w $FAMILY_XLS_WORKING_DIR -o $FAMILY_XLS_OUT_DIR -f $FAMILY_XLS_FAMILY_CODE -m $FAMILY_XLS_MEMBER_LIST"
if [ ! -z "$FAMILY_XLS_VCF_REGION" ]; then
    cmd+=" -R $FAMILY_XLS_VCF_REGION"
fi
if [ ! -z "$FAMILY_XLS_OAF_RATIO" ]; then
    cmd+=" -A $FAMILY_XLS_OAF_RATIO"
fi
if [ ! -z "$FAMILY_XLS_MAF_RATIO" ]; then
    cmd+=" -F $FAMILY_XLS_MAF_RATIO"
fi
eval $cmd
