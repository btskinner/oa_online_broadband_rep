#!/bin/bash

# drop .stan from name
STANPATH=$PWD
STANFILE=$(basename $1 .stan)
BUILDDIR=$2
TARGETDIR=$3

# make executable
printf "\n"
printf "%0.s-" {1..80}
printf "\n"
printf "COMPILING: %s\n" $STANFILE
printf "%0.s-" {1..80}
printf "\n"
(cd /usr/local/cmdstan/ && make $STANPATH/$STANFILE)

# clean up
printf "\n"
printf "Moving *.hpp to %s and executable to %s\n\n" $BUILDDIR $TARGETDIR
mv ${STANFILE}.hpp ${STANPATH}/$BUILDDIR
mv $STANFILE ${STANPATH}/$TARGETDIR

