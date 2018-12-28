## Figures for RQ 1 paper

## libraries
libs <- c('tidyverse','rstan','broom','RSQLite','maps','mapproj','maptools',
          'scales','RColorBrewer', 'grid','gridExtra')
sapply(libs, require, character.only = TRUE)

## directories
bdir <- '../../data/broadband/'
ddir <- '../../data/cleaned/'
fdir <- '../../figures/'
gdir <- '../../data/geo/'
odir <- '../../output/'

## functions
`%+%` <- function(a,b) paste(a, b, sep = '')
`%_%` <- function(a,b) paste(a, b, sep = '_')

## colorpalette
vublack <- rgb(0/255,0/255,0/255,1)
vugold <- rgb(162/255,132/255,72/255,1)
vumaroon <- rgb(122/255,5/255,74/255,1)
vublue <- rgb(0/255,93/255,164/255,1)
vugreen <- rgb(0/255,89/255,65/255,1)
vugray <- rgb(109/255,110/255,113/255,1)

## =============================================================================
## Broadband histogram
## =============================================================================

df_oap <- read_csv(file.path(ddir, 'analysis_oap.csv')) %>%
    filter(unitid != 150987)

threshold_dl <- data.frame(x = c(5, 8), name = c('Old threshold',
                                                 'New threshold (2015)'))

g <- ggplot(df_oap, aes(x = pdw2_download)) +
    geom_histogram(aes(y = ..density..), fill = 'white', colour = 'black') +
    geom_density(alpha = .2, fill = 'red') +
    geom_vline(aes(xintercept = x, linetype = name), data = threshold_dl) +
    scale_x_continuous(breaks = 1:11, limits = c(1,11)) +
    scale_y_continuous(breaks = seq(0,1,.1), limits = (c(0, 0.7))) +
    xlab('Download speed tier') +
    ylab('Density') +
    labs(linetype = 'FCC definition of broadband') +
    theme(legend.justification = c(1,1),
          legend.position = c(.95,.9))

ggsave(filename = 'sample_dl_hist.pdf',
       plot = g,
       device = 'pdf',
       path = fdir,
       width = 9,
       height = 4)

threshold_ul <- data.frame(x = c(3, 5), name = c('Old threshold',
                                                 'New threshold (2015)'))

g <- ggplot(df_oap, aes(x = pdw2_upload)) +
    geom_histogram(aes(y = ..density..), fill = 'white', colour = 'black') +
    geom_density(alpha = .2, fill = 'red') +
    geom_vline(aes(xintercept = x, linetype = name), data = threshold_ul) +
    scale_x_continuous(breaks = 1:11, limits = c(1,11)) +
    scale_y_continuous(breaks = seq(0,1,.1), limits = (c(0, 0.7))) +
    xlab('Upload speed tier') +
    ylab('Density') +
    labs(linetype = 'FCC definition of broadband') +
    theme(legend.justification = c(1,1),
          legend.position = c(.95,.9))

ggsave(filename = 'sample_ul_hist.pdf',
       plot = g,
       device = 'pdf',
       path = fdir,
       width = 9,
       height = 4)

## =============================================================================
## Broadband choropleth maps
## =============================================================================

## get database connection
bb_con <- dbConnect(SQLite(), bdir %+% 'bb.db')

## get census block group populations
bgpop <- read_csv(gdir %+% 'CenPop2010_Mean_BG.txt') %>%
    setNames(tolower(names(.))) %>%
    mutate(fips = statefp %+% countyfp %+% tractce %+% blkgrpce) %>%
    select(fips, pop = population)

## get table names
bb_tables <- dbListTables(bb_con)

## init list
bb_df_list <- list()

## loop to build county-level datasets
for (tab in bb_tables) {

    message('Now working with: ' %+% tab)

    ## get month and year
    mon <- strsplit(tab, '_')[[1]][1]
    year <- strsplit(tab, '_')[[1]][2]

    ## read/clean
    df <- dbReadTable(bb_con, tab) %>%
        ## drop measure count
        select(-mcount) %>%
        ## add in population data
        left_join(bgpop, by = 'fips') %>%
        ## drop if pop is missing (non-states)
        filter(!is.na(pop)) %>%
        ## substring to county fips (5 digit)
        mutate(fips = substr(fips, 1, 5)) %>%
        ## group by county
        group_by(fips) %>%
        ## population-weighted mean
        summarise_each(funs(weighted.mean(., pop)), -pop) %>%
        ## add month and year
        mutate(mon = mon,
               year = year) %>%
        ## ungroup
        ungroup()

    ## add to list
    bb_df_list[[tab]] <- df

}

## bind into one tbl_df
bb_df <- bind_rows(bb_df_list) %>%
    arrange(fips, year, mon)

## disconnect from broadband database
dbDisconnect(bb_con)

