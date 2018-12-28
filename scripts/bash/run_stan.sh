#!/bin/bash

# command line arguments
STAN_EXE=$1
DATA_DIR=$2
MOD_TYPE=$3
DATA_TYPE=$4
OUTD=$5
BB_OPTS_VAL=$6
R_DIR=$7

# name of Stan executable
STAN_NME=$(basename $STAN_EXE)

# temporary directory for Stan Rdump data files
TMP_DIR=${DATA_DIR}/tmp
mkdir -p ${TMP_DIR}

# array of broadband values
if [ $BB_OPTS_VAL = 'all' ]; then

    BB_OPTS=(pdw2_all)

elif [ $BB_OPTS_VAL = 'single' ]; then
    BB_OPTS=(pdw2_download
	     pdw2_upload
	     pdw2_pcount)

elif [ $BB_OPTS_VAL = 'both' ]; then
    
    BB_OPTS=(pdw2_download
    	     pdw2_upload
    	     pdw2_pcount
	     pdw2_all)

fi

# convert array to list that R can read
BB_LIST=$(printf ",%s" "${BB_OPTS[@]}")
BB_LIST=${BB_LIST:1}		# drops leading comma

# create datasets
Rscript $R_DIR/make_stan_data.R $MOD_TYPE $BB_LIST $DATA_DIR/ $TMP_DIR/

# do analysis using each dataset
for bb in "${BB_OPTS[@]}"
do
    if [ $DATA_TYPE = 'full' ]; then
	echo "Full dataset"
	DATA=${TMP_DIR}/${MOD_TYPE}_full_${bb}.R.data
	OUTN=${MOD_TYPE}_full_${bb}

	for i in {1..4}
	do
	    ./$STAN_EXE sample random seed=100605 \
			id=$i data file=$DATA \
			output file=${OUTD}/${OUTN}_$i.csv &
	done
	wait
    fi

    if [ $DATA_TYPE = 'two' ]; then
	echo "Two-year only dataset"
	DATA=${TMP_DIR}/${MOD_TYPE}_two_${bb}.R.data
	OUTN=${MOD_TYPE}_two_${bb}
	for i in {1..4}
	do
	    ./$STAN_EXE sample random seed=100605 \
			id=$i data file=$DATA \
			output file=${OUTD}/${OUTN}_$i.csv &
	done
	wait
    fi

    if [ $DATA_TYPE = 'sens' ]; then
	echo "Sensitivity analyses"
	DATA=${TMP_DIR}/${MOD_TYPE}_sens_${bb}.R.data
	OUTN=${MOD_TYPE}_sens_${bb}
	for i in {1..4}
	do
	    ./$STAN_EXE sample random seed=100605 \
			id=$i data file=$DATA \
			output file=${OUTD}/${OUTN}_$i.csv &
	done
	wait
    fi
done

# delete temporary directory
rm -r ${TMP_DIR}
