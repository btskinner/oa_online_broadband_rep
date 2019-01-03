################################################################################
##
## [ PROJ ] Open access broadband
## [ FILE ] clean_ipeds.R
## [ AUTH ] Benjamin Skinner
## [ INIT ] 30 August 2016
##
################################################################################

## clear memory
rm(list = ls())

## command line arguments
## args[1] <- <path>/<to>/scripts/r
## args[2] <- <path>/<to>/data
args <- commandArgs(trailingOnly = TRUE)

## read in utility functions
source(paste0(args[1],'/utils.R'))

## libraries
libs <- c('tidyverse')
lapply(libs, require, character.only = TRUE)

## directories (temporary directory for unzipping files)
ddir <- args[2] %+% '/ipeds/'
cdir <- args[2] %+% '/cleaned/'
gdir <- args[2] %+% '/geo/'
tmp <- tempdir()

## function to return name of file to unzip (revision if exists)
get_file <- function(zipfile) {

    opts <- unzip(zipfile, list = TRUE)

    if (nrow(opts) > 1) {
        fn <- grep('*_rv.csv', opts$Name, value = TRUE)
    } else {
        fn <- opts$Name[1]
    }
    return(fn)
}

## get list of state abbreviations
st <- read_csv(gdir %+% 'stcrosswalk.csv') %>% .[['st']]

## ---------------------------
## READ DATA/CREATE TABLES
## ---------------------------

## years
years <- c(2012:2014)

## init tbl_df() list
df_list <- list()

for (i in years) {

    ## set years
    year <- i
    yearmod <- (as.integer(year) - 2001) %+% (as.integer(year) - 2000)

    ## get zip file names (revised versions if they exist)
    hd_zip <- ddir %+% 'HD' %+% year %+% '.zip'
    hd_file <- get_file(hd_zip)

    ic_zip <- ddir %+% 'IC' %+% year %+% '.zip'
    ic_file <- get_file(ic_zip)

    efia_zip <- ddir %+% 'EFIA' %+% year %+% '.zip'
    efia_file <- get_file(efia_zip)

    ef_a_zip <- ddir %+% 'EF' %+% year %+% 'A.zip'
    ef_a_file <- get_file(ef_a_zip)

    ef_b_zip <- ddir %+% 'EF' %+% year %+% 'B.zip'
    ef_b_file <- get_file(ef_b_zip)

    sfa_zip <- ddir %+% 'SFA' %+% yearmod %+% '.zip'
    sfa_file <- get_file(sfa_zip)


    ef_dist_zip <- ddir %+% 'EF' %+% year %+% 'A_DIST.zip'
    ef_dist_file <- get_file(ef_dist_zip)

    message('Now working with: ' %+% year)

    ## begin w/ general information
    df <- read_csv(unzip(hd_zip, hd_file, exdir = tmp)) %>%
        select(UNITID,                      # id
               STABBR,                      # state
               COUNTYCD,                    # 5-digit fips
               SECTOR,                      # control/level
               LONGITUD,                    # lon
               LATITUDE) %>%                # lat
        ## add further institutional characteristics
        left_join(read_csv(unzip(ic_zip, ic_file, exdir = tmp)) %>%
            select(UNITID,                  # id
                   OPENADMP,                # open admissions
                   ROOM),                   # has on-campus housing
            by = 'UNITID') %>%
        ## add instructional activity
        left_join(read_csv(unzip(efia_zip, efia_file, exdir = tmp)) %>%
            select(UNITID,                  # id
                   EFTEUG),                 # est. FTE ug enrollment
            by = 'UNITID') %>%
        ## add enrollment info (I)
        left_join(read_csv(unzip(ef_a_zip, ef_a_file, exdir = tmp)) %>%
            filter(EFALEVEL == 2) %>%       # ug only
            select(UNITID,                  # id
                   EFTOTLT,                 # ug total
                   EFTOTLW,                 # ug women total
                   EFWHITT),                # ug white pop. total
            by = 'UNITID') %>%
        ## add enrollment info (II)
        left_join(read_csv(unzip(ef_b_zip, ef_b_file, exdir = tmp)) %>%
            filter(EFBAGE == 1, LSTUDY == 2) %>%
            rename(PTTOT = EFAGE06) %>%
            select(UNITID,                  # id
                   PTTOT),                  # part time total
            by = 'UNITID') %>%
        ## add enrollment info (III)
        left_join(read_csv(unzip(ef_b_zip, ef_b_file, exdir = tmp)) %>%
            filter(EFBAGE == 7, LSTUDY == 2) %>%
            rename(AGE25O = EFAGE09) %>%
            select(UNITID,                  # id
                   AGE25O),                 # pop over age 25
            by = 'UNITID') %>%
        ## add student aid information
        left_join(read_csv(unzip(sfa_zip, sfa_file, exdir = tmp)) %>%
            select(UNITID,                  # id
                   UPGRNTN,                 # ug num pell grant
                   UPGRNTP),                # ug pct pell grant
            by = 'UNITID') %>%
        ## add distance education numbers
        left_join(read_csv(unzip(ef_dist_zip, ef_dist_file, exdir = tmp)) %>%
            filter(EFDELEV == 2) %>%        # ug only
            select(UNITID,                  # id
                   EFDETOT,                 # online total
                   EFDESOM,                 # some courses online
                   EFDEEXC,                 # exclusively online
                   EFDENON),                # none online
            by = 'UNITID') %>%
        ## filter out non-schools
        filter(SECTOR != 0, SECTOR != 99) %>%
        ## convert to tbl_df()
        collect %>%
        ## set names to lowercase
        setNames(tolower(names(.))) %>%
        ## new variables
        mutate(year = year,
               twoyr = as.integer(sector > 3 & sector < 7),
               fouryr = as.integer(sector < 4),
               public = as.integer(sector == 1 | sector == 4 | sector == 7),
               privnp = as.integer(sector == 2 | sector == 5 | sector == 8),
               privfp = as.integer(sector == 3 | sector == 6 | sector == 9),
               openadmp = ifelse(openadmp == 2, 0,
                          ifelse(openadmp < 0, NA, openadmp)),
               pttot = as.numeric(pttot),
               age25o = as.numeric(age25o),
               room = ifelse(room == 2, 0,
                      ifelse(room < 0, NA, room))) %>%
        ## arrange rows
        arrange(unitid, year) %>%
        ## arrange columns
        select(unitid, year, stabbr, fips = countycd,
               lon = longitud, lat = latitude, openadmp:privfp)

    ## store in list
    df_list[[as.character(year)]] <- df
}

## bind into one tbl_df()
df <- bind_rows(df_list) %>%
    arrange(unitid, year) %>%
    ## keep only lower 48 states
    filter(stabbr %in% st)

## -------------------------------------
## write to disk
## -------------------------------------

write.csv(df, file = cdir %+% 'ipeds.csv', row.names = FALSE, quote = FALSE)

## -------------------------------------
## clean up
## -------------------------------------

unlink(tmp, recursive = TRUE)

## =============================================================================
## END
################################################################################
