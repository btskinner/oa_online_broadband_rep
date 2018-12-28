################################################################################
#
# [ PROJ ] Open access broadband
# [ FILE ] makefile
# [ AUTH ] Benjamin Skinner; @btskinner (GitHub; Twitter); btskinner.me
# [ CITE ]
#
#  Skinner, B. (2019). Making the connection: broadband access and online
#    course enrollment at public open admissions institutions. Research in
#    Higher Education.       
#
################################################################################

# --- settings -----------------------------------

# set to https or ssh
git_type := ssh

# cores
cores := 8

# stan version
stanver := 2.18.0

# --- directories --------------------------------

# data 
DATA_DIR := data
CDATA_DIR := $(DATA_DIR)/cleaned
GDATA_DIR := $(DATA_DIR)/geo
BDATA_DIR := $(DATA_DIR)/broadband
NBM_ZIP_DIR := $(BDATA_DIR)/zip

# scripts
SCRIPT_DIR := scripts
BASH_DIR := $(SCRIPT_DIR)/bash
CMDSTAN_DIR := $(SCRIPT_DIR)/cmdstan
STAN_DIR := $(SCRIPT_DIR)/stan
R_DIR := $(SCRIPT_DIR)/r

# model output
OUT_DIR := output
PWD := $(shell pwd)

# stan repo
ifneq ($(git_type), ssh)
	CMDSTAN_GIT := git@github.com:stan-dev/cmdstan.git
else
	CMDSTAN_GIT := https://github.com/stan-dev/cmdstan.git
endif

# --- build targets ------------------------------

.PHONY: all cmdstan stanfiles data analysis-data broadband-data
.PHONY: analysis core-analysis sens-analysis

all: cmdstan data stanfiles analysis

SL_SAMPLES := $(OUT_DIR)/sl_normal_full_pdw2_download_1.csv
SL_SAMPLES += $(OUT_DIR)/sl_beta_full_pdw2_download_1.csv
VI_SAMPLES := $(OUT_DIR)/vi_normal_full_pdw2_download_1.csv
VI_SAMPLES += $(OUT_DIR)/vi_beta_full_pdw2_download_1.csv
core-analysis: $(SL_SAMPLES) $(VI_SAMPLES) # $(VS_SAMPLES_1) $(VS_SAMPLES_2)

SL_SAMPLES_S := $(OUT_DIR)/sl_normal_sens_pdw2_download_1.csv
SL_SAMPLES_S += $(OUT_DIR)/sl_beta_sens_pdw2_download_1.csv
VI_SAMPLES_S := $(OUT_DIR)/vi_normal_sens_pdw2_download_1.csv
VI_SAMPLES_S += $(OUT_DIR)/vi_beta_sens_pdw2_download_1.csv
sens-analysis: $(SL_SAMPLES_S) $(VI_SAMPLES_S) $(VS_SAMPLES_S)

analysis: core-analysis sens-analysis

broadband-data: $(BDATA_DIR)/bb.db

analysis-data: $(addprefix $(CDATA_DIR)/,$(addsuffix .csv,scbb analysis_oap ipeds))

data: broadband-data analysis-data

stanfiles: $(patsubst %.stan, %, $(wildcard $(STAN_DIR)/*.stan))

# --- Stan ---------------------------------------

# get cmdstan and build
cmdstan:
ifneq ($(wildcard $(CMDSTAN_DIR)/.),)
	@echo "Cmdstan already exists"
	@echo "Checking out CmdStan version $(stanver) and building"
	(cd $(CMDSTAN_DIR) && make build -j$(cores))
else
	@echo "Cloning CmdStan"
	@echo "checking out CmdStan version $(stanver) and building"
	git clone $(CMDSTAN_GIT) $(CMDSTAN_DIR) --recursive
	(cd $(CMDSTAN_DIR) && make build -j$(cores))
endif

# compile stan files
$(STAN_DIR)/%: $(STAN_DIR)/%.stan
	@echo "Compiling Stan scripts"
	(cd $(CMDSTAN_DIR) && make $(PWD)/$(basename $<))

# --- Data ---------------------------------------

# final analysis dataset
ANALYSIS_DATA_DEPS := $(CDATA_DIR)/ipeds.csv $(CDATA_DIR)/scbb.csv
ANALYSIS_DATA_DEPS += $(R_DIR)/clean_data.R
$(CDATA_DIR)/analysis_oap.csv: $(ANALYSIS_DATA_DEPS)
	Rscript $(R_DIR)/clean_data.R $(R_DIR) $(DATA_DIR)

# measures of broadband access for each school
SCBB_DATA_DEPS := $(R_DIR)/clean_bb.R $(CDATA_DIR)/ipeds.csv
SCBB_DATA_DEPS += $(BDATA_DIR)/bb.db
$(CDATA_DIR)/scbb.csv: $(SCBB_DATA_DEPS)
	Rscript $(R_DIR)/clean_bb.R $(R_DIR) $(DATA_DIR)

# IPEDS dataset
$(CDATA_DIR)/ipeds.csv: $(R_DIR)/clean_ipeds.R
	Rscript $(R_DIR)/clean_ipeds.R $(R_DIR) $(DATA_DIR)

# National Broadband Map CSV (ZIP) files to SQLite DB
BB_DB_DEPS := $(addprefix $(BASH_DIR)/, \
	$(addsuffix .sh, make_bb bb_db_clean bb_table_clean bb_table_create))

$(BDATA_DIR)/bb.db: $(BB_DB_DEPS)
	$(BASH_DIR)/make_bb.sh $(NBM_ZIP_DIR) $(BDATA_DIR) $(BASH_DIR)

# --- Analysis -----------------------------------

# Single level ----------

# beta
$(OUT_DIR)/sl_beta_full_pdw2_download_1.csv: $(STAN_DIR)/sl_beta
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_beta full $(OUT_DIR) both $(R_DIR)

# normal
$(OUT_DIR)/sl_normal_full_pdw2_download_1.csv: $(STAN_DIR)/sl_normal
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_normal full $(OUT_DIR) both $(R_DIR)

# Varying intercept -----

# beta
$(OUT_DIR)/vi_beta_full_pdw2_download_1.csv: $(STAN_DIR)/vi_beta
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_beta full $(OUT_DIR) both $(R_DIR)

# normal
$(OUT_DIR)/vi_normal_full_pdw2_download_1.csv: $(STAN_DIR)/vi_normal
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_normal full $(OUT_DIR) both $(R_DIR)


# --- Sensitivity analysis -----------------------

# Single level ----------

# beta
$(OUT_DIR)/sl_beta_sens_pdw2_download_1.csv: $(STAN_DIR)/sl_beta
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_beta sens $(OUT_DIR) both $(R_DIR)

# normal
$(OUT_DIR)/sl_normal_sens_pdw2_download_1.csv: $(STAN_DIR)/sl_normal
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_normal sens $(OUT_DIR) both $(R_DIR)

# Varying intercept -----

# beta
$(OUT_DIR)/vi_beta_sens_pdw2_download_1.csv: $(STAN_DIR)/vi_beta
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_beta sens $(OUT_DIR) both $(R_DIR)

# normal
$(OUT_DIR)/vi_normal_sens_pdw2_download_1.csv: $(STAN_DIR)/vi_normal
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_normal sens $(OUT_DIR) both $(R_DIR)

# --- CLEAN --------------------------------------

clean:
	$(RM) -r $(BUILDDIR) $(TARGETDIR)


