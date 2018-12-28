################################################################################
##
## <PROJ> Dissertaion utility functions (R)
## <FILE> utils.R
## <AUTH> Benjamin Skinner
## <INIT> 28 August 2016
##
################################################################################

## quick paste
`%+%` <- function(a,b) paste(a, b, sep = '')

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
