#!/bin/bash

# directory NBM data release zip files
zip=$1

# output directory
out=$2

# location of other bash scripts
bdir=$3

# set broadband database
db=${out}/bb.db

# files
zf_array=(All-NBM-CSV-June-2012
	  All-NBM-CSV-June-2013
	  All-NBM-CSV-June-2014)

# create temporary directory
mkdir ${zip}/tmp
tmpdir=$zip/tmp

for i in "${zf_array[@]}";
do

    # get final table name
    ftn="${i//-/_}"
    ftn=$(echo $ftn | cut -d'_' -f 4 -f 5)

    echo "-------------------------------------------"
    echo "$i"
    echo "Final table name: $ftn"
    echo "-------------------------------------------"

    # grab address and census block file names
    address_file=$(lsar $zip/$i.zip | grep -i "Address")
    csblock_file=$(lsar $zip/$i.zip | grep -i "CBLOCK")

    # loop through each area type
    for j in $address_file $csblock_file;
    do

	# get zipped version of file and unzip
	echo "Unzipping ${j}..."
	unar -o $tmpdir $zip/$i.zip $j

	# get subdirectory name
	subdir=$(ls $tmpdir)

	# get file name
	z=$(ls $tmpdir/$subdir | grep -i "\.zip$")

	# unzip actual file to get CSV
	unar -o $tmpdir $tmpdir/$subdir/$z

	# get file name
	f=$(ls $tmpdir | grep -i -E "\.txt$|\.csv$")

	# get table name (change - to _ b/c SQL doesn't like - in names)
	t=${f%.*}
	t="${t//-/_}"

	# import csv file into database
	echo "Importing $f into $db"
	${bdir}/bb_table_create.sh -d $db -f $tmpdir/$f

	# clean raw imported table
	echo "Cleaning $t"
	${bdir}/bb_table_clean.sh -d $db -t $t

	# clean
	rm -r $tmpdir/$subdir $tmpdir/$f

	# save table names for final merging
	if [[ $j == $address_file ]]; then
	    t1=$t
	else
	    t2=$t
	fi

    done;

    # merge tables and get one value for each census block
    ${bdir}/bb_db_clean.sh -d $db -f $t1 -s $t2 -n $ftn

done;

