################################################################################
##
## [ PROJ ] Open access broadband
## [ FILE ] make_stan_data.R
## [ AUTH ] Benjamin Skinner: @btskinner
## [ INIT ] 27 October 2016
##
################################################################################

## clear
rm(list = ls())

## command line arguments
args <- commandArgs(trailingOnly = TRUE)

## libraries
libs <- c('tidyverse', 'rstan')
lapply(libs, require, character.only = TRUE)

## paste function
`%+%` <- function(a,b) paste0(a,b)

## model type
mod_type <- args[1]

## broadband measures
bb_measures <- unlist(strsplit(args[2],','))

## directories
cdir <- args[3]
sdir <- args[4]

## =============================================================================
## VECTORS OF VARS
## =============================================================================

second_level_vars <- c('stunemrate',    # state unemployment rate
                       'appropfte_t',   # appropriations / FTE ($1000s)
                       'twoyr_p',       # % public OA that are two year
                       'pwm_dist_oa')   # pop weighted ave. dist to nearest OA

first_level_vars <- c('twoyr',          # == 1 if two year
                      'room',           # == 1 if has room available
                      'lefdetot',       # log of total enrollment
                      'nwhitenrlp',     # prop. non-white enrollment
                      'womenenrlp',     # prop. women enrollment
                      'upgrntpp',       # prop. Pell grant
                      'pttotp',         # prop. part time
                      'age25op',        # prop. >= 25 years old
                      'lpopdens',       # log county population density
                      'year13',         # == 1 if 2013
                      'year14',         # == 1 if 2014
                      'rucc_2',         # USDA Rural/Urban codes (less 1)
                      'rucc_3',
                      'rucc_4',
                      'rucc_5',
                      'rucc_6',
                      'rucc_7',
                      'rucc_8',
                      'rucc_9')

## =============================================================================
## READ IN DATA
## =============================================================================

## student-level outcomes
df <- read_csv(cdir %+% 'analysis_oap.csv') %>%
    ## drop Indiana Ivy Tech b/c only one value in Indy
    filter(unitid != 150987) %>%
    ## create dummies for rural/urban categories
    mutate(rucc_2 = as.integer(rucc == 2),
           rucc_3 = as.integer(rucc == 3),
           rucc_4 = as.integer(rucc == 4),
           rucc_5 = as.integer(rucc == 5),
           rucc_6 = as.integer(rucc == 6),
           rucc_7 = as.integer(rucc == 7),
           rucc_8 = as.integer(rucc == 8),
           rucc_9 = as.integer(rucc == 9))

## =============================================================================
## SET STAN DATA: FULL
## =============================================================================

## vector of states using Stan-approved integers with no skips like fips
state <- df %>% .[['ststan']]

## second-level predictors
z <- df %>%
    distinct(stfips, .keep_all = TRUE) %>%
    select_(.dots = second_level_vars) %>%
    as.matrix(.)

## vector of regions for second-level intercept
region <- df %>%
    distinct(stfips, .keep_all = TRUE) %>%
    .[['region']]

## dimensions
J = length(unique(state))
L = ncol(z)
R = length(unique(region))

## =============================================================================
## CHECK FOR MODEL TYPE
## =============================================================================

