# Dataset info: 
#https://cds.climate.copernicus.eu/datasets/sis-hydrology-meteorology-derived-projections?tab=download
# request_id: "916d3a4e-52a3-44d8-98be-a1168e689b2a"
# product_type: "Essential Climate Variables"
# variable: "Precipitation"
# processing_type: "Bias corrected"
# variable_type: "Absolute values"
# time_aggregation: "Daily"
# horizontal_resolution: "5 km"
# experiment: "RCP 8.5"
# regional_climate_model:
#   name: "RACMO22E"
#   institution: "KNMI"
#   country: "Netherlands"
# global_climate_model:
#   name: "HadGEM2-ES"
#   institution: "UK Met Office"
#   country: "UK"
# ensemble_member: "r1i1p1"
# period:
#   start_year: 2030
#End year = 2040 

#Projection
#Lambert azimuthal equal area and rotated grid


#################################################################
# Script start: 
#https://rspatial.org/index.html
#https://cds.climate.copernicus.eu/datasets/sis-hydrology-meteorology-derived-projections?tab=overview
# control flow (if, else,next etc): https://cran.r-project.org/doc/manuals/r-release/R-lang.html#Control-structures
# more information on error handling : https://adv-r.hadley.nz/conditions.html

# Attempt at automating the processing of my .nc files 2041-2080 Pr data 
# complete with error wraps to prevent crashes during full run through, this is my first attempt at trying to automate a script to process multiple files rather than doling it manually 
# this should hopefully halp me automate it in python when i want to replicate the model, except using machine learning mechanism instead of the gpd (or ML+ GPD)

# Starting try will process years 2041 -45 as a test run. Then 46-80
# Super important to be very careful with memory dumping as . nc files are super intense 
# fit error checks on each to avoid crashes and stops the whole loop from getting stopped

#Following an ETL pipeline: Extract, transform and load - progression 
# in this case its optimised for geospatial data taken from the CDS datastore dataset: Temperature and precipitation climate impact indicators from 1970 to 2100 derived from European climate projections

# Remove all objects from the r workspace , careful not to delete needed objects 
rm(list = ls())

# Disk space running out caused r to crash at year 2071
# error: 'No space left on device' -> likely disk space, assuming temporary files as my HDD has more than enough space 
# Windirstat clearly shows its the temp file storage issue 
tempdir()
# Temp files stored on my SSD with a lot less space than my HDD, under setwd command redirect temp files to HDD if mid process to save progress 
# in this case as it stopped and CSVs are saved, just delete all of the files in the the Rtmp folder 

## In teh case of a crash use these lines to check whether the NetCDF file contains any data
#test <- rast("2072.nc", subds = "prAdjust")
#print(test)
#hasValues(test)

#############################

# Set WD
#setwd("F:/1 - Thesis/RCP 4.5 2030-2080 pr processing")

outputs<-"RCP2.6_2025-2080.csv.txt"
write("All years RCP2.6 2025-2080 data Batch Processing Output: \\n\\n", append=F, file = outputs)
# Load necessary libraries
library(terra)
library(sf)
library(ncdf4)
# library(ggplot2) #might need later for plot 

#before starting the loop, load up the shapefile 
# put a status message ion the console 
cat("Loading and transforming shapefile...\n")
shapefile_path <- "Gemeenten_Zuid_Holland_shp.shp"
#set the orioginal CRS 
shapefile_original_crs <- "EPSG:28992" # should be at Amersfoort / RD New 
# not assign target projecttion -> shapefule should do it automatically without reproj 
target_crs <- "EPSG:3035" # should now be ETRS89-extended / LAEA Europe -> 3035 

# to help with  seeing if there is a mistake in the process, use the trycatch function to notify me in the console if there has been an error in reading the shapefile  
shapefile <- tryCatch({
  st_read(shapefile_path)
}, error = function(e) {
  stop("Error reading shapefile: ", e$message)
})

