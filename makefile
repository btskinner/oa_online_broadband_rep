################################################################################
#
# [ PROJ ] Open access broadband
# [ FILE ] makefile
# [ AUTH ] Benjamin Skinner; @btskinner (GitHub; Twitter); btskinner.me
# [ CITE ]
#
#  Skinner, B.T. (2019). Making the connection: broadband access and online
#    course enrollment at public open admissions institutions. Research in
#    Higher Education, 1-40. DOI: 10.1007/s11162-018-9539-6      
#
################################################################################

# --- settings -----------------------------------

# set to https or ssh (probably https for most)
git_type := ssh

# cores
cores := 8

# --- directories --------------------------------

# data 
DATA_DIR := data
ADATA_DIR := $(DATA_DIR)/acs
BDATA_DIR := $(DATA_DIR)/broadband
NBM_ZIP_DIR := $(BDATA_DIR)/zip
CDATA_DIR := $(DATA_DIR)/cleaned
GDATA_DIR := $(DATA_DIR)/geo
IDATA_DIR := $(DATA_DIR)/ipeds
SDATA_DIR := $(DATA_DIR)/sheeo

# scripts
SCRIPT_DIR := scripts
BASH_DIR := $(SCRIPT_DIR)/bash
CMDSTAN_DIR := $(SCRIPT_DIR)/cmdstan
STAN_DIR := $(SCRIPT_DIR)/stan
R_DIR := $(SCRIPT_DIR)/r

# model output
OUT_DIR := output
PWD := $(shell pwd)

# table/figures
TABLE_DIR := tables
FIGURE_DIR := figures

# stan repo
ifneq ($(git_type), ssh)
	CMDSTAN_GIT := git@github.com:stan-dev/cmdstan.git
else
	CMDSTAN_GIT := https://github.com/stan-dev/cmdstan.git
endif

# --- build targets ------------------------------

all: cmdstan rpkgs data stanfiles analysis output

