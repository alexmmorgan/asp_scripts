#!/bin/bash


## Usage: 
## asp_ctx_step1_stage0.sh <config> <left ID> <right ID> <stereodir> <nodelist> <stage: {0..4}>

# Just a simple function to print a usage message
print_usage (){
    echo "Usage: asp_ctx_step1_stage0.sh <config> <left ID> <right ID> <stereodir> <nodelist> <stage: {0..4}>"
    echo " where <stage> is the ASP stage number to run"
}


    
## Check for correct number of arguments
if [[ $# = 0 ]]; then
    # print usage message and exit
    print_usage
    exit 0
elif [[ $# != 6 ]]; then
    # print usage message and exit with an error
    print_usage
    exit 1
fi

config=$1
L=$2
R=$3
id=$4
nodelist=$5
stage=$6

## Derived variables
Lcam=${L}.lev1eo.cub
Rcam=${R}.lev1eo.cub

## Gather inputs and verify that files/directories exist

## stereo config existence
if [ ! -e "$config" ]; then
    echo $config " not found"
    exit 1
fi

## stereodir existence
if [ -d "$id" ]; then
    cd ${id}
else
    echo ${id} " not found or not a directory"
    exit 1
fi

## input cube existence (implied by productIDs from commandline)
if [ ! -e "$Lcam" ]; then
    echo "Left image "$Lcam " not found"
    exit 1
fi

if [ ! -e "$Rcam" ]; then
    echo "Right image "$Rcam " not found"
    exit 1
fi

## Validate stage number
if ([ "$stage" -ge 0 ]  && [ "$stage" -le 5 ]) ; then
    stop=$(($stage + 1))
    echo "Running Stage "$stage
else
    # print_usage
    echo $stage " is not a valid stage number."
    echo "Acceptable values: 0, 1, 2, 3, 4, 5"
    # exit 1
fi


## Run parallel_stereo stage $stage
## Note that "--threads-single-process" is clamped to 14. This should only affect stages 0 and 3
parallel_stereo --nodes-list ${nodelist} --threads-singleprocess 14 --entry-point ${stage} --stop-point ${stop} ${Lcam} ${Rcam} -s ${config} results_ba/${id}_ba --bundle-adjust-prefix adjust/ba