# Its generally good practice to make sure the read CRS is what i am expecting -> over ZH Amersfoort (EPSG:28992)is logical 
# But because the data i am using is going to be projected in 3035 (also specified in the CDS data page)  i need to transform teh shapefile into 3035 to ensure the mask function i use later is compatible 
# if an NA comes up i might have to assign it first : st_crs(shapefile) <- shapefile_original_crs

shapefile <- st_transform(shapefile, crs = target_crs)
print(ext(shapefile)) # Check extent first time 

# define years to process
# This script is going to attempt to process 2041-2080 
start_year <- 2025
end_year <- 2080 # try with less years to start , make sure it works well 
# create a sequence from start to end year to inform the loop 
years <- seq(start_year, end_year)

#Loop through each year
for (year in years) {   # this is going to iterate over each year in the aforementioned sequence 
  cat("\nProcessing year:", year, "...\n")  # Print hte year that is currently being processed 
  nc_file_name <- paste0(year, ".nc") #  make the NetCDF file name, in this case the year being processes -> e.g 2041 
  csv_output_file_name <- paste0(year, "_precipitation_ts.csv") # add some context to the output file name 
  
  cat("NetCDF file:", nc_file_name, "\n")   # print the file name 
  
  #making sure the file exists -> if it doesnt it skips to the next year 
  if (!file.exists(nc_file_name)) {
    cat("File", nc_file_name, "does not exist. Skipping.\n")
    next # this next command is what will allow the force skip 
  }
  
  # Now i need to load the NetCDF directly as a SpatRaster -> this method is more computationally efficient
  r_full <- tryCatch({  # error wrapper to run error message rather than crashing 
    rast(nc_file_name, subds = "prAdjust")  # subds specified pradjust to be variable i want / rast from terra loads the .nc file as a spatraster 
  }, error = function(e) {  # wrap error 
    cat("Error loading raster for year", year, ":", e$message, "\n")  # error message, so i know which years havent been processed 
    return(NULL) # Returns NULL to skip this iteration's processing step in case of failiure 
  })
  #check if r_full is null, if it is the next command will skip to the next step 
  if (is.null(r_full)) {  
    next 
  }
  
  # open up the .nc file and extract metadata from the NetCDF to set the extent and time 
  data_nc <- tryCatch({ 
    nc_open(nc_file_name)   #  while rast only gives me the raster data, the nc_open command gives me access to everything in the file 
  }, error = function(e) {  # error wrap again in case of file corruptions, which could happen more freq with larger loops 
    cat("Error opening NetCDF file", nc_file_name, "for metadata: ", e$message, "\n")  
    return(NULL)
  })
  
  #Because nc files are so computationally intensive, teh running of a loop requires strict memory clearing and dumping, to make sure my desktop doesnt crash 
  if (is.null(data_nc)) {
    rm(r_full) # cleans up the loaded raster to free up memory 
    gc() # force garbage collection to clear theg memory not being used 
    next # next loop 
  }
  
  lon <- ncvar_get(data_nc, "lon")
  lat <- ncvar_get(data_nc, "lat") 
  tm <- ncvar_get(data_nc, "time")
  time_units_att <- ncatt_get(data_nc, "time", "units") # gets the time unit attribute 
  
  if (!time_units_att$hasatt) {  # error check to make sure the time attribute is present in the .nc file to skip it if it is missing 
    cat("Time units attribute not found in", nc_file_name, ". Skipping.\n")  
    nc_close(data_nc)  # close the file 
    rm(r_full, lon, lat, tm)  # remove the objects from R , save space 
    gc() # save mem again by dumping garbage collection  
    next 
  }
  time_units <- time_units_att$value  # store the time units string 
  
  # time management 
  time_origin_string <- sub("seconds since ", "", time_units) # subs removes the prefix and leaves the origin date -> "1970-01-01" 00:00:00
  # as.numeric to make sure treated as numbers, origin setting the reference date and UTS is just the common timezone used in climate data 
  time_dates <- as.POSIXct(as.numeric(tm), origin = time_origin_string, tz = "UTC") # convert to real datetime objects using POSIX as time was in seconds since before (that how .nc files hold time to save space)
  
  nc_close(data_nc) # Close nc file after collecting meta data 
  
  # Assigning time and extent 
  #
  tryCatch({ # error catch 
    time(r_full) <- time_dates # this time set the time extent at the same time on the raster 
    ext(r_full) <- c(min(lon), max(lon), min(lat), max(lat)) #  same ext line as old code , set the spatial extent 
  }, error = function(e) {  # wrap 
    cat("Error setting time or extent for year", year, ":", e$message, "\n")
    rm(r_full, lon, lat, tm, time_dates, data_nc) # clean 
    gc() # dump 
    next # skip next yr
  })
  
  # Setting the original CRS and reprojecting 
  # this section is the most intense for my desktop 
  crs(r_full) <- "EPSG:4326" #  while the CDS store says the projection is in 3035 (metres) the numbers show that it is in degrees WGS 84, tell r the data is in degres 1st 
  r_projected <- project(r_full, target_crs) #  now re project to EPSG: 3035 to match shp and datasets original CRS 
  
  # Crop the raster to teh extent of the .shp
  r_crop <- crop(r_projected, ext(shapefile))
  # mask it to the .shp boundaries 
  #use vect(shapefile) to turn sf object into a spatraster, this will ensure it can be masked 
  
  r_mask <- mask(r_crop, vect(shapefile))
  
  # Convert units from kg m-2 s-1 to mm/day (1 kg/m^2 = 1 mm; 86400 seconds/day)
  # The pr data is stored in kg in .nc files to save space and minimise errors 
  r_mask <- r_mask * 86400
  
  # calculates the spatial mean of pr ignoring the NA values 
  # this can be changed based on the aimof the script, for example, a binary classification can be used to calculate which grid tiles are over a specific threshold to increase res of results 
  # this can also be changed to sum rather thasn mean, to calc the total rainfall 
  precipitation_values <- global(r_mask, fun = "mean", na.rm = TRUE)
  
  # Make a df so that it can be exported in the CSV 
  precipitation_ts_df <- data.frame(
    Date = time(r_mask), # take time from teh masked raster 
    Precipitation_mm_day = precipitation_values$mean
  )
  
  # Write to CSV
  write.csv(precipitation_ts_df, csv_output_file_name, row.names = FALSE) # save data 
  cat("Successfully processed and saved data for year:", year, "to", csv_output_file_name, "\n") # add a sucess message to make sure  
  
  
  # Memory management: i want to clean up all large objects for this iteration, make sure r is clean for the next one, poor memory clearing could cause my desktop to crash AGAIN 
  rm(r_full, r_projected, r_crop, r_mask, precipitation_values, precipitation_ts_df, data_nc, lon, lat, tm, time_dates)
  gc() # more garbage collection
  
} # End of year loop

