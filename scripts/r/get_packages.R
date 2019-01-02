################################################################################
##
## [ PROJ ] Open access broadband
## [ FILE ] get_packages.R
## [ AUTH ] Benjamin Skinner: @btskinner
## [ INIT ] 1 January 2019
##
################################################################################

## -----------------
## CRAN
## -----------------

## required packages
recpkgs <- c('tidyverse',
             'devtools',
             'readxl',
             'rstan',
             'broom',
             'RSQLite',
             'maps',
             'mapproj',
             'maptools',
             'scales',
             'RColorBrewer',
             'grid',
             'gridExtra',
             'xtable')

## compare against already installed
misspkgs <- recpkgs[!(recpkgs %in% installed.packages()[,'Package'])]

## install those that are missing
if (length(misspkgs)) {
    install.packages(misspkgs)
} else {
    message('All required CRAN packages already installed!')
}

## -----------------
## GitHub
## -----------------

## required package
recpkgs <- c('distRcpp')

## compare against already installed
misspkgs <- recpkgs[!(recpkgs %in% installed.packages()[,'Package'])]

## get github packages
if (length(misspkgs)) {
    devtools::install_github('btskinner/distRcpp')
} else {
    message('All required GitHub packages already installed!')
}

## -----------------------------------------------------------------------------
## END SCRIPT
################################################################################
