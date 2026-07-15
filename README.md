# Climate-data-automated-processing-pipeline

# Automated Processing of Climate Projection NetCDF Files

## Overview

This repository contains an automated R script designed to process climate projection NetCDF (.nc) files containing precipitation data from the **Copernicus Climate Data Store (CDS)**. The workflow extracts daily precipitation values, processes geospatial data, and generates time-series outputs for a defined region (Zuid-Holland, Netherlands).

The script implements a robust ETL (Extract, Transform, Load) pipeline with extensive error handling and memory management to enable batch processing of large climate datasets.

---

## Dataset Description

| Property | Value |
|----------|-------|
| **Source** | Copernicus Climate Data Store (CDS) |
| **Dataset** | Hydrology and Meteorology Derived Climate Projections |
| **Variable** | Precipitation |
| **Processing type** | Bias corrected |
| **Temporal resolution** | Daily |
| **Spatial resolution** | 5 km |
| **Climate experiment** | RCP 2.6 / RCP 8.5 |
| **Regional Climate Model** | RACMO22E (KNMI, Netherlands) |
| **Global Climate Model** | HadGEM2-ES (UK Met Office) |
| **Projection grid** | Lambert Azimuthal Equal Area (LAEA Europe – EPSG:3035) |

**Data:** The data was downloaded from this particular CDS site using the python API request code found in the txt file uploaded. https://cds.climate.copernicus.eu/datasets/sis-hydrology-meteorology-derived-projections?tab=download

**Data Size: ~300gb of space is needed for an initial manual install from CDS, the pipeline incorporates robust memory management so it does not exceed this amount. 

**Period:** 2025–2080

---

## Processing Pipeline Overview

The script follows a structured ETL data pipeline:


### 1. Extract
- Load NetCDF precipitation files year-by-year
- Retrieve spatial coordinates and temporal metadata
- Load the Zuid-Holland municipal shapefile

### 2. Transform
- Convert NetCDF raster data into SpatRaster objects
- Reproject raster layers to EPSG:3035
- Crop and mask raster data using the shapefile boundary
- Convert precipitation units from kg·m⁻²·s⁻¹ to mm/day
- Compute spatial mean precipitation values

### 3. Load
- Export yearly precipitation time series to CSV
- Combine yearly CSV files into a single aggregated dataset
- Perform integrity checks to detect missing years

---

## Prerequisites

### System Requirements
- **R** (version 4.0 or higher)
- Sufficient disk space for temporary files (NetCDF files are memory-intensive, 16gb RAM reccomended)


### Required R Packages

```r
install.packages(c(
  "terra",    # Raster and spatial data processing
  "sf",       # Shapefile and vector spatial data
  "ncdf4",    # NetCDF file interaction
  "dplyr",    # Data aggregation and manipulation
  "ggplot2"   # Visualization of processed time series
))