cat("\nAll years processed.\n")

#####################

# To achieve full automation from here i would need: 
# to automate CSV sorting into one df, done automatically once loop is finished 
# API at teh start so that the data extraction is automatic and seamless -> issues with my CDS API key need to be resolved 

#######################

# To comnbine all the 40 years of CSVs into one use dplyr 
# https://cran.r-project.org/web/packages/dplyr/dplyr.pdf

library(dplyr)# use it to combine data frames 
# state start and end year 
CSV_start_year <- 2025
CSV_end_year <- 2080
# create sequence for the years to iterate over 
years <- seq(CSV_start_year, CSV_end_year)

# Make sure the directory is the one where the csv files are stored, if it is'nt rerun the setwd command at the top of the script 

# To aggregate all of the CSV files into one CSV, im am going to create a large dataframe, albeit rather simple with only two columns date and preciopiataion (in teh GPD this will be renamed to observation to work in the cluster command )
# Once again i will run a loop with all CSVs, similar to what was done above, boosting the automated capacity of my script (avoids manual aggregation like i did fornthe last 10 years)
# first create the empty dataframe 
data_agg <- data.frame()
# start the loop 

for (year in years) {
  csv_file <- paste0(year, "_precipitation_ts.csv") # # line to detect the CSV file name existence. making sire it replicable for each year by adding year, _ -> generates the filename as a string 
  # check if file exists in dir
  if (file.exists(csv_file)) {   # if doesn't exist "else" wrap it later
    csv_data <- read.csv(csv_file) # read teh current years data 
    data_agg <- bind_rows(data_agg, csv_data)  #append all the data from the csv currently being read into data_agg, error came from the second variable needing to be called data (as its the new data being appended as the subject of the command)
  } else {
    cat("missing CSV for year:", year, "\n")
  }
}

