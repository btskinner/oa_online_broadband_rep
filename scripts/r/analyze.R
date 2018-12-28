################################################################################
##
## <PROJ> Dissertation
## <FILE> analyze.R
## <AUTH> Benjamin Skinner
## <INIT> 31 August 2016
##
################################################################################

## clear
rm(list = ls())

## libraries
libs <- c('dplyr', 'readr', 'rstan')
lapply(libs, require, character.only = TRUE)

## utility functions
source('../../utils.R')

## directories
ddir <- '../../../data/'
cdir <- ddir %+% 'cleaned/'
gdir <- ddir %+% 'geo/'

## set optimizations
rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

## =============================================================================
## READ IN DATA
## =============================================================================

## student-level outcomes
df <- read_csv(cdir %+% 'rq1_analysis.csv') %>%
    tbl_df() %>%
    filter(!is.na(efdesom),
           !is.na(efdeexc),
           !is.na(efdenon),
           !is.na(openadmp),
           !is.na(age25o),
           !is.na(upgrntn)) %>%
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
           public_p = round(mean(public), 2),
           privnp_p = round(mean(privnp), 2),
           privfp_p = round(mean(privfp), 2),
           openadmp_p = round(mean(openadmp, na.rm = TRUE), 2)) %>%
    ungroup() %>%
    select(stfips, ends_with('_p')) %>%
    distinct(stfips, .keep_all = TRUE)

## join back to tbl_df
df <- df %>%
    left_join(ststan, by = 'stfips') %>%
    left_join(stpct, by = 'stfips')

## =============================================================================
## SET STAN DATA
## =============================================================================

## empirical outcome: at least some
y <- df %>% .[['efdesom']]

## likelihood is bionmial (success, total): these are totals
trials <- df %>% .[['efdetot']]

## vector of states using Stan-approved integers with no skips like fips
state <- df %>% .[['ststan']]

## first-level matrix of school-level predictors
x <- df %>%
    mutate(nwhitenrlp = (efdetot - efwhitt) / efdetot, # non-white enrollment
           womenenrlp = (efdetot - eftotlw) / efdetot, # women enrollment
           upgrntpp = upgrntp / 100,                   # pell grnt prop
           pttotp = pttot / efdetot,                   # parttime
           age25op = age25o / efdetot,                 # >= 25 yo
           year13 = ifelse(year == 2013, 1, 0),
           year14 = ifelse(year == 2014, 1, 0)) %>%
    select(wdownload,
           twoyr,
           public,
           privnp,
           privfp,
           openadmp,
           nwhitenrlp,
           womenenrlp,
           upgrntpp,
           pttotp,
           age25op,
           year13) %>%
    ## to matrix
    as.matrix(.)

## Second-level predictors
z <- df %>%
    distinct(stfips, .keep_all = TRUE) %>%
    select(stunemrate,
           appropfte_t,
           twoyr_p,
           public_p,
           privnp_p,
           privfp_p,
           openadmp_p) %>%
    ## standardize to aid mixing
    mutate_each(funs((. - mean(.)) / sd(.))) %>%
    ## to matrix
    as.matrix(.)

## vector of regions for second-level intercept
region <- df %>%
    distinct(stfips, .keep_all = TRUE) %>%
    .[['region']]

## store in list
stan_df <- list('y' = y,
                'trials' = trials,
                'state' = state,
                'x' = x,
                'z' = z,
                'N' = nrow(x),
                'K' = ncol(x),
                'J' = length(unique(state)),
                'L' = ncol(z),
                'R' = length(unique(region)),
                'region' = region)
N = nrow(x)
K = ncol(x)
J = length(unique(state))
L = ncol(z)
R = length(unique(region))

stan_rdump(c('y', 'trials', 'state', 'x', 'z',
             'N', 'K', 'J', 'L', 'R', 'region'),
           file = cdir %+% 'test.R.data')

## =============================================================================
## RUN STAN
## =============================================================================

## cheap way to compile before sampling (will get error, but that's okay)
fit <- stan(file = '../stan/varying_int_nc.stan', iter = 0)

## set options (this is to avoid divergent transitions)
opts <- list(adapt_delta = 0.999, stepsize = 0.001, max_treedepth = 20)

## actual samples (can use fit object now)
samp <- stan(fit = fit, data = stan_df, chains = 4, control = opts)

## print parameters that matter
print(samp, c('a_region', 'b_state', 'beta'))

## save posteriors as csv
pars <- c('beta','a_region','b_state')
post <- extract(samp)[pars]

## add names
colnames(post[['beta']]) <- paste0('beta[', 1:ncol(post[['beta']]), ']')
colnames(post[['a_region']]) <- paste0('a_region[',1:ncol(post[['a_region']]),']')
colnames(post[['b_state']]) <- paste0('b_state[',1:ncol(post[['b_state']]),']')

## put into matrix
post <- cbind(post[['a_region']], post[['b_state']], post[['beta']])

## write to csv
write.csv(post, file = ddir %+% 'posterior.csv', row.names = FALSE)

## =============================================================================
## END FILE
################################################################################
