#!/bin/bash

## Part of asp_scripts
## Run ASP's bundle_adjust tool on a pair of CTX Level 1 EO cubes.
## Script expects there to be a file "stereopair.lis" in the current directory that contains a space-separated list of CTX ProductIDs
## 

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

# Run ASP's bundle_adjust on the given stereopair
echo "Begin bundle_adjust on "$i" at "$(date)
bundle_adjust --threads 14 $L $R -o adjust/ba
echo "Finished bundle_adjust on "$i" at "$(date)
