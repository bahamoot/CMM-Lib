#!/bin/bash

source /glob/jessada/lib/CMM-Lib/scripts/export_script_var.sh

cmd="$SCRIPT_CAL_MUTATIONS_STAT -k $MUTATIONS_STAT_RUNNING_KEY -w $MUTATIONS_STAT_WORKING_DIR -t $MUTATIONS_STAT_TABIX_FILE"
if [ ! -z "$MUTATIONS_STAT_OUT_DIR" ]; then
    cmd+=" -o $MUTATIONS_STAT_OUT_DIR"
fi
if [ ! -z "$MUTATIONS_STAT_VCF_REGION" ]; then
    cmd+=" -R $MUTATIONS_STAT_VCF_REGION"
fi
if [ ! -z "$MUTATIONS_STAT_COL_NAMES" ]; then
    cmd+=" -c $MUTATIONS_STAT_COL_NAMES"
fi
#if [ "$MUTATIONS_STAT_CAL_ALLELIC_FREQUENCY" = "On" ]; then
#    cmd+=" -a"
#fi
#if [ "$MUTATIONS_STAT_CAL_GENOTYPED_FREQUENCY" = "On" ]; then
#    cmd+=" -g"
#fi
eval $cmd
