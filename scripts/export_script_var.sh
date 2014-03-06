#!/bin/bash

#export HOME_GLOB=/glob/jessada/
#export CMM_PROJECTS_ROOT_DIR=$HOME_GLOB/private/projects/CMM
#
#export CMM_PROJECTS_OUTPUT_DIR=$CMM_PROJECTS_ROOT_DIR/out
#export CMM_PROJECTS_LOG_DIR=$CMM_PROJECTS_ROOT_DIR/log
#export CMM_PROJECTS_WORKING_DIR=$CMM_PROJECTS_ROOT_DIR/tmp
#
##********************************************* set path *****************************************************
export LIB_SCRIPT_DIR=$HOME_GLOB/lib/CMM-Lib/scripts
#export SCRIPT_GEN_OAF=$LIB_SCRIPT_DIR/script_gen_oaf.sh
#export SCRIPT_GEN_SA=$LIB_SCRIPT_DIR/script_gen_sa.sh
#export SCRIPT_GEN_VCF_GT=$LIB_SCRIPT_DIR/script_gen_vcf_gt.sh
#export SCRIPT_GEN_GT=$LIB_SCRIPT_DIR/script_gen_gt.sh
#export SCRIPT_GEN_XLS=$LIB_SCRIPT_DIR/script_gen_xls.sh
export SCRIPT_GEN_DEFAULT_DATA=$LIB_SCRIPT_DIR/script_gen_default_data.sh
#export EXEC_SCRIPT_GEN_DEFAULT_DATA=$LIB_SCRIPT_DIR/exec_script_gen_default_data.sh
export SCRIPT_GEN_CONSENSUS_XLS=$LIB_SCRIPT_DIR/script_gen_consensus_xls.sh
#export EXEC_SCRIPT_GEN_CONSENSUS_XLS=$LIB_SCRIPT_DIR/exec_script_gen_consensus_xls.sh
export CSVS2XLS=$LIB_SCRIPT_DIR/csvs2xls.py
#export SORT_N_AWK_CSV=$LIB_SCRIPT_DIR/sort_n_awk_csv.sh
#
###********************************************* data location *****************************************************
##set global master data location
#export CMM_MASTER_DATA_ROOT_DIR=$HOME_GLOB/private/master_data/CMM
#
##set CMM shared data location
##hbvdb
#export HBVDB_ROOT_DIR=$CMM_MASTER_DATA_ROOT_DIR/hbvdb/
##export CMM_HBVDB_UPPSALA_ALL_FAM=$HBVDB_ROOT_DIR/uppsala_all_fam
##export CMM_HBVDB_UPPSALA_REALIGNED_ALL_50FAM=$HBVDB_ROOT_DIR/uppsala_realigned_all_50fam
##export CMM_HBVDB_SCILIFE_ILLUMINA_ALL_FAM=$HBVDB_ROOT_DIR/scilife_illumina_all_fam
##export CMM_HBVDB_AXEQ_CHR9_ALL_FAM=$HBVDB_ROOT_DIR/axeq_chr9_all_fam
##OAF
#export OAF_ROOT_DIR=$CMM_MASTER_DATA_ROOT_DIR/oaf/
#export CMM_OAF_UPPSALA_ALL_FAM=$OAF_ROOT_DIR/uppsala_all_fam.oaf
#export CMM_OAF_UPPSALA_REALIGNED_ALL_50FAM=$OAF_ROOT_DIR/uppsala_realigned_all_50fam.oaf
#export CMM_OAF_SCILIFE_ILLUMINA_ALL_FAM=$OAF_ROOT_DIR/scilife_illumina_all_fam.oaf
#export CMM_OAF_AXEQ_CHR9_ALL_FAM=$OAF_ROOT_DIR/axeq_chr9_all_fam.oaf
##Genotype data
#export GT_ROOT_DIR=$CMM_MASTER_DATA_ROOT_DIR/gt/
#export CMM_GT_BFILE_PREFIX_WITHOUT_RELATIVES=$GT_ROOT_DIR/without_relatives/AL5cnc_common
##export CMM_GT_UPPSALA_REALIGNED_50FAM=$OAF_ROOT_DIR/uppsala_realigned_50fam.gt
##VCF
#export CMM_UPPSALA_SEQUENCE_ROOT_DIR=$CMM_MASTER_DATA_ROOT_DIR/CMM_Uppsala_b2011117
#export CMM_UPPSALA_ALL_PATIENTS_BWA_GATK_GZ=$CMM_UPPSALA_SEQUENCE_ROOT_DIR/systematic/Uppsala_bwa_GATK/bwa_GATK.vcf.gz
#export CMM_UPPSALA_ALL_PATIENTS_BWA_GATK_HEADER=$CMM_UPPSALA_SEQUENCE_ROOT_DIR/systematic/Uppsala_bwa_GATK/bwa_GATK_header.vcf
#export CMM_UPPSALA_50FAM_ALL_PATIENTS_GZ=$CMM_UPPSALA_SEQUENCE_ROOT_DIR/systematic/Uppsala_realigned_50_families/vcf/merged/Uppsala_realigned_50_families.vcf.gz
#export CMM_UPPSALA_50FAM_ALL_PATIENTS_HEADER=$CMM_UPPSALA_SEQUENCE_ROOT_DIR/systematic/Uppsala_realigned_50_families/vcf/merged/Uppsala_realigned_50_families_header.vcf
#export CMM_SCILIFE_ILLUMINA_SEQUENCE_ROOT_DIR=$CMM_MASTER_DATA_ROOT_DIR/CMM_Scilife_b2011158/
#export CMM_SCILIFE_ILLUMINA_ALL_PATIENTS_MANS_GZ=$CMM_SCILIFE_ILLUMINA_SEQUENCE_ROOT_DIR/systematic/mans/merged/scilife_illumina_mans.vcf.gz
#export CMM_SCILIFE_ILLUMINA_ALL_PATIENTS_MANS_HEADER=$CMM_SCILIFE_ILLUMINA_SEQUENCE_ROOT_DIR/systematic/mans/merged/scilife_illumina_mans_header.vcf
#export CMM_SCILIFE_ILLUMINA_ALL_PATIENTS_UPPSALA_GZ=$CMM_SCILIFE_ILLUMINA_SEQUENCE_ROOT_DIR/systematic/uppsala/merged/scilife_illumina_uppsala.vcf.gz
#export CMM_AXEQ_SEQUENCE_ROOT_DIR=$CMM_MASTER_DATA_ROOT_DIR/CMM_Axeq_b2012247/
#export CMM_AXEQ_CHR9_ALL_PATIENTS_GZ=$CMM_AXEQ_SEQUENCE_ROOT_DIR/systematic/chr9/merged/Axeq_chr9.vcf.gz
#export CMM_AXEQ_CHR9_ALL_PATIENTS_HEADER=$CMM_AXEQ_SEQUENCE_ROOT_DIR/systematic/chr9/merged/Axeq_chr9_header.vcf
#export CMM_AXEQ_CHR9_FOLDER=$CMM_AXEQ_SEQUENCE_ROOT_DIR/systematic/chr9/vcf/
#export CMM_AXEQ_CHR5_19_FOLDER=$CMM_AXEQ_SEQUENCE_ROOT_DIR/systematic/chr5_19/vcf/
#export CMM_AXEQ_CHR3_6_14_18_FOLDER=$CMM_AXEQ_SEQUENCE_ROOT_DIR/systematic/chr3_6_14_18/vcf/
#export CMM_SCILIFE_CAPTURE_ROOT_DIR=$CMM_MASTER_DATA_ROOT_DIR/CMM_Scilife_b2011097/
#export CMM_SCILIFE_CAPTURE_FAM24_PATIENTS_GZ=$CMM_SCILIFE_CAPTURE_ROOT_DIR/systematic/capture/merged/Scilife_capture_Co166_213.vcf.gz
##VCF Genotyping data
#export VCF_GT_OUT_DIR=$CMM_MASTER_DATA_ROOT_DIR/vcf_gt/
#export CMM_UPPSALA_50FAM_GENOTYPED_VCF_GT=$VCF_GT_OUT_DIR/uppsala_50fam_genotyped_gt.vgt
#export CMM_UPPSALA_50FAM_MUTATED_VCF_GT=$VCF_GT_OUT_DIR/uppsala_50fam_mutated_gt.vgt
#export CMM_SCILIFE_ILLUMINA_GENOTYPED_VCF_GT=$VCF_GT_OUT_DIR/scilife_illumina_genotyped_gt.vgt
#export CMM_SCILIFE_ILLUMINA_MUTATED_VCF_GT=$VCF_GT_OUT_DIR/scilife_illumina_mutated_gt.vgt
#export CMM_AXEQ_CHR9_GENOTYPED_VCF_GT=$VCF_GT_OUT_DIR/axeq_chr9_genotyped_gt.vgt
#export CMM_AXEQ_CHR9_MUTATED_VCF_GT=$VCF_GT_OUT_DIR/axeq_chr9_mutated_gt.vgt
##summarize_annovar
#export SUMMARIZE_ANNOVAR_OUT_DIR=$CMM_MASTER_DATA_ROOT_DIR/summarize_annovar/
#export CMM_SCILIFE_ILLUMINA_MANS_SA_DB=$SUMMARIZE_ANNOVAR_OUT_DIR/scilife_illumina_mans.tab.csv
#export CMM_SCILIFE_ILLUMINA_UPPSALA_SA_DB=$SUMMARIZE_ANNOVAR_OUT_DIR/scilife_illumina_uppsala.tab.csv
#export CMM_UPPSALA_SA_DB=$SUMMARIZE_ANNOVAR_OUT_DIR/uppsala.tab.csv
#export CMM_UPPSALA_REALIGNED_50FAM_SA_DB=$SUMMARIZE_ANNOVAR_OUT_DIR/uppsala_realigned_50fam.tab.csv
#export CMM_AXEQ_CHR9_SA_DB=$SUMMARIZE_ANNOVAR_OUT_DIR/axeq_chr9.tab.csv
#export CMM_SCILIFE_CAPTURE_FAM24_SA_DB=$SUMMARIZE_ANNOVAR_OUT_DIR/scilife_capture_Co166_213.tab.csv
#
#
#
###********************************************* tools/scripts location *****************************************************
##set third-party tools location
#export TOOLS_ROOT_DIR=$HOME_GLOB/tools/
##set active hbvdb location
#export HBVDB_TOOLS_ROOT_DIR=$TOOLS_ROOT_DIR/hbvdb
#export HBVDB_BVD_GET=$HBVDB_TOOLS_ROOT_DIR/bin/bvd-get.pl
#export HBVDB_BVD_ADD=$HBVDB_TOOLS_ROOT_DIR/bin/bvd-add.pl
#
##ANNOVAR
#export ANNOVAR_ROOT_DIR=$TOOLS_ROOT_DIR/annovar
#export ANNOVAR_HUMAN_DB_DIR=$ANNOVAR_ROOT_DIR/humandb
#export CONVERT2ANNOVAR=$ANNOVAR_ROOT_DIR/convert2annovar.pl
#export SUMMARIZE_ANNOVAR=$ANNOVAR_ROOT_DIR/summarize_annovar.pl
