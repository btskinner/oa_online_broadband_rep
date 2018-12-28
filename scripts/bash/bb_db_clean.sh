#!/bin/bash

# ==============================================================================
# SET OPTIONS
# ==============================================================================

usage()
{
    cat <<EOF
 
 PURPOSE:

 This script makes final database file.

 USAGE: 

 $0 <arguments>

 ARGUMENTS:
    [-d]       Broadband database
    [-f]       Broadband table name (first)
    [-s]       Broadband table name (second)
    [-n]       Final table name



 EXAMPLE:
 
 ./bb_db_clean.sh -d bb.sqlite -f NATIONAL_NBM_Address_Street_CSV_JUN_2014 /
                               -s NATIONAL_NBM_CBLOCK_CSV_JUN_2014 /
                               -n June_2014

EOF
}

# argument flags
d_flag=0
f_flag=0
s_flag=0
n_flag=0

while getopts "hd:f:s:n:" opt;
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
	f)
	    f_flag=1
	    f=$OPTARG
	    ;;
	s)
	    s_flag=1
	    s=$OPTARG
	    ;;	
	n)
	    n_flag=1
	    n=$OPTARG
	    ;;
	\?)
	    usage
	    exit 1
	    ;;
    esac
done

# check for missing arguments
if (( $d_flag==0 )) || (( $f_flag==0 )) || (( $s_flag==0 )) || (( $n_flag==0 )); then
    echo "Missing one or more arguments"
    usage
    exit 1
fi

# ==============================================================================
# SQL COMMANDS
# ==============================================================================
 
sql=$(cat <<EOF

-- -----------------------------------------------
-- create temp table
-- -----------------------------------------------

-- drop table if it exists	       
DROP TABLE IF EXISTS temp;

CREATE TABLE temp
(
fips       character varying(12),
mcount     smallint,
pcount     smallint,
download   smallint,
upload     smallint
);

-- -----------------------------------------------
-- move selected columns into temp table
-- -----------------------------------------------

INSERT INTO temp(fips, mcount, pcount, download, upload)
SELECT 
fips,
mcount,
pcount,
download,
upload
FROM $f;

INSERT INTO temp(fips, mcount, pcount, download, upload)
SELECT 
fips,
mcount,
pcount,
download,
upload
FROM $s;

-- -----------------------------------------------
-- drop original tables
-- -----------------------------------------------

DROP TABLE $f;
DROP TABLE $s;

-- -----------------------------------------------
-- create final table
-- -----------------------------------------------

-- drop table if it exists	       
DROP TABLE IF EXISTS $n;

CREATE TABLE $n
(
fips       character varying(12),
mcount     smallint,
pcount     smallint,
download   smallint,
upload     smallint
);

INSERT INTO $n
SELECT
fips as fips,
sum(mcount) as mcount,
sum(pcount) as pcount,
round(sum(mcount * download) / sum(mcount), 3) as download,
round(sum(mcount * upload) / sum(mcount), 3) as upload
FROM temp
GROUP BY fips
ORDER BY fips;

-- -----------------------------------------------
-- drop temp table
-- -----------------------------------------------
	       
DROP TABLE temp;

-- -----------------------------------------------
-- show first 10 rows and count
-- -----------------------------------------------

.headers on
SELECT * FROM $n LIMIT 10;
SELECT count(*) from $n;

EOF
	 )

# ==============================================================================
# RUN
# ==============================================================================

echo "$sql" | sqlite3 $d

# ------------------------------------------------------------------------------
# END
# ==============================================================================

