################################################################################
##
## [ PROJ ] Open access broadband
## [ FILE ] utils.R
## [ AUTH ] Benjamin Skinner: @btskinner
## [ INIT ] 28 August 2016
##
################################################################################

## quick paste
`%+%` <- function(a,b) paste(a, b, sep = '')
`%_%` <- function(a,b) paste(a, b, sep = '_')

## check proportion missing
## https://gist.github.com/stephenturner/841686
propmiss <- function(dataframe) {
	m <- sapply(dataframe, function(x) {
		data.frame(
			nmiss=sum(is.na(x)),
			n=length(x),
			propmiss=sum(is.na(x))/length(x)
		)
	})
	d <- data.frame(t(m))
	d <- sapply(d, unlist)
	d <- as.data.frame(d)
	d$variable <- row.names(d)
	row.names(d) <- NULL
	d <- cbind(d[ncol(d)],d[-ncol(d)])
	return(d[order(d$propmiss), ])
}

## check if file exists and then download if not
check_get <- function(file, path, url, mode = 'w') {
    if (!file.exists(file.path(path, file))) {
        download.file(url = url,
                      destfile = file.path(path, file),
                      mode = mode)
    } else {
        message(file.path(path, file) %+% ' already exists!')
    }
}

## lon/lat to county fips
## h/t http://stackoverflow.com/a/8751965
latlong2county <- function(points_tbl) {

    require(sp)
    require(maps)
    require(maptools)

    ## set coord system
    crs <- CRS('+proj=longlat +datum=WGS84')

    ## get fips data for match
    fips <- get(data(county.fips)) %>%
        mutate(fips = sprintf('%05d', fips),
               polyname = as.character(polyname)) %>%
        tbl_df()

    ## get county polygons data w/o mapping
    counties <- map('county', fill = TRUE, col = 'transparent', plot = FALSE)

    ## set names as IDS
    IDs <- counties$names

    ## convert counties to spatial polygon
    counties_sp <- map2SpatialPolygons(counties, IDs = IDs, proj4string = crs)

    ## convert points to a spatial points object
    pointsSP <- SpatialPoints(points_tbl %>%
                              select(x = lon, y = lat) %>%
                              data.frame(),
                              proj4string = crs)

    ## use 'over' to get _indices_ of the Polygons object containing each point
    indices <- over(pointsSP, counties_sp)

    ## return the state names of the polygons object containing each point
    countyNames <- sapply(counties_sp@polygons, function(x) x@ID)
    match <- countyNames[indices]

    ## add to tbl
    out <- points_tbl %>%
        mutate(polyname = match) %>%
        left_join(fips, by = 'polyname')

    return(out)
}

## get marginal with quadratic
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

## get marginal for two base / two quadratics
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

## get a y-axis range based on x-axis range
get_y_range <- function(df, x_range) {
    y_range <- with(df, seq(min(pdw2_upload)/min(pdw2_download),
                            max(pdw2_upload)/max(pdw2_download),
                            length.out = length(x_range)))
    x_range * y_range
}

## -----------------------------------------------------------------------------
## END SCRIPT
################################################################################
