#!/bin/bash

# ==============================================================================
# SET OPTIONS
# ==============================================================================

usage()
{
    cat <<EOF
 
 PURPOSE:

 This script cleans and reduces US broadband sqlite database tables.

 USAGE: 

 $0 <arguments>

 ARGUMENTS:
    [-d]        Broadband database
    [-t]        Broadband table name

 EXAMPLE:
 
 ./bb_table_clean.sh -d bbdb.sqlite -t NBM-CBLOCK-CSV-December-2013

EOF
}

# argument flags
d_flag=0
t_flag=0

while getopts "hd:f:t:" opt;
do
    case $opt in
	h)
	    usage
	    exit 1
	    ;;
	d)
	    d_flag=1
	    d=$OPTARG
	    ;;
	t)
	    t_flag=1
	    t=$OPTARG
	    ;;
	\?)
	    usage
	    exit 1
	    ;;
    esac
done

# check for missing arguments
if (( $d_flag == 0 )) || (( $t_flag == 0 )); then
    echo "Missing one or more arguments"
    usage
    exit 1
fi

# ==============================================================================
# SQL COMMANDS
# ==============================================================================
 
sql=$(cat <<EOF

-- -----------------------------------------------
-- drop temp table if it exists
-- -----------------------------------------------

DROP TABLE IF EXISTS temp;

-- -----------------------------------------------
-- create temp table
-- -----------------------------------------------

CREATE TABLE temp
(
fips       character varying(15),
transtech  character varying(2),
frn        character varying(10),
download   smallint,
upload     smallint
);

-- -----------------------------------------------
-- move selected columns into temp table
-- -----------------------------------------------

INSERT INTO temp(fips, transtech, frn, download, upload)
SELECT 
fullfipsid,
transtech,
frn,
downloadspeed,
uploadspeed
FROM $t;

-- -----------------------------------------------
-- drop original table
-- -----------------------------------------------

DROP TABLE $t;

-- -----------------------------------------------
-- combine transtech categories
-- -----------------------------------------------

-- OLD   NEW    Description
-- 10    1      Asymmetric xDSL
-- 20    1      Symmetric xDSL
-- 30    2      Other Copper Wire
-- 40    2      Cable Modem - DOCSIS 3.0 Down
-- 41	 2      Cable Model - Other
-- 50	 3      Optical Carrier/Fiber to the End User
-- 60	 4      Satellite
-- 70	 5      Terrestrial Fixed - Unlicensed
-- 71	 5      Terrestrial Fixed - Licensed
-- 80	 6      Terrestrial Mobile Wireless
-- 90	 7      Electric Power Line
-- 0	 8      All Other

-- NB: all transtech to same
UPDATE temp SET transtech = 1;

-- -----------------------------------------------
-- substring fips to census block group
-- -----------------------------------------------

UPDATE temp SET fips = substr(fips,1,12);

-- -----------------------------------------------
-- create final table
-- -----------------------------------------------

CREATE TABLE $t
(
fips       character varying(12),
mcount     smallint,
pcount     smallint,
download   smallint,
upload     smallint
);

INSERT INTO $t
SELECT 
fips                    as fips,
count(transtech)        as mcount,
count(distinct frn)     as pcount,
round(avg(download),3)  as download,
round(avg(upload),3)    as upload
FROM temp
GROUP BY fips;

-- -----------------------------------------------
-- drop temporary table
-- -----------------------------------------------

DROP TABLE temp;

-- -----------------------------------------------
-- show first 10 rows and count
-- -----------------------------------------------

.headers on
SELECT * FROM $t LIMIT 10;
SELECT count(*) from $t;

EOF
	 )

# ==============================================================================
# RUN
# ==============================================================================

echo "$sql" | sqlite3 $d

# ------------------------------------------------------------------------------
# END
# ==============================================================================