if (grepl('beta', mod_type)) {

    ## -------------------------------------
    ## BETA
    ## -------------------------------------

    for (meas in bb_measures) {

        ## empirical outcome: at least some
        y <- df %>% .[['efdesom']]

        ## likelihood is bionmial (success, total): these are totals
        trials <- df %>% .[['efdetot']]

        ## empirical outcome: proportion
        y <- y / trials

        ## first-level matrix of school-level predictors
        if (grepl('_all', meas)) {

            ## get measure vector (need so get right weighted version)
            m <- grep(strsplit(meas, '_')[[1]][1], names(df), value = TRUE)

            ## all broadband measures
            x <- df %>%
                mutate_(bb_meas_1 = m[1],
                        bb_meas_sq_1 = quote(bb_meas_1^2),
                        bb_meas_2 = m[2],
                        bb_meas_sq_2 = quote(bb_meas_2^2),
                        bb_meas_3 = m[3],
                        bb_meas_sq_3 = quote(bb_meas_3^2)) %>%
                select_(.dots = c('bb_meas_1', 'bb_meas_sq_1',
                                  'bb_meas_2', 'bb_meas_sq_2',
                                  'bb_meas_3', 'bb_meas_sq_3',
                                  first_level_vars)) %>%
                as.matrix(.)

        } else {

            ## only one broadband measure
            x <- df %>%
                mutate_(bb_meas = meas,
                        bb_meas_sq = quote(bb_meas^2)) %>%
                select_(.dots = c('bb_meas', 'bb_meas_sq', first_level_vars)) %>%
                as.matrix(.)
        }

        ## dimensions
        N = nrow(x)
        K = ncol(x)

        if (mod_type == 'vi_beta') {

            ## multilevel: varying intercept
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K',
                         'J', 'L', 'R', 'region'),
                       file = sdir %+% 'vi_beta_full_' %+% meas %+% '.R.data')

        } else if (mod_type == 'vs_beta_all') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K',
                         'J', 'L', 'R', 'region'),
                       file = sdir %+% 'vs_beta_all_full_' %+%
                           meas %+% '.R.data')

        } else if (mod_type == 'vs_beta') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K',
                         'J', 'L', 'R', 'region'),
                       file = sdir %+% 'vs_beta_full_' %+% meas %+% '.R.data')

        } else {

            ## single level
            stan_rdump(c('y', 'x', 'N', 'K'),
                       file = sdir %+% 'sl_beta_full_' %+% meas %+% '.R.data')
        }
    }

} else if (grepl('normal', mod_type)) {

    ## -------------------------------------
    ## NORMAL
    ## -------------------------------------

    for (meas in bb_measures) {

        ## empirical outcome: log(at least some)
        y <- df %>% .[['lefdesom']]

        ## first-level matrix of school-level predictors
        if (grepl('_all', meas)) {

            ## get measure vector (need so get right weighted version)
            m <- grep(strsplit(meas, '_')[[1]][1], names(df), value = TRUE)

            ## all broadband measures
            x <- df %>%
                mutate_(bb_meas_1 = m[1],
                        bb_meas_sq_1 = quote(bb_meas_1^2),
                        bb_meas_2 = m[2],
                        bb_meas_sq_2 = quote(bb_meas_2^2),
                        bb_meas_3 = m[3],
                        bb_meas_sq_3 = quote(bb_meas_3^2)) %>%
                select_(.dots = c('bb_meas_1', 'bb_meas_sq_1',
                                  'bb_meas_2', 'bb_meas_sq_2',
                                  'bb_meas_3', 'bb_meas_sq_3',
                                  first_level_vars)) %>%
                as.matrix(.)

        } else {

            ## only one broadband measure
            x <- df %>%
                mutate_(bb_meas = meas,
                        bb_meas_sq = quote(bb_meas^2)) %>%
                select_(.dots = c('bb_meas', 'bb_meas_sq', first_level_vars)) %>%
                as.matrix(.)
        }

        ## dimensions
        N = nrow(x)
        K = ncol(x)

        if (mod_type == 'vi_normal') {

            ## multilevel: varying intercept
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K', 'J',
                         'L', 'R', 'region'),
                       file = sdir %+% 'vi_normal_full_' %+% meas %+% '.R.data')

        } else if (mod_type == 'vs_normal_all') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K', 'J',
                         'L', 'R', 'region'),
                       file = sdir %+% 'vs_normal_all_full_' %+%
                           meas %+% '.R.data')

        } else if (mod_type == 'vs_normal') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K', 'J',
                         'L', 'R', 'region'),
                       file = sdir %+% 'vs_normal_full_' %+% meas %+% '.R.data')

        } else {

            ## single level
            stan_rdump(c('y','x', 'N', 'K'),
                       file = sdir %+% 'sl_normal_full_' %+% meas %+% '.R.data')
        }
    }
}

## =============================================================================
## SET STAN DATA: SENS
## =============================================================================

## =============================================================================
## READ IN DATA
## =============================================================================

## student-level outcomes
df <- read_csv(cdir %+% 'analysis_all.csv') %>%
    ## drop Indiana Ivy Tech b/c only one value in Indy
    filter(unitid != 150987) %>%
    ## create dummies for rural/urban categories
    mutate(rucc_2 = as.integer(rucc == 2),
           rucc_3 = as.integer(rucc == 3),
           rucc_4 = as.integer(rucc == 4),
           rucc_5 = as.integer(rucc == 5),
           rucc_6 = as.integer(rucc == 6),
           rucc_7 = as.integer(rucc == 7),
           rucc_8 = as.integer(rucc == 8),
           rucc_9 = as.integer(rucc == 9))

first_level_vars <- c('twoyr',          # == 1 if two year
                      'room',           # == 1 if has room available
                      'privnp',         # == 1 if private, non-profit
                      'privfp',         # == 1 if private, for-profit
                      'openadmp',       # == 1 if open admissions policy
                      'lefdetot',       # log of total enrollment
                      'nwhitenrlp',     # prop. non-white enrollment
                      'womenenrlp',     # prop. women enrollment
                      'upgrntpp',       # prop. Pell grant
                      'pttotp',         # prop. part time
                      'age25op',        # prop. >= 25 years old
                      'lpopdens',       # log county population density
                      'year13',         # == 1 if 2013
                      'year14',         # == 1 if 2014
                      'rucc_2',         # USDA Rural/Urban codes (less 1)
                      'rucc_3',
                      'rucc_4',
                      'rucc_5',
                      'rucc_6',
                      'rucc_7',
                      'rucc_8',
                      'rucc_9')

## vector of states using Stan-approved integers with no skips like fips
state <- df %>% .[['ststan']]

## second-level predictors
z <- df %>%
    distinct(stfips, .keep_all = TRUE) %>%
    select_(.dots = second_level_vars) %>%
    as.matrix(.)

## vector of regions for second-level intercept
region <- df %>%
    distinct(stfips, .keep_all = TRUE) %>%
    .[['region']]

## dimensions
J = length(unique(state))
L = ncol(z)
R = length(unique(region))

