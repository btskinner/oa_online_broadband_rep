################################################################################
##
## [ PROJ ] Open access broadband
## [ FILE ] get_data.R
## [ AUTH ] Benjamin Skinner: @btskinner
## [ INIT ] 1 January 2019
##
################################################################################

## command line arguments
args <- commandArgs(trailingOnly = TRUE)

## read in utility functions
source(paste0(args[1],'/utils.R'))

## directories
ddir <- args[2]
adir <- file.path(ddir, 'acs')
bdir <- file.path(ddir, 'broadband')
cdir <- file.path(ddir, 'cleaned')
idir <- file.path(ddir, 'ipeds')
gdir <- file.path(ddir, 'geo')
sdir <- file.path(ddir, 'sheeo')

## -----------------
## create subdirs
## -----------------

dirs <- c(adir, bdir, cdir, idir, gdir, sdir)
for (d in dirs) { dir.create(d, showWarnings = FALSE) }

## -----------------
## ./acs
## -----------------

## employment data: state
file <- 'ACS_14_5YR_S2301_state.csv'
url <- 'https://factfinder.census.gov/bkmk/table/1.0/en/ACS/14_5YR/' %+%
    'S2301/0100000US.04000'
check_get(file, adir, url)

## employment data: county
file <- 'ACS_14_5YR_S2301_county.csv'
url <- 'https://factfinder.census.gov/bkmk/table/1.0/en/ACS/14_5YR/' %+%
    'S2301/0100000US.05000.003'
check_get(file, adir, url)

## population
file <- 'co-est2015-alldata.csv'
url <- 'https://www2.census.gov/programs-surveys/popest/datasets/' %+%
    '2010-2015/counties/totals/' %+% file
check_get(file, adir, url)

## -----------------
## ./broadband
## -----------------

## National Broadband Map
nbm_base_url <- 'https://www2.ntia.doc.gov/files/broadband-data/'
years <- 2012:2014
for (yr in years) {
    file <- 'All-NBM-CSV-June-' %+% yr %+% '.zip'
    url <- nbm_base_url %+% file
    check_get(file, file.path(bdir, 'zip'), url)
}

## -----------------
## ./geo
## -----------------

## spatial data url
git_geo <- 'https://raw.githubusercontent.com/btskinner/spatial/master/data/'

## county centers
file <- 'county_centers.csv'
url <- git_geo %+% file
check_get(file, gdir, url)

## neighboring counties
file <- 'neighborcounties.csv'
url <- git_geo %+% file
check_get(file, gdir, url)

## population centers
file <- 'CenPop2010_Mean_BG.txt'
url <- 'http://www2.census.gov/geo/docs/reference/cenpop2010/blkgrp/' %+% file
check_get(file, gdir, url)

## RUCC
file <- 'ruralurbancodes2013.xls'
url <- 'https://www.ers.usda.gov/webdocs/DataFiles/53251/' %+% file
check_get(file, gdir, url)

## land area
file <- 'LND01.xls'
url <- 'http://www2.census.gov/prod2/statcomp/usac/excel/' %+% file
check_get(file, gdir, url)

## -----------------
## ./ipeds
## -----------------

source('./downloadipeds.R')

## -----------------
## ./sheeo
## -----------------

file <- 'State_by_State_Wave_Charts_FY15_0.xlsx'
url <- 'www.sheeo.org/sites/default/files/' %+% file
check_get(file, sdir, url)

## -----------------------------------------------------------------------------
## END SCRIPT
################################################################################
