# Data

Except where noted, the following data files will be downloaded by
`get_data.R` called by the `makefile`:

## American Community Survey / Census

1. [Population](https://www2.census.gov/programs-surveys/popest/datasets/2010-2015/counties/totals/co-est2015-alldata.csv)  

### Already in repo

Because the following files come from the American Factfinder, they
have been included in the repo. If you want to download the files
yourself, here are the links:  

1. [Employment: state](https://factfinder.census.gov/bkmk/table/1.0/en/ACS/14_5YR/S2301/0100000US.04000)  
2. [Employment: county](https://factfinder.census.gov/bkmk/table/1.0/en/ACS/14_5YR/S2301/0100000US.05000.003)

Uncheck both download options when downloading and rename each `CSV`
file to add the suffix `_state` and `_county`, respectively.

## Broadband

These data files that cover the entire US come from the [National Broadband Map data
archive](https://www2.ntia.doc.gov/broadband-data). Though compressed,
they are large and will take time to download.

1. [2012](https://www2.ntia.doc.gov/files/broadband-data/All-NBM-CSV-June-2012.zip)  
2. [2013](https://www2.ntia.doc.gov/files/broadband-data/All-NBM-CSV-June-2013.zip)  
3. [2014](https://www2.ntia.doc.gov/files/broadband-data/All-NBM-CSV-June-2014.zip)  

**NB** Funding for the NBM expired in 2014 and the interactive map is
no longer available. As of this date (3 January 2019), the data files
can still be downloaded.

## Geographic

The following three files can be downloaded from the
[`btskinner/spatial`](https://github.com/btskinner/spatial) repo:  

1. [`stcrosswalk.csv`](https://raw.githubusercontent.com/btskinner/spatial/master/data/stcrosswalk.csv)  
2. [`county_centers.csv`](https://raw.githubusercontent.com/btskinner/spatial/master/data/county_centers.csv)  
3. [`neighborcounties.csv`](https://raw.githubusercontent.com/btskinner/spatial/master/data/neighborcounties.csv)  

The remaining files come from various US government sites:  

1. [Block group population centers](http://www2.census.gov/geo/docs/reference/cenpop2010/blkgrp/CenPop2010_Mean_BG.txt)  
2. [Rural-Urban Continuum Codes](https://www.ers.usda.gov/webdocs/DataFiles/53251/ruralurbancodes2013.xls)  
3. [Land area](http://www2.census.gov/prod2/statcomp/usac/excel/LND01.xls)  

## IPEDS

[IPEDS](https://nces.ed.gov/ipeds/) files are downloaded using a
modified version of [`downloadipeds.R`
script](https://github.com/btskinner/downloadipeds). The following
files are needed:  

* HD2012.zip
* HD2013.zip
* HD2014.zip
* IC2012.zip
* IC2013.zip
* IC2014.zip
* EFIA2012.zip
* EFIA2013.zip
* EFIA2014.zip
* EF2012A.zip
* EF2013A.zip
* EF2014A.zip
* EF2012B.zip
* EF2013B.zip
* EF2014B.zip
* EF2012A\_DIST.zip
* EF2013A\_DIST.zip
* EF2014A\_DIST.zip
* SFA1112.zip
* SFA1213.zip
* SFA1314.zip

## SHEEO

State appropriations by year come from the State Higher Education
Executive Office.

1. [Finance](http://www.sheeo.org/sites/default/files/State_by_State_Wave_Charts_FY15_0.xlsx)  

