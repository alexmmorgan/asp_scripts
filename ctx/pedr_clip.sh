#!/bin/bash

## This is a standalone for now but the core functionality should be folded into a broader utility script for prepping the PEDR CSV for max-displacement estimation

## Usage:
## pedr_clip.sh <DTMID>
stereopair=$1

   # Test that a file named "stereopairs.lis" exists in the current directory
    if [ ! -d ${stereopair} ]; then
        echo ${stereopair}" not found"
        exit 1
    fi

# change into the directory for stereopair
cd $stereopair

#################################
## OLD METHOD OF GETTING WKT
# # Assume we already have extracted PEDR CSV for a series of CTX stereopairs
# # Build a VRT file for each CSV
#     # Get the name of the first map-projected cube listed in stereopairs.lis
#     cube=${1}.map.cub 
#################################


# Create a footprint shapefile of the initial DEM
#  This is extra messy because the exact path to the initial DEM will vary depending on whether we are processing Step 1 or Step 2 DEMs
#  Here we will assume a Step 2 DEM that was processed from map-projected, bundle_adjusted data:
dtmpath="results_map_ba/dem"

gdal_trace_outline ${dtmpath}/${stereopair}_map_ba-DEM.tif -ndv -32767 -erosion -out-cs en -ogr-out ${dtmpath}/${stereopair}_map_ba_footprint.shp

# Apply a -400 meter buffer to the corresponding footprint file
ogr2ogr -f "ESRI Shapefile" ${dtmpath}/${stereopair}_map_ba_footprint_buff.shp ${dtmpath}/${stereopair}_map_ba_footprint.shp -dialect sqlite -sql "select ST_buffer(Geometry,-400),FID from ${stereopair}_map_ba_footprint"

# Get projection info in WKT format from the DTM and send to a file
gdalsrsinfo -o wkt ${dtmpath}/${stereopair}_map_ba-DEM.tif > ${stereopair}_pedr.wkt

# Write a VRT for the PEDR CSV we're currently working on
echo "<OGRVRTDataSource>
 <OGRVRTLayer name=\"${stereopair}_pedr\">
 <SrcDataSource>${stereopair}_pedr.csv</SrcDataSource>
 <GeometryType>wkbPoint</GeometryType>
 <LayerSRS>${stereopair}_pedr.wkt</LayerSRS>
 <GeometryField encoding=\"PointFromColumns\" x=\"Easting\" y=\"Northing\"/>
 </OGRVRTLayer>
 </OGRVRTDataSource>" > ${stereopair}_pedr.vrt


# Clip the PEDR VRT using the buffered shapefile and write a new shapefile to disk
ogr2ogr -f "ESRI Shapefile" -clipsrc ${dtmpath}/${stereopair}_map_ba_footprint_buff.shp ${stereopair}_pedr_clip.shp ${stereopair}_pedr.vrt
