#!/bin/bash

# Author: David P. Mayer
# Email: dpmayer@uchicago.edu
# First version released to public: 15 February 2015

## CTX Downloader ##
#
# Usage: ctx_downloader.sh [-s|i] <file>
#  Where <file> contains a list of CTX Product IDs
#  Default behavior is to download CTX EDRs from the PDS Imagaing Node
#   and corresponding footprint shapefiles from the PDS Geoscience Node
#  Use -i to download EDRs only
#  Use -s to download shapefiles only
#
# The primary purpose of this script is to facilitate bulk downloads of Mars Reconnaissance Orbiter Context Camera (CTX) image data from the Planetary Data System (PDS).
# The script will first identify the most recent cumulative index table (cumindex.tab) from the PDS and scan through it to determine which data volumes the products of interest belong to.
# By default, the script will also download ESRI shapefiles outlining the image footprints from the PDS Geoscience Node and place them in a subdirectory named "footprints". The shapefiles
# are downloaded as gzipped tarballs (*.tar.gz).
# 
##

## Define 2 main functions of the script

# Function to identify and parse latest cumindex.tab for CTX EDRs, then extract URLs of desired EDRs. No file is written to disk.
ctx_get_mrox (){
urlprefix="http://pds-imaging.jpl.nasa.gov/data/mro/mars_reconnaissance_orbiter/ctx/"

# Structure of the function:
# wget index of root of CTX data on PDS | grep list of CTX data volume subdirs | get name/number of most recent CTX data volume (will be listed last in index) | awk to build wget command | run wget command to return contents of most recent cumindex.tab | print columns 1 and 2 of cumindex.tab | strip out quotation marks | change part of the path to EDR to lowercase | grep lines matching the ProductIDs of interest

wget -qO- $urlprefix | grep -o mrox_[0-9][0-9][0-9][0-9]/ | gawk 'END{print}' | gawk '{print("wget -qO- http://pds-imaging.jpl.nasa.gov/data/mro/mars_reconnaissance_orbiter/ctx/"$1"index/cumindex.tab")}' | sh | gawk -F "," '{print $1 $2}' | sed 's/\"//g' | sed 's/MROX_\(....\)DATA/\/mrox_\1\/data/1' | grep -f $productIDs

}

ctx_build_urls (){
    gawk '{print("wget http://pds-imaging.jpl.nasa.gov/data/mro/mars_reconnaissance_orbiter/ctx"$1" http://ode.rsl.wustl.edu/mars/datafile/shapefiles/mro-m-ctx-2-edr-l0-v1"$1)}' | gawk '{print $1" "$2" " tolower($3)}' | sed 's/\.img/_img.tar.gz/1'

}

if [[ $# = 0 ]]; then
    echo " "
    echo "Usage: ctx_downloader.sh [-i|s] <file>"
    echo "Where <file> contains a list of CTX Product IDs"
    echo "Default behavior is to download CTX EDRs from the PDS Imagaing Node"
    echo " and corresponding footprint shapefiles from the PDS Geoscience Node"
    echo "Options:"
    echo "    -i Download EDRs only"
    echo "    -s Download shapefiles only"
    exit 1

    # If first argument doesn't look like a flag, assume it's a file containing Product IDs and attempt to download EDRs and shapefiles
elif [[ "$1" != "-"* ]]; then
    productIDs=$1
    # Quick test to see if the file exists
    if [ ! -e "$1" ]; then
	echo "$1 not found"
	exit 1
    fi
    ctx_get_mrox | ctx_build_urls | sh
    exit
   # Else use getopts to parse any flags that may have been set
elif  [[ "$1" = "-"* ]]; then
    while getopts ":s:i:" opt; do
	case $opt in
	    s)
		productIDs=$OPTARG
		if [ ! -e "$OPTARG" ]; then
        	    echo "$OPTARG not found"
        	    exit 1
                fi
		ctx_get_mrox | ctx_build_urls | gawk '{print $1" "$3}' | sh
		exit
		;;
	    i)
		productIDs=$OPTARG
		if [ ! -e "$OPTARG" ]; then
        	    echo "$OPTARG not found"
        	    exit 1
                fi
		ctx_get_mrox | ctx_build_urls | gawk '{print $1" "$2}' | sh
		exit
		;;
	   \?)
                # Error to stop the script if an invalid option is passed
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
            :)
                # Error to prevent script from continuing if flag is not followed by at least 1 argument
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
   done
fi 