## -----------------
## MAP
## -----------------

## set up county map data
cmap <- map_data('county') %>%
    mutate(polyname = region %+% ',' %+% subregion) %>%
    left_join(get(data(county.fips)) %>%
              mutate(polyname = as.character(polyname)),
              by = 'polyname') %>%
    mutate(fips = sprintf('%05d', fips))

## set up state map data
smap <- map_data('state')

## palette
s_pal <- brewer.pal(11,'RdBu')
c_pal <- brewer.pal(9,'Reds')

## loop: map each broadband table
for (tab in bb_tables) {

    message('Now working with: ' %+% tab)

    ## get month and year
    m <- strsplit(tab, '_')[[1]][1]
    y <- strsplit(tab, '_')[[1]][2]

    ## pull relevant table into tmp
    tmp <- bb_df %>%
        filter(mon == m, year == y)

    ## merge to county map data
    cmap_tmp <- left_join(cmap, tmp, by = 'fips') %>%
        arrange(group, order)

    ## loop through each measure
    for (meas in c('download','upload','pcount')) {

        ## legend name
        lmeas <- switch(meas,
                        download = 'Download\nspeed',
                        upload = 'Upload\nspeed',
                        pcount = 'Providers')

        ## with brewer palette to use
        meas_pal <- switch(meas,
                           download = s_pal,
                           upload = s_pal,
                           pcount = c_pal)

        ## create map
        m <- ggplot(cmap_tmp, aes(long, lat, group = group)) +
            geom_polygon(aes_string(fill = meas)) +
            geom_polygon(data = smap, aes(long, lat, group = group),
                         color = 'grey65', alpha = 0) +
            scale_fill_gradientn(lmeas, colours = meas_pal) +
            coord_map('polyconic', xlim = c(-120, -73.5),
                      ylim = c(25, 50)) +
            theme(line = element_blank(),
                  axis.text = element_blank(),
                  axis.title = element_blank(),
                  panel.background = element_blank(),
                  plot.margin = unit(c(0,0,0,0),'lines'),
                  legend.position = c(.94,.23),
                  legend.key.size = unit(2, 'lines'),
                  legend.text = element_text(size = 20),
                  legend.title = element_text(size = 20))

        ## write to disk
        ggsave(tab %_% meas %+% '.pdf',
               m,
               path = fdir,
               width = 13,
               height = 9)

    }

}

## =============================================================================
## Example broadband weighting scheme
## =============================================================================

## Davidson County, TN and surrounding counties
surcounty <- read_csv(gdir %+% 'neighborcounties.csv') %>%
    filter(orgfips == 47037) %>%
    select(-instate) %>%
    mutate(orgfips = as.integer(orgfips),
           adjfips = as.integer(adjfips)) %>%
    bind_rows(data.frame(orgfips = 47037,
                         adjfips = 47037)) %>%
    left_join(get(data(county.fips)),
              by = c('adjfips' = 'fips'))

## surrounding county centers
surcounty <- read_csv(gdir %+% 'county_centers.csv') %>%
    mutate(fips = as.integer(fips)) %>%
    filter(fips %in% surcounty$adjfips) %>%
    select(fips, clon = pclon10, clat = pclat10) %>%
    filter(map.where('county', clon, clat) %in% surcounty$polyname) %>%
    right_join(surcounty, by = c('fips' = 'adjfips')) %>%
    mutate(fips = as.character(fips))

## map data
cmap <- map_data('county') %>%
    mutate(polyname = region %+% ',' %+% subregion) %>%
    left_join(get(data(county.fips)) %>%
              mutate(polyname = as.character(polyname)),
              by = 'polyname') %>%
    mutate(fips = sprintf('%05d', fips)) %>%
    filter(fips %in% surcounty$fips) %>%
    left_join(surcounty %>% select(fips, clon, clat), by = 'fips')

## nashville state community college
nscc <- read_csv(ddir %+% 'analysis_oap.csv') %>%
    filter(unitid == 221184, year == 2012) %>%
    select(lon, lat)

points <- bind_rows(surcounty %>%
                    select(lon = clon, lat = clat) %>%
                    mutate(group = 'Broadband measure'),
                    nscc %>%
                    mutate(group = 'Nashville State Community College')) %>%
    mutate(group = factor(group))

## add to cmap
cmap$nscc_lon <- nscc$lon
cmap$nscc_lat <- nscc$lat


## create map
m <- ggplot(cmap, aes(long, lat, group = group)) +
    geom_polygon(colour = 'black', fill = NA) +
    geom_segment(aes(x = nscc_lon, xend = clon,
                     y = nscc_lat, yend = clat),
                 linetype = 'dashed') +
    geom_point(aes(x = lon, y = lat, fill = group, shape = group),
               size = 5, data = points) +
    scale_shape_manual(values = c(16, 23)) +
    scale_fill_manual(values = c('black', vugold)) +
    theme(line = element_blank(),
          axis.text = element_blank(),
          axis.title = element_blank(),
          panel.background = element_blank(),
          plot.margin = unit(c(0,0,0,0),'lines'),
          legend.position = c(.22,.08),
          legend.key.size = unit(1, 'lines'),
          legend.text = element_text(size = 17),
          legend.title = element_blank())

