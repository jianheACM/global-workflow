#!/usr/bin/env bash
set -eux

# Detect current HPC system
host=$(hostname -s)

case "$host" in
    hfe*|hecflow*|hera*)
        machine="hera"
        ;;
    ufe*|uecflow*|ursa*)
        machine="ursa"
        ;;
    *)
        echo "ERROR: Unsupported HPC system: $host"
        exit 1
        ;;
esac

echo "Building on $machine ($host) ..."

cd ./prepchem_NC.fd/process-obs/FV3/gbbepx2netcdf/

# Select machine-specific build script
bash "mk-${machine}.sh"

mkdir -p ../../../../../exec
# Copy executable
cp mkncgbbepx.exe ../../../../../exec/mkncgbbepx

