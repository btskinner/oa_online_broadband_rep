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
## args[1] <- <path>/<to>/scripts/r
## args[2] <- <path>/<to>/data
source(file.path(args[1], '/utils.R'))

## directories
ddir <- args[2]
adir <- file.path(ddir, 'acs')
bdir <- file.path(ddir, 'broadband', 'zip')
cdir <- file.path(ddir, 'cleaned')
idir <- file.path(ddir, 'ipeds')
gdir <- file.path(ddir, 'geo')
sdir <- file.path(ddir, 'sheeo')

## -----------------
## create subdirs
## -----------------

dirs <- c(bdir, cdir, idir, gdir, sdir) # adir already exists
for (d in dirs) { dir.create(d, showWarnings = FALSE, recursive = TRUE) }

## -----------------
## ./acs
## -----------------

## population
file <- 'co-est2015-alldata.csv'
url <- 'http://www2.census.gov/programs-surveys/popest/datasets/' %+%
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
    check_get(file, bdir, url, mode = 'wb')
}

## -----------------
## ./geo
## -----------------

## spatial data url
git_geo <- 'https://raw.githubusercontent.com/btskinner/spatial/master/data/'

## stcrossalk
file <- 'stcrosswalk.csv'
url <- git_geo %+% file
check_get(file, gdir, url)

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
check_get(file, gdir, url, mode = 'wb')

## land area
file <- 'LND.zip'
url <- 'http://www2.census.gov/prod2/statcomp/usac/zip/' %+% file
check_get(file, gdir, url, mode = 'wb')
unzip(file.path(gdir, 'LND.zip'), exdir = gdir)

## -----------------
## ./ipeds
## -----------------

ipeds_dir <- idir
source(file.path(args[1], 'download_ipeds.R'))

## -----------------
## ./sheeo
## -----------------

file <- 'State_by_State_Wave_Charts_FY15_0.xlsx'
url <- 'http://www.sheeo.org/sites/default/files/' %+% file
check_get(file, sdir, url, mode = 'wb')

## -----------------------------------------------------------------------------
## END SCRIPT
################################################################################
