#!/bin/bash

# Summary:
# Script to take Level 1eo CTX stereopairs, run them through NASA Ames stereo Pipeline.
# The script uses ASP's bundle_adjust tool to perform bundle adjustment on each stereopair separately.
# The script also runs ASP's cam2map4stereo.py on the input cubes, but the resulting map-projected cubes are only used as a convenient source of ideal projection information;
#  they're not actually used for stereo matching.  (This is a legacy of a much earlier version of the code and now is merely a lazy workaround for generating sensible map projection
#  information that is used later. This should really be done with a few calls to ISIS3's `camrange`. )
# This script is capable of processing many stereopairs in a single run and uses GNU parallel
#  to improve the efficiency of the processing and reduce total wall time.  


# Dependencies:
#      NASA Ames Stereo Pipeline
#      USGS ISIS3
#      GDAL
#      GNU parallel
# Optional dependency:
#      Dan's GDAL Scripts https://github.com/gina-alaska/dans-gdal-scripts
#        (used to generate footprint shapefile based on initial DEM)


# Just a simple function to print a usage message
print_usage (){
echo ""
echo "Usage: $(basename $0) -s <stereo.default> -p <productIDs.lis>"
echo " Where <productIDs.lis> is a file containing a list of the IDs of the CTX products to be processed."
echo " Product IDs belonging to a stereopair must be listed sequentially."
echo " The script will search for CTX Level 1eo products in the current directory before processing with ASP."
echo " "
echo "<stereo.default> is the name and absolute path to the stereo.default file to be used by the stereo command."
}

### Check for sane commandline arguments

if [[ $# = 0 ]] || [[ "$1" != "-"* ]]; then
# print usage message and exit
print_usage
exit 0

   # Else use getopts to parse flags that may have been set
elif  [[ "$1" = "-"* ]]; then
    while getopts ":p:s:" opt; do
	case $opt in
	    p)
		prods=$OPTARG
		if [ ! -e "$OPTARG" ]; then
        	    echo "$OPTARG not found" >&2
                    # print usage message and exit
                    print_usage
        	    exit 1
                fi

		;;
	    s)
		config=$OPTARG
		if [ ! -e "$OPTARG" ]; then
        	    echo "$OPTARG not found" >&2
                    # print usage message and exit
                    print_usage
        	    exit 1
                fi
                # Export $config so that GNU parallel can use it later
                export config=$OPTARG
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


if [[ -e "stereopair.lis" ]]; then
    # Store the names of the Level 1 EO cubes in variables
    L=$(awk 'NR==1 {print($1".lev1eo.cub")}' stereopair.lis)
    R=$(awk 'NR==1 {print($2".lev1eo.cub")}' stereopair.lis)

    # If one or both of the input cubes are not found, print error and exit
    if [[ ! -e $L ]] || [[ ! -e $R ]]; then
	echo "One or more input cubes not found" 1>&2
	exit 1
    fi
    
else
    echo $PWD"/stereopair.lis Not Found" 1>&2
    exit 1
fi


# If we've made it this far, commandline args look sane and specified files exist

# Script assumes that the subdirectories for each stereopair are within the current working directory
# Store the working directory in a variable
workdir=${PWD}

    # Check that ISIS has been initialized by looking for pds2isis,
    #  if not, initialize it
    if [[ $(which pds2isis) = "" ]]; then
        echo "Initializing ISIS3"
        source $ISISROOT/scripts/isis3Startup.sh
    # Quick test to make sure that initialization worked
    # If not, print an error and exit
       if [[ $(which pds2isis) = "" ]]; then
           echo "ERROR: Failed to initialize ISIS3" 1>&2
           exit 1
       fi
    fi

######

    date

##  Run ALL stereo in series for each stereopair using `parallel_stereo`
# This is not the most resource efficient way of doing this but it's a hell of a lot more efficient compared to using plain `stereo` in series
for i in $( cat stereodirs.lis ); do
    
    cd ${workdir}/$i
    # Store the names of the Level1 EO cubes in variables
    L=$(awk '{print($1".lev1eo.cub")}' stereopair.lis)
    R=$(awk '{print($2".lev1eo.cub")}' stereopair.lis)

    # Run ASP's bundle_adjust on the given stereopair
    echo "Begin bundle_adjust on "$i" at "$(date)
    bundle_adjust $L $R -o adjust/ba
    echo "Finished bundle_adjust on "$i" at "$(date)
    
    # Note that we specify ../nodelist.lis as the file containing the list of hostnames for `parallel_stereo` to use
    # You may wish to edit out the --nodes-list argument if running this script in a non-SLURM environment
    # See the ASP manual for information on running `parallel_stereo` with a node list argument that is suitable for your environment

    # We break parallel_stereo into 3 stages in order to optimize resource utilization. The first and third stages let parallel_stereo decide how to do this.
    # For the second stage, we specify an optimal number of processes and number of threads to use for multi-process and single-process portions of the code.
    # By default, we assume running on a machine with 16 cores. Users should tune this to suit their hardware.

    echo "Begin parallel_stereo on "$i" at "$(date)
    
    # stop parallel_stereo after correlation
    parallel_stereo --nodes-list=../nodelist.lis --stop-point 2 $L $R -s ${config} results_ba/${i}_ba --bundle-adjust-prefix adjust/ba

    # attempt to optimize parallel_stereo for running on 16-core machines for Steps 2 (refinement) and 3 (filtering)
    # Users should customize the number of processors, threads for multiprocessing and threads for single processing to values that suit their hardware
    parallel_stereo --nodes-list=../nodelist.lis --processes 4 --threads-multiprocess 7 --threads-singleprocess 28 --entry-point 2 --stop-point 4 $L $R -s ${config} results_ba/${i}_ba --bundle-adjust-prefix adjust/ba

    # finish parallel_stereo using default options for Stage 4 (Triangulation)
    parallel_stereo --nodes-list=../nodelist.lis --entry-point 4 $L $R -s ${config} results_ba/${i}_ba --bundle-adjust-prefix adjust/ba
    
    cd ${workdir}
    echo "Finished parallel_stereo on "$i" at "$(date)
done


date