## =============================================================================
## CHECK FOR MODEL TYPE
## =============================================================================

if (grepl('beta', mod_type)) {

    ## -------------------------------------
    ## BETA
    ## -------------------------------------

    for (meas in bb_measures) {

        ## empirical outcome: at least some
        y <- df %>% .[['efdesom']]

        ## likelihood is bionmial (success, total): these are totals
        trials <- df %>% .[['efdetot']]

        ## empirical outcome: proportion
        y <- y / trials

        ## first-level matrix of school-level predictors
        if (grepl('_all', meas)) {

            ## get measure vector (need so get right weighted version)
            m <- grep(strsplit(meas, '_')[[1]][1], names(df), value = TRUE)

            ## all broadband measures
            x <- df %>%
                mutate_(bb_meas_1 = m[1],
                        bb_meas_sq_1 = quote(bb_meas_1^2),
                        bb_meas_2 = m[2],
                        bb_meas_sq_2 = quote(bb_meas_2^2),
                        bb_meas_3 = m[3],
                        bb_meas_sq_3 = quote(bb_meas_3^2)) %>%
                select_(.dots = c('bb_meas_1', 'bb_meas_sq_1',
                                  'bb_meas_2', 'bb_meas_sq_2',
                                  'bb_meas_3', 'bb_meas_sq_3',
                                  first_level_vars)) %>%
                as.matrix(.)

        } else {

            ## only one broadband measure
            x <- df %>%
                mutate_(bb_meas = meas,
                        bb_meas_sq = quote(bb_meas^2)) %>%
                select_(.dots = c('bb_meas', 'bb_meas_sq', first_level_vars)) %>%
                as.matrix(.)
        }

        ## dimensions
        N = nrow(x)
        K = ncol(x)

        if (mod_type == 'vi_beta') {

            ## multilevel: varying intercept
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K',
                         'J', 'L', 'R', 'region'),
                       file = sdir %+% 'vi_beta_sens_' %+% meas %+% '.R.data')

        } else if (mod_type == 'vs_beta_all') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K',
                         'J', 'L', 'R', 'region'),
                       file = sdir %+% 'vs_beta_all_sens_' %+%
                           meas %+% '.R.data')

        } else if (mod_type == 'vs_beta') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K',
                         'J', 'L', 'R', 'region'),
                       file = sdir %+% 'vs_beta_sens_' %+% meas %+% '.R.data')

        } else {

            ## single level
            stan_rdump(c('y', 'x', 'N', 'K'),
                       file = sdir %+% 'sl_beta_sens_' %+% meas %+% '.R.data')
        }
    }

} else if (grepl('normal', mod_type)) {

    ## -------------------------------------
    ## NORMAL
    ## -------------------------------------

    for (meas in bb_measures) {

        ## empirical outcome: log(at least some)
        y <- df %>% .[['lefdesom']]

        ## first-level matrix of school-level predictors
        if (grepl('_all', meas)) {

            ## get measure vector (need so get right weighted version)
            m <- grep(strsplit(meas, '_')[[1]][1], names(df), value = TRUE)

            ## all broadband measures
            x <- df %>%
                mutate_(bb_meas_1 = m[1],
                        bb_meas_sq_1 = quote(bb_meas_1^2),
                        bb_meas_2 = m[2],
                        bb_meas_sq_2 = quote(bb_meas_2^2),
                        bb_meas_3 = m[3],
                        bb_meas_sq_3 = quote(bb_meas_3^2)) %>%
                select_(.dots = c('bb_meas_1', 'bb_meas_sq_1',
                                  'bb_meas_2', 'bb_meas_sq_2',
                                  'bb_meas_3', 'bb_meas_sq_3',
                                  first_level_vars)) %>%
                as.matrix(.)

        } else {

            ## only one broadband measure
            x <- df %>%
                mutate_(bb_meas = meas,
                        bb_meas_sq = quote(bb_meas^2)) %>%
                select_(.dots = c('bb_meas', 'bb_meas_sq', first_level_vars)) %>%
                as.matrix(.)
        }

        ## dimensions
        N = nrow(x)
        K = ncol(x)

        if (mod_type == 'vi_normal') {

            ## multilevel: varying intercept
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K', 'J',
                         'L', 'R', 'region'),
                       file = sdir %+% 'vi_normal_sens_' %+% meas %+% '.R.data')

        } else if (mod_type == 'vs_normal_all') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K', 'J',
                         'L', 'R', 'region'),
                       file = sdir %+% 'vs_normal_all_sens_' %+%
                           meas %+% '.R.data')

        } else if (mod_type == 'vs_normal') {

            ## multilevel: varying slope
            stan_rdump(c('y', 'state', 'x', 'z', 'N', 'K', 'J',
                         'L', 'R', 'region'),
                       file = sdir %+% 'vs_normal_sens_' %+% meas %+% '.R.data')

        } else {

            ## single level
            stan_rdump(c('y','x', 'N', 'K'),
                       file = sdir %+% 'sl_normal_sens_' %+% meas %+% '.R.data')
        }
    }
}

## =============================================================================
## END FILE
################################################################################
