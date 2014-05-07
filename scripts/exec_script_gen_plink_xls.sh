#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

cmd="$SCRIPT_GEN_PLINK_XLS -p $PLINK_XLS_PROJECT_CODE -k $PLINK_XLS_RUNNING_KEY -b $PLINK_XLS_PLINK_BIN_FILE_PREFIX -w $PLINK_XLS_WORKING_DIR -o $PLINK_XLS_OUT_DIR -l $PLINK_XLS_LOG_DIR"

if [ ! -z "$PLINK_XLS_PLINK_PHENO_FILE" ]; then
    cmd+=" -P $PLINK_XLS_PLINK_PHENO_FILE"
fi
if [ ! -z "$PLINK_XLS_PLINK_REGION" ]; then
    cmd+=" -R $PLINK_XLS_PLINK_REGION"
fi

eval $cmd
