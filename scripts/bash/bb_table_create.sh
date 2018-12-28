#!/bin/bash

# ==============================================================================
# SET OPTIONS
# ==============================================================================

usage()
{
    cat <<EOF
 
 PURPOSE:

 This script puts US broadband data flat files in tables in a sqlite database.

 USAGE: 

 $0 <arguments>

 ARGUMENTS:
    [-d]        Broadband database
    [-f]        Raw broadband file

 EXAMPLE:
 
 ./bb_table_create.sh -d bbdb.sqlite -f NBM-CBLOCK-CSV-December-2013.CSV

EOF
}

# argument flags
d_flag=0
f_flag=0

while getopts "hd:f:" opt;
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
	    n=$(basename "$f")	# drop path
	    n=${n%.*}		# drop extension
	    n="${n//-/_}"	# replace - with _
	    
	    ;;
	\?)
	    usage
	    exit 1
	    ;;
    esac
done

# check for missing arguments
if (( $d_flag == 0 )) || (( $f_flag == 0 )); then
    echo "Missing one or more arguments"
    usage
    exit 1
fi

# ==============================================================================
# SQL COMMANDS (CAT FILES)
# ==============================================================================

# sql commands
sql=$(cat <<EOF

-- drop table if it exists	       
DROP TABLE IF EXISTS $n;

-- set options
.separator '|'
.headers on

-- IMPORT CSV FILE
.import $f $n

-- show first 10 rows
SELECT * FROM $n LIMIT 10;

-- count rows
SELECT count(*) FROM $n;

EOF
	)

# ==============================================================================
# RUN
# ==============================================================================

echo "$sql" | sqlite3 $d

# get number of lines from original file for comparison
rows=($(wc -l $f))
rows=$(( $rows - 1 ))
echo -e "\nOriginal file has $rows rows.\n"

# ------------------------------------------------------------------------------
# END
# ==============================================================================