## save
ggsave('broadband_weights.pdf',
       m,
       path = fdir,
       width = 10,
       height = 8)


## =============================================================================
## Marginal effect
## =============================================================================

files <- grep('sl_normal_full_pdw2_all_*', list.files('../../output/'), value = T)
df <- read_stan_csv(file.path('../../output', files))
params <- extract(df)
sl_beta <- params$beta

files <- grep('sl_normal_full_pdw2_download_*', list.files('../../output/'), value = T)
df <- read_stan_csv(file.path('../../output', files))
params <- extract(df)
sl_beta_dl <- params$beta

files <- grep('sl_normal_full_pdw2_upload_*', list.files('../../output/'), value = T)
df <- read_stan_csv(file.path('../../output', files))
params <- extract(df)
sl_beta_ul <- params$beta

files <- grep('sl_normal_full_pdw2_pcount_*', list.files('../../output/'), value = T)
df <- read_stan_csv(file.path('../../output', files))
params <- extract(df)
sl_beta_pc <- params$beta

files <- grep('vi_normal_full_pdw2_all_*', list.files('../../output/'), value = T)
df <- read_stan_csv(file.path('../../output', files))
params <- extract(df)
vi_beta <- params$beta

get_margin_quad <- function(sample_mat, x_range, ci = 95) {
    lo <- (1 - (ci / 100)) / 2
    hi <- 1 - lo
    out <- purrr::map(x_range,
                      ~ sample_mat[,1] + (2*sample_mat[,2]*.x)) %>%
        setNames(as.character(x_range)) %>%
        as_tibble() %>%
        gather(x, range) %>%
        group_by(x) %>%
        summarize(lo_ci = quantile(range, lo),
                  med = quantile(range, .5),
                  mean = mean(range),
                  hi_ci = quantile(range, hi),
                  gt0 = mean(range > 0)) %>%
        ungroup() %>%
        mutate(x = as.numeric(x),
               x = x + 1) %>%
        arrange(x)
    return(out)
}

get_margin_mult <- function(df, dl_mat, ul_mat, x_range, y_range, ci = 95) {
    lo <- (1 - (ci / 100)) / 2
    hi <- 1 - lo
    out <- purrr::map2(x_range, y_range,
                       ~ dl_mat[,1] + (2*dl_mat[,2]*.x)
                       + ul_mat[,1] + (2*ul_mat[,2]*.y)) %>%
        bind_cols() %>%
        setNames(as.character(x_range)) %>%
        gather(x, range) %>%
        group_by(x) %>%
        summarize(lo_ci = quantile(range, lo),
                  med = quantile(range, .5),
                  mean = mean(range),
                  hi_ci = quantile(range, hi),
                  gt0 = mean(range > 0)) %>%
        ungroup() %>%
        mutate(x = as.numeric(x),
               x = x + 1) %>%
        arrange(x)
    return(out)
}
x_range <- seq(0,10,.1)

sl_dl_ <- get_margin_quad(sl_beta_dl[,1:2], x_range) %>% mutate(type = 'dl')
sl_ul_ <- get_margin_quad(sl_beta_ul[,1:2], x_range) %>% mutate(type = 'ul')
sl_pc_ <- get_margin_quad(sl_beta_pc[,1:2], x_range) %>% mutate(type = 'pc')

write_csv(sl_dl_, path = file.path(ddir, 'sl_dl_solo_margin_table.csv'))
write_csv(sl_ul_, path = file.path(ddir, 'sl_ul_solo_margin_table.csv'))
write_csv(sl_pc_, path = file.path(ddir, 'sl_pc_solo_margin_table.csv'))

sl_dl <- get_margin_quad(sl_beta[,1:2], x_range) %>% mutate(type = 'dl')
vi_dl <- get_margin_quad(vi_beta[,1:2], x_range) %>% mutate(type = 'dl')
sl_ul <- get_margin_quad(sl_beta[,3:4], x_range) %>% mutate(type = 'ul')
vi_ul <- get_margin_quad(vi_beta[,3:4], x_range) %>% mutate(type = 'ul')
sl_pc <- get_margin_quad(sl_beta[,5:6], x_range) %>% mutate(type = 'pc')
vi_pc <- get_margin_quad(vi_beta[,5:6], x_range) %>% mutate(type = 'pc')

