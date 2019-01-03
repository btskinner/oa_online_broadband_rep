################################################################################
##
## [ PROJ ] Open access broadband
## [ FILE ] clean_data.R
## [ AUTH ] Benjamin Skinner
## [ INIT ] 11 October 2016
##
################################################################################

## clear
rm(list = ls())

## command line arguments
## args[1] <- <path>/<to>/scripts/r
## args[2] <- <path>/<to>/data
args <- commandArgs(trailingOnly = TRUE)

## read in utility functions
source(paste0(args[1],'/utils.R'))

## libraries
libs <- c('tidyverse','readxl','distRcpp')
lapply(libs, require, character.only = TRUE)

## directories
ddir <- args[2]
adir <- ddir %+% '/acs/'
bdir <- ddir %+% '/broadband/'
cdir <- ddir %+% '/cleaned/'
idir <- ddir %+% '/ipeds/'
gdir <- ddir %+% '/geo/'
sdir <- ddir %+% '/sheeo/'

## constants
m2miles <- 0.000621371

## =============================================================================
## READ IN DATA
## =============================================================================

## -------------------------------------
## State crosswalk
## -------------------------------------

cw <- read_csv(gdir %+% 'stcrosswalk.csv') %>%
    rename(stabbr = st)

## -------------------------------------
## School w/Broadband
## -------------------------------------

sc <- read_csv(cdir %+% 'ipeds.csv') %>%
    left_join(read_csv(cdir %+% 'scbb.csv'),
              by = c('unitid', 'year')) %>%
    left_join(cw, by = 'stabbr') %>%
    ## drop if fips < 0 or missing state name or DC (not state)
    filter(fips > 0, !is.na(stname), stabbr != 'DC') %>%
    ## fix state fips to be character w/ leading zero
    mutate(fips = sprintf('%05d', fips))

## -------------------------------------
## SHEEO
## -------------------------------------

sheeo <- read_excel(sdir %+% 'State_by_State_Wave_Charts_FY15_0.xlsx',
                    sheet = 1,
                    skip = 1,
                    col_names = c('year','stname','fte','appropfte',
                                  'nettuitfte','stuappropshare')) %>%
    filter(stname != 'US',
           year %in% c(2012:2014)) %>%
    ## round fte to nearest integer
    mutate(fte = as.integer(round(fte))) %>%
    arrange(stname, year) %>%
    left_join(cw %>%
              select(stfips, stname),
              by = 'stname')

## -------------------------------------
## ACS
## -------------------------------------

## NB: Using 5 year rolling to get small county values

acs <- read_csv(adir %+% 'ACS_14_5YR_S2301_state.csv') %>%
    select(stfips = GEO.id2,
           sttotpop = HC01_EST_VC01,
           stlforcepct = HC02_EST_VC01,
           stemppct = HC03_EST_VC01,
           stunemrate = HC04_EST_VC01,
           sttotwhite = HC01_EST_VC22,
           stbahigh = HC01_EST_VC41) %>%
    mutate(sttotpop = as.numeric(sttotpop),
           stlforcepct = as.numeric(stlforcepct),
           stemppct = as.numeric(stemppct),
           stunemrate = as.numeric(stunemrate),
           sttotwhite = as.numeric(sttotwhite),
           stbahigh = as.numeric(stbahigh),
           sttotnonwhite = sttotpop - sttotwhite,
           stlabforce = round(sttotpop * stlforcepct/100),
           sttotunem = round(stlabforce * stunemrate/100)) %>%
    left_join(read_csv(adir %+% 'ACS_14_5YR_S2301_county.csv') %>%
              select(fips = GEO.id2,
                     cttotpop = HC01_EST_VC01,
                     ctlforcepct = HC02_EST_VC01,
                     ctemppct = HC03_EST_VC01,
                     ctunemrate = HC04_EST_VC01,
                     cttotwhite = HC01_EST_VC22,
                     ctbahigh = HC01_EST_VC41) %>%
              mutate(cttotpop = as.numeric(cttotpop),
                     ctlforcepct = as.numeric(ctlforcepct),
                     ctemppct = as.numeric(ctemppct),
                     ctunemrate = as.numeric(ctunemrate),
                     cttotwhite = as.numeric(cttotwhite),
                     ctbahigh = as.numeric(ctbahigh),
                     cttotnonwhite = cttotpop - cttotwhite,
                     ctlabforce = round(cttotpop * ctlforcepct/100),
                     cttotunem = round(ctlabforce * ctunemrate/100),
                     stfips = substr(fips,1,2)),
              by = 'stfips') %>%
    filter(!is.na(fips))

## -------------------------------------
## Population
## -------------------------------------

## read file
pop <- read_csv(adir %+% 'co-est2015-alldata.csv',
                col_names = TRUE) %>%
    setNames(tolower(names(.)))

## state level
state <- pop %>% filter(sumlev == '040') %>%
    select(stfips = state, popestimate2012:popestimate2014) %>%
    gather(year, statepop, popestimate2012:popestimate2014) %>%
    mutate(year = as.integer(gsub('.*(\\d{4})', '\\1', year)))