stanfiles: $(patsubst %.stan, %, $(wildcard $(STAN_DIR)/*.stan))

SL_SAMPLES := $(OUT_DIR)/sl_normal_full_pdw2_download_1.csv
SL_SAMPLES += $(OUT_DIR)/sl_beta_full_pdw2_download_1.csv
VI_SAMPLES := $(OUT_DIR)/vi_normal_full_pdw2_download_1.csv
VI_SAMPLES += $(OUT_DIR)/vi_beta_full_pdw2_download_1.csv
core-analysis: $(SL_SAMPLES) $(VI_SAMPLES)

SL_SAMPLES_S := $(OUT_DIR)/sl_normal_sens_pdw2_download_1.csv
SL_SAMPLES_S += $(OUT_DIR)/sl_beta_sens_pdw2_download_1.csv
VI_SAMPLES_S := $(OUT_DIR)/vi_normal_sens_pdw2_download_1.csv
VI_SAMPLES_S += $(OUT_DIR)/vi_beta_sens_pdw2_download_1.csv
sens-analysis: $(SL_SAMPLES_S) $(VI_SAMPLES_S) $(VS_SAMPLES_S)

analysis: core-analysis sens-analysis

broadband-data: $(BDATA_DIR)/bb.db

analysis-data: $(addprefix $(CDATA_DIR)/,$(addsuffix .csv,scbb analysis_oap ipeds))

data: get-data broadband-data analysis-data

output: $(TABLE_DIR)/table_figures.pdf

ifndef VERBOSE
.SILENT:
endif

.PHONY: all cmdstan stanfiles data analysis-data broadband-data get-data
.PHONY: analysis core-analysis sens-analysis rpkgs output

# --- Stan ---------------------------------------

# get cmdstan and build
cmdstan:
ifneq ($(wildcard $(CMDSTAN_DIR)/.),)
	@echo "Cmdstan already exists"
	@echo "Checking out CmdStan and building"
	(cd $(CMDSTAN_DIR) && make build -j$(cores) --silent)
else
	@echo "Cloning CmdStan"
	@echo "Checking out CmdStan and building"
	git clone $(CMDSTAN_GIT) $(CMDSTAN_DIR) --recursive -q
	(cd $(CMDSTAN_DIR) && make build -j$(cores) --silent)
endif

# compile stan files
$(STAN_DIR)/%: $(STAN_DIR)/%.stan
	@echo "Compiling Stan scripts"
	(cd $(CMDSTAN_DIR) && make $(PWD)/$(basename $<))

# --- R packages ---------------------------------

# get R packages
rpkgs:
	@echo "Getting required R packages"
	Rscript $(R_DIR)/get_packages.R

# --- Data ---------------------------------------

# get data
get-data: 
	@echo "Downloading raw data files"
	Rscript $(R_DIR)/get_data.R $(R_DIR) $(DATA_DIR)

# final analysis dataset
ANALYSIS_DATA_DEPS := $(CDATA_DIR)/ipeds.csv $(CDATA_DIR)/scbb.csv
ANALYSIS_DATA_DEPS += $(R_DIR)/clean_data.R
$(CDATA_DIR)/analysis_oap.csv: $(ANALYSIS_DATA_DEPS)
	Rscript $(R_DIR)/clean_data.R $(R_DIR) $(DATA_DIR)

# measures of broadband access for each school
SCBB_DATA_DEPS := $(R_DIR)/clean_bb.R $(CDATA_DIR)/ipeds.csv
SCBB_DATA_DEPS += $(BDATA_DIR)/bb.db
$(CDATA_DIR)/scbb.csv: $(SCBB_DATA_DEPS)
	@echo "Cleaning broadband data"
	Rscript $(R_DIR)/clean_bb.R $(R_DIR) $(DATA_DIR)

# IPEDS dataset
$(CDATA_DIR)/ipeds.csv: $(R_DIR)/clean_ipeds.R
	@echo "Cleaning IPEDS data"
	Rscript $(R_DIR)/clean_ipeds.R $(R_DIR) $(DATA_DIR)

# National Broadband Map CSV (ZIP) files to SQLite DB
BB_DB_DEPS := $(addprefix $(BASH_DIR)/, \
	$(addsuffix .sh, make_bb bb_db_clean bb_table_clean bb_table_create))

# build broadband database
$(BDATA_DIR)/bb.db: $(BB_DB_DEPS)
	@echo "Building broadband database from flat files"
	$(BASH_DIR)/make_bb.sh $(NBM_ZIP_DIR) $(BDATA_DIR) $(BASH_DIR)

# --- Main Analysis ------------------------------

# single-level
$(OUT_DIR)/sl_normal_full_pdw2_download_1.csv: $(STAN_DIR)/sl_normal
	mkdir -p $(OUT_DIR)
	@echo "Running single-level normal models"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_normal full $(OUT_DIR) both $(R_DIR)

# varying-intercept
$(OUT_DIR)/vi_normal_full_pdw2_download_1.csv: $(STAN_DIR)/vi_normal
	mkdir -p $(OUT_DIR)	
	@echo "Running varying-intercept normal models"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_normal full $(OUT_DIR) both $(R_DIR)

# --- Appendix A ---------------------------------

# single-level
$(OUT_DIR)/sl_beta_full_pdw2_download_1.csv: $(STAN_DIR)/sl_beta
	mkdir -p $(OUT_DIR)
	@echo "Running single-level beta models for appendix A"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_beta full $(OUT_DIR) both $(R_DIR)

# varying-intercept
$(OUT_DIR)/vi_beta_full_pdw2_download_1.csv: $(STAN_DIR)/vi_beta
	mkdir -p $(OUT_DIR)
	@echo "Running varying-intercept beta models for appendix A"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_beta full $(OUT_DIR) both $(R_DIR)

# --- Sensitivity analysis -----------------------

# Single level ----------

# normal
$(OUT_DIR)/sl_normal_sens_pdw2_download_1.csv: $(STAN_DIR)/sl_normal
	mkdir -p $(OUT_DIR)
	@echo "Running single-level normal models for appendix B"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_normal sens $(OUT_DIR) both $(R_DIR)

# beta
$(OUT_DIR)/sl_beta_sens_pdw2_download_1.csv: $(STAN_DIR)/sl_beta
	mkdir -p $(OUT_DIR)
	@echo "Running single-level beta models for appendix B"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) sl_beta sens $(OUT_DIR) both $(R_DIR)

# Varying intercept -----

# normal
$(OUT_DIR)/vi_normal_sens_pdw2_download_1.csv: $(STAN_DIR)/vi_normal
	mkdir -p $(OUT_DIR)
	@echo "Running varying-intercept normal models for appendix B"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_normal sens $(OUT_DIR) both $(R_DIR)

# beta
$(OUT_DIR)/vi_beta_sens_pdw2_download_1.csv: $(STAN_DIR)/vi_beta	
	mkdir -p $(OUT_DIR)
	@echo "Running varying-intercept beta models for appendix B"
	$(BASH_DIR)/run_stan.sh $< $(CDATA_DIR) vi_beta sens $(OUT_DIR) both $(R_DIR)

# --- Figures / Tables ---------------------------

$(TABLE_DIR)/%.tex: $(TABLE_DIR)/%.Rnw 
	@echo "Making figures"
	Rscript $(R_DIR)/make_figures.R $(R_DIR) $(DATA_DIR) $(FIGURE_DIR) $(OUT_DIR)
	@echo "Making tables / figure document"
	Rscript -e "knitr::knit('$<','$@')"

$(TABLE_DIR)/%.pdf: $(TABLE_DIR)/%.tex
	@echo "Compiling TeX document"
	latexmk -pdf $<
	$(RM) *.aux *.fdb_latexmk *.fls *.lof *.log *.lot *.out

# --- Clean --------------------------------------

clean:
	@echo "Returning repo to initial state, removing all new files"
	$(RM) -r $(BUILDDIR) $(TARGETDIR)
	$(RM) -r $(ADATA_DIR)/co-est2015-alldata.csv
	$(RM) -r $(BDATA_DIR) $(CDATA_DIR) $(GDATA_DIR) $(IDATA_DIR) $(SDATA_DIR)
	$(RM) -r $(CMDSTAN_DIR)
	$(RM) -r $(OUT_DIR)
	# hack to save .stan scripts while removing all else
	@mkdir -p $(SCRIPT_DIR)/tmp
	@mv $(STAN_DIR)/*.stan $(SCRIPT_DIR)/tmp
	$(RM) -r $(STAN_DIR)
	@mkdir -p $(STAN_DIR)
	@mv $(SCRIPT_DIR)/tmp/* $(STAN_DIR)
	$(RM) -r $(SCRIPT_DIR)/tmp
	$(RM) $(TABLE_DIR)/*.tex $(TABLE_DIR)/tex
	$(RM) $(FIGURE_DIR)/*.pdf
	$(RM) table_figures.*