# Now to write the new csv , row names =  false , can add them in myself when i check csv 
write.csv(data_agg, "Combined_RCP2.6_2025-2080.csv", row.names = FALSE)

# sucess confirmation messaage 
cat("Combined_RCP2.6_2025-2080.csv\n")

# CSV is going to be really long 
# to check if each year is there once 
data_agg$Date <- as.Date(data_agg$Date)  # date not converting properly, do again for data_agg 
expecter_years <- unique(format(data_agg$Date, "%Y")) 
# check if years are missing 
missing_years <- setdiff(years, expecter_years) # set diff finds the years in years that aren't in expected years 

# Final step of the automated process is to add a message to know whether a year is missing 
# two message options, either the first stating that all years are present and teh second showing which years are not there
# this will be useful in py version, for streamlining the troubleshooting of particular files and understanding the final status for future modelling 

if (length(missing_years) == 0) {  # if missing years is 0 then show txt below 
  cat("All years present\n")
} else {  # otherwise show which years are missing -> collapse = ", " is the format of the string of missing years 
  cat("Missing years:", paste(missing_years, collapse = ", "), "\n") # "\n" adds a line break so next output starts on new line in case i want to link with GPD script + structures in full auto 
} 

#########################
#because i first ran the code manually for the first 10 years, i need to add that in there too for RCP 8.5 

#######################
##########
# Final part of this processing script is a simple ggplot vis to check out the data and its distribution 
# read the csv created above which should be directly available in the wd 
# the GPD model script assigns the final csv as data, so use that for this one to help continuation 

data <- read.csv("Combined_RCP2.6_2025-2080.csv")
str(data)
summary(data)

data <- data[,1:2] # Keep only Date, Precipitation, Temperature # temp only for RCP 8.5 & covariance experiments 
# date format isn't correct , need it to be numerical and not chr 
# this is required for ggplot to work 
# troubleshooting article for FORMAT specification: https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/as.POSIX*

data$Date <- as.POSIXct(   # ggplot cant plot character strings (chr) , use format from ISO 8601 dates 
  data$Date,
  format = "%Y-%m-%d %H:%M:%S",  # Matches the new "1971-01-01 12:00:00"  ###  this needs to be changed proportional to the date numbers 
  tz = "UTC"
)

# verify if it worked with str
library(ggplot2)
Plot <- ggplot(data, aes(x = Date, y = Precipitation_mm_day)) +
  geom_line(color = "#FF6B6B", alpha = 1) +  # Solid coral line , "#4ECDC4" (turquoise), "#6A0572" (purple)
  labs(title = "Precipitation data for  RCP2.6 2025-2080", 
       x = "Date", 
       y = "Precipitation (mm/day)") +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white")) 

ggsave("Combined_RCP2.6_2025-2080.png", Plot, width = 12, height = 6)

# finally done automated processing, now start aggregating py libraries and assigning direct translations to replicate more computationally efficiently 
# from the ggplot, can see that there are significantly more exceedances this time, with the optimal threhsold last time sitting at around 30mm, for 5 years of data 