## county level
county <- pop %>% filter(sumlev == '050') %>%
    select(stfips = state, county, ctyname, popestimate2012:popestimate2014) %>%
    mutate(fips = stfips %+% county) %>%
    gather(year, countypop, popestimate2012:popestimate2014) %>%
    mutate(year = as.integer(gsub('.*(\\d{4})', '\\1', year))) %>%
    ## change new fips to old fips number
    mutate(fips = ifelse(fips == 46102, 46113, fips)) %>%
    ## add land area
    left_join(read_excel(gdir %+% 'LND01.xls') %>%
              setNames(tolower(names(.))) %>%
              rename(fips = stcou,
                     landarea = lnd110210d) %>%
              select(fips, landarea),
              by = 'fips') %>%
    mutate(popdens = countypop / landarea) %>%
    ## add rurality
    left_join(read_excel(gdir %+% 'ruralurbancodes2013.xls') %>%
              setNames(tolower(names(.))) %>%
              rename(rucc = rucc_2013) %>%
              select(fips, rucc),
              by = 'fips')

## -------------------------------------
## Mean distance to nearest OA public
## -------------------------------------

## read in institutions, subset to open admissions
oa <- sc %>%
    filter(openadmp == 1)

## get census block groups
cb <- read_csv(gdir %+% 'CenPop2010_Mean_BG.txt') %>%
    setNames(tolower(names(.))) %>%
    mutate(fips = statefp %+% countyfp %+% tractce %+% blkgrpce) %>%
    select(stfips = statefp, fips, pop = population,
           lon = longitude, lat = latitude) %>%
    filter(!(stfips %in% c('11', '72')))

## init list
mean_dist_list <- list()

## loop through years and states
for (y in oa %>% distinct(year) %>% .[['year']]) {

    for (s in cb %>% distinct(stfips) %>% .[['stfips']]) {

        message('Working with ' %+% s %+% ' in ' %+% y)

        ## subset
        tmp_oa <- oa %>% filter(year == y, stfips == s)
        tmp_cb <- cb %>% filter(stfips == s)

        ## get min distance
        tmp <- dist_min(tmp_cb, tmp_oa, 'fips', 'unitid') %>%
            tbl_df() %>%
            mutate(fips = as.character(id_start)) %>%
            left_join(cb %>% select(fips, pop), by = 'fips') %>%
            summarise(pwm_dist_oa = weighted.mean(meters, pop) * m2miles) %>%
            mutate(stfips = s,
                   year = y) %>%
            select(stfips, year, pwm_dist_oa)

        ## add to list
        mean_dist_list[[as.character(s) %+% '_' %+% as.character(y)]] <- tmp

    }
}

## collapse into dataframe
md <- bind_rows(mean_dist_list) %>%
    arrange(stfips, year)

## =============================================================================
## JOIN AND CLEAN DATA
## =============================================================================

df <- sc %>%
    ## add county data
    left_join(county) %>%
    ## add state data
    left_join(state) %>%
    ## acs data
    left_join(acs) %>%
    ## add SHEEO
    left_join(sheeo) %>%
    ## add mean distance to open admissions
    left_join(md) %>%
    ## filter out those w/o distance education data
    filter(!is.na(efdesom)) %>%
    ## filter those w/o undergraduate enrollment totals
    filter(!is.na(efteug)) %>%
    ## make tbl_df
    tbl_df() %>%
    ## subset to non-missing
    filter(!(stabbr %in% c('AK','HI')),
           !is.na(efdesom),
           !is.na(efdeexc),
           !is.na(efdenon),
           !is.na(openadmp),
           !is.na(public),
           !is.na(age25o),
           !is.na(upgrntn),
           efdesom > 0,
           efdesom != efdetot) %>%
    ## change scale of appropriations variable
    mutate(appropfte_t = appropfte / 1000)

## stan indicators for states
ststan <- df %>%
    select(stfips) %>%
    distinct() %>%
    arrange(stfips) %>%
    mutate(ststan = row_number())

## state-level percentages
stpct <- df %>%
    group_by(stfips) %>%
    mutate(twoyr_p = round(mean(twoyr), 2),
           public_p = round(mean(public), 2)) %>%
    ungroup() %>%
    select(stfips, ends_with('_p')) %>%
    distinct(stfips, .keep_all = TRUE)

## join back to tbl_df
df <- df %>%
    left_join(ststan, by = 'stfips') %>%
    left_join(stpct, by = 'stfips') %>%
    ## new variables
    mutate(lpopdens = log(popdens),                    # log population density
           lefdesom = log1p(efdesom),                  # log some online
           lefdetot = log1p(efdetot),                  # log total enrollment
           nwhitenrlp = (efdetot - efwhitt) / efdetot, # non-white enrollment
           womenenrlp = (efdetot - eftotlw) / efdetot, # women enrollment
           upgrntpp = upgrntp / 100,                   # pell grnt prop
           pttotp = pttot / efdetot,                   # parttime
           age25op = age25o / efdetot,                 # >= 25 yo
           year13 = ifelse(year == 2013, 1, 0),        # == 1 for 2013
           year14 = ifelse(year == 2014, 1, 0))        # == 1 for 2014

df_analysis <- df %>% filter(openadmp == 1, public == 1)
df_public <- df %>% filter(public == 1)

## =============================================================================
## WRITE DATA
## =============================================================================

write.table(df_analysis,
            cdir %+% 'analysis_oap.csv',
            quote = FALSE,
            sep = ',',
            row.names = FALSE)

write.table(df_public,
            cdir %+% 'analysis_public.csv',
            quote = FALSE,
            sep = ',',
            row.names = FALSE)

write.table(df,
            cdir %+% 'analysis_all.csv',
            quote = FALSE,
            sep = ',',
            row.names = FALSE)

## =============================================================================
## END FILE
################################################################################
