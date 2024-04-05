#! /usr/bin/env bash
set -eux


cd ./prepchem_NC.fd/process-obs/FV3/gbbepx2netcdf/

echo " Building ... prepchem to convert binary to NetCDF"

sh mk-hera.sh
cp mkncgbbepx.exe ../../../../../exec/mkncgbbepx
