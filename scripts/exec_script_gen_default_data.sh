#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

cmd="$SCRIPT_GEN_DEFAULT_DATA -p $DEFAULT_DATA_PROJECT_CODE -N $DEFAULT_DATA_DATASET_NAME -t $DEFAULT_DATA_TABIX_FILE -w $DEFAULT_DATA_WORKING_DIR -l $DEFAULT_DATA_LOG_DIR -H $DEFAULT_DATA_HBVDB_TOOLS_ROOT_DIR -A $DEFAULT_DATA_ANNOVAR_ROOT_DIR"
if [ ! -z "$DEFAULT_DATA_OAF_OUT_FILE" ]; then
    cmd+=" -O $DEFAULT_DATA_OAF_OUT_FILE"
fi
if [ ! -z "$DEFAULT_DATA_GT_VCF_GT_OUT_FILE" ]; then
    cmd+=" -G $DEFAULT_DATA_GT_VCF_GT_OUT_FILE"
fi
if [ ! -z "$DEFAULT_DATA_MT_VCF_GT_OUT_FILE" ]; then
    cmd+=" -M $DEFAULT_DATA_MT_VCF_GT_OUT_FILE"
fi
if [ ! -z "$DEFAULT_DATA_SA_OUT_FILE" ]; then
    cmd+=" -S $DEFAULT_DATA_SA_OUT_FILE"
fi

if [ ! -z "$DEFAULT_DATA_VCF_REGION" ]; then
    cmd+=" -R $DEFAULT_DATA_VCF_REGION"
fi
if [ ! -z "$DEFAULT_DATA_COL_NAMES" ]; then
    cmd+=" -c $DEFAULT_DATA_COL_NAMES"
fi
echo "$cmd"
eval $cmd
