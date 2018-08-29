#!/bin/bash

# This script uses USGS ISIS3 routines to transform CTX EDRs into Level 1 products with the even/odd detector correction applied (hence "lev1eo"),

# Just a simple function to print a usage message
print_usage (){
echo ""
echo "Usage: $(basename $0) [-n] ProductID"
echo " Where <ProductID> is the PDS ProductID of the CTX EDR to be processed."
echo " The script will search for CTX an EDR in the current directory named ProductID.[IMG|img] before processing with ISIS."
echo " "
echo " Use of the optional -n flag will skip running spicefit."
echo " "
}

### Check for sane commandline arguments

if [[ "$#" -eq 0 ]] ; then
# print usage message and exit
print_usage
exit 0

elif [[ "$#" -gt 2 ]]; then
    echo "Error: Too Many Arguments"
    print_usage
    exit 1

   # Else use getopts to parse flags that may have been set
elif  [[ "$#" -le 2 ]]; then
    while getopts "n" opt; do
	case $opt in
	    n)
		n=1
		;;
	   \?)
                # Error to stop the script if an invalid option is passed
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
    # Remaining argument should be ProductID of EDR to process
    productID=$@
    
else
    print_usage
    exit 1
fi 


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


## Search for input file corresponding to ProductID
## If not found, print error and exit
if [[ -e "${productID}.IMG" ]]; then
    edr=${productID}.IMG
elif [[ -e "${productID}.img" ]]; then
    edr=${productID}.img
else
    echo "Error: Can't find "$PWD"/"${productID}".IMG or "$PWD"/"${productID}".img" 1>&2
    exit 1
fi

## ISIS Processing
#Ingest CTX EDRs into ISIS using mroctx2isis
mroctx2isis from=${edr} to=${productID}.cub

#Add SPICE data using spiceinit
spiceinit from=${productID}.cub

#Apply spicefit as appropriate based on input flag
if [[ "$n" -eq 1 ]]; then
   echo "WARNING: spicefit has been deactivated" 1>&2 
else
   #Smooth SPICE using spicefit
   spicefit from=${productID}.cub  
fi

#Apply photometric calibration using ctxcal
ctxcal from=${productID}.cub to=${productID}.lev1.cub

#Apply CTX even/odd detector correction, ctxevenodd
ctxevenodd from=${productID}.lev1.cub to=${productID}.lev1eo.cub

# Delete intermediate files
if [[ -e ${productID}.cub ]]; then
    rm ${productID}.cub
fi
if [[ -e ${productID}.lev1.cub ]]; then
    rm ${productID}.lev1.cub
fi