write_csv(sl_dl, path = file.path(ddir, 'sl_dl_margin_table.csv'))
write_csv(vi_dl, path = file.path(ddir, 'vi_dl_margin_table.csv'))
write_csv(sl_ul, path = file.path(ddir, 'sl_ul_margin_table.csv'))
write_csv(vi_ul, path = file.path(ddir, 'vi_ul_margin_table.csv'))
write_csv(sl_pc, path = file.path(ddir, 'sl_pc_margin_table.csv'))
write_csv(vi_pc, path = file.path(ddir, 'vi_pc_margin_table.csv'))

g <- ggplot(vi_dl, aes(x = x, y = med)) +
    geom_hline(aes(yintercept = 0), linetype = 'dashed') +
    geom_ribbon(aes(ymin = lo_ci, ymax = hi_ci), alpha = 0.3) +
    geom_line() +
    scale_x_continuous(breaks = 1:11) +
    scale_y_continuous(breaks = seq(-1,1,.1), limits = c(-0.5, 1),
                       labels = seq(-100, 100, 10)) +
    labs(x = 'Tiers of broadband speed: download',
         y = 'Percent change in number of students\n'%+%
             'taking some online courses') +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          panel.background = element_blank(),
          axis.line = element_line(colour = 'black'))

ggsave(filename = 'vi_dl.pdf',
               plot = g,
               device = 'pdf',
               path = fdir,
               width = 8,
               height = 4)

g <- ggplot(sl_dl, aes(x = x, y = med)) +
    geom_hline(aes(yintercept = 0), linetype = 'dashed') +
    geom_ribbon(aes(ymin = lo_ci, ymax = hi_ci), alpha = 0.3) +
    geom_line() +
    scale_x_continuous(breaks = 1:11) +
    scale_y_continuous(breaks = seq(-1,1,.1), limits = c(-0.5, 1),
                       labels = seq(-100, 100, 10)) +
    labs(x = 'Tiers of broadband speed: download',
         y = 'Percent change in number of students\n'%+%
             'taking some online courses') +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          panel.background = element_blank(),
          axis.line = element_line(colour = 'black'))

ggsave(filename = 'sl_dl.pdf',
               plot = g,
               device = 'pdf',
               path = fdir,
               width = 8,
       height = 4)

## COMBO: download + upload margin
x_range <- seq(0,10,.1)
get_y_range <- function(df, x_range) {
    y_range <- with(df, seq(min(pdw2_upload)/min(pdw2_download),
                            max(pdw2_upload)/max(pdw2_download),
                            length.out = length(x_range)))
    x_range * y_range
}
y_range <- get_y_range(df_oap, x_range)

comb_sl <- get_margin_mult(df, sl_beta[,1:2], sl_beta[,3:4], x_range, y_range)
write_csv(comb_sl, path = file.path(ddir, 'comb_sl_margin_table.csv'))
comb_vi <- get_margin_mult(df, vi_beta[,1:2], vi_beta[,3:4], x_range, y_range)

## write for later reference
write_csv(comb_vi, path = file.path(ddir, 'comb_vi_margin_table.csv'))

g <- ggplot(comb_sl, aes(x = x, y = med)) +
    geom_hline(aes(yintercept = 0), linetype = 'dashed') +
    geom_ribbon(aes(ymin = lo_ci, ymax = hi_ci), fill = 'red', alpha = 0.4) +
    geom_line() +
    scale_x_continuous(breaks = 1:11,
                       labels = 1:11 %+% '/' %+% round(get_y_range(df_oap, 1:11),2)) +
    scale_y_continuous(breaks = seq(-1,1,.1), limits = c(-0.5, 1),
                       labels = seq(-100, 100, 10)) +
    labs(x = 'Tiers of broadband speed: download / upload',
         y = 'Percent change in number of students\n'%+%
             'taking some online courses')

ggsave(filename = 'sl_dl_ul.pdf',
               plot = g,
               device = 'pdf',
               path = fdir,
               width = 8,
       height = 4)

g <- ggplot(comb_vi, aes(x = x, y = med)) +
    geom_hline(aes(yintercept = 0), linetype = 'dashed') +
    geom_ribbon(aes(ymin = lo_ci, ymax = hi_ci), fill = 'red', alpha = 0.4) +
    geom_line() +
    scale_x_continuous(breaks = 1:11,
                       labels = 1:11 %+% '/' %+% round(get_y_range(df_oap, 1:11),2)) +
    scale_y_continuous(breaks = seq(-1,1,.1), limits = c(-0.5, 1),
                       labels = seq(-100, 100, 10)) +
    labs(x = 'Tiers of broadband speed: download / upload',
         y = 'Percent change in number of students\n'%+%
             'taking some online courses')

ggsave(filename = 'vi_dl_ul.pdf',
               plot = g,
               device = 'pdf',
               path = fdir,
               width = 8,
       height = 4)

## =============================================================================
## END SCRIPT
## #############################################################################
