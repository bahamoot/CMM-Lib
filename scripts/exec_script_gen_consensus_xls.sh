#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

cmd="$SCRIPT_GEN_CONSENSUS_XLS -k $CONSENSUS_XLS_RUNNING_KEY -O $CONSENSUS_XLS_OAF_IN_FILE -S $CONSENSUS_XLS_SA_IN_FILE -w $CONSENSUS_XLS_WORKING_DIR -o $CONSENSUS_XLS_OUT_DIR"
if [ ! -z "$CONSENSUS_XLS_GT_VCF_GT_IN_FILE" ]; then
    cmd+=" -G $CONSENSUS_XLS_GT_VCF_GT_IN_FILE"
fi
if [ ! -z "$CONSENSUS_XLS_MT_VCF_GT_IN_FILE" ]; then
    cmd+=" -M $CONSENSUS_XLS_MT_VCF_GT_IN_FILE"
fi
if [ ! -z "$CONSENSUS_XLS_VCF_REGION" ]; then
    cmd+=" -R $CONSENSUS_XLS_VCF_REGION"
fi
if [ ! -z "$CONSENSUS_XLS_OAF_RATIO" ]; then
    cmd+=" -A $CONSENSUS_XLS_OAF_RATIO"
fi
if [ ! -z "$CONSENSUS_XLS_MAF_RATIO" ]; then
    cmd+=" -F $CONSENSUS_XLS_MAF_RATIO"
fi
echo "$cmd"
eval $cmd
