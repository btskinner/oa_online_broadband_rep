################################################################################
##
## [ PROJ ] Open access broadband
## [ FILE ] clean_bb.R
## [ AUTH ] Benjamin Skinner: @btskinner
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
libs <- c('tidyverse','distRcpp')
sapply(libs, require, character.only = TRUE)

## directories
bdir <- args[2] %+% '/broadband/'
cdir <- args[2] %+% '/cleaned/'
gdir <- args[2] %+% '/geo/'

## ---------------------------
## READ DATA/CREATE TABLES
## ---------------------------

## get census block group pop and lon/lat
cb <- read_csv(gdir %+% 'CenPop2010_Mean_BG.txt') %>%
    setNames(tolower(names(.))) %>%
    filter(!(statefp %in% c('02','15','72'))) %>%
    mutate(fips = statefp %+% countyfp %+% tractce %+% blkgrpce) %>%
    select(fips, pop = population, lon = longitude, lat = latitude)

## get school data
sc <- read_csv(cdir %+% 'ipeds.csv') %>%
    filter(!(stabbr %in% c('AK','HI'))) %>%
    distinct(unitid, year, .keep_all = TRUE)

## census block level broadband tables
db <- src_sqlite(bdir %+% 'bb.db')
bb_tbls <- c('June_2012', 'June_2013', 'June_2014')

## init list
scbb_list <- list()

## loop through each measurement period
for(i in 1:length(bb_tbls)) {

    message('---------------------------------')
    message('Working with: ' %+% bb_tbls[i])
    message('---------------------------------')

    ## split name into month / year components
    nm <- strsplit(bb_tbls[i], '_')[[1]]
    mo <- ifelse(nm[1] == 'June', 6, 12)
    yr <- as.integer(nm[2])

    ## read and store in list
    bb <- tbl(db, bb_tbls[i]) %>%
        filter(!is.na(download)) %>%
        select(-mcount) %>%
        tbl_df() %>%
        inner_join(cb, by = 'fips')

    ## measures: download, upload, pcount
    measure <- c('download','upload','pcount')

    ## init list
    outlist <- list()

    ## loop through each measure
    for(j in 1:length(measure)) {

        message('Working on: ' %+% measure[j])

        ## Rcpp population-distance weighting script: quadratic decay (2)
        message('   Population distance weight: quadratic decay')
        out_1 <- popdist_weighted_mean(x_df = sc %>% filter(year == yr),
                                       y_df = bb,
                                       measure_col = measure[j],
                                       x_id = 'unitid',
                                       decay = 2) %>%
            rename(unitid = id) %>%
            rename_(.dots = setNames('wmeasure', 'pdw2_' %+% measure[j]))

        outlist[[j]] <- Reduce(left_join, list(out_1))

    }

    ## add to list
    scbb_list[[i]] <- Reduce(left_join, outlist) %>%
        tbl_df() %>%
        mutate(mon = mo,
               year = yr)

}

## bind time periods into one tbl_df
scbb <- bind_rows(scbb_list) %>%
    arrange(unitid, year, mon) %>%
    mutate_each(funs(round(., 4)), -c(unitid, year, mon))

## -------------------------------------
## write to disk
## -------------------------------------

write.table(scbb, file = cdir %+% 'scbb.csv', sep = ',',
            quote = FALSE, row.names = FALSE)

## =============================================================================
## END
################################################################################
