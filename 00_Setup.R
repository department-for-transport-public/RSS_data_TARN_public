################################################################################
# LINKING STATS19 AND TARN: SETUP
################################################################################

#This initial script loads required libraries and specifies folder and file names where data files are located
#A number of pre-specified lookups are loaded in from CSV/Excel files 

################################################################################

## INSTALL PACKAGES

#Load the following libraries

library(readxl) #to import data from Excel
library(tidyverse) #general data manipulation tools, includes dplyr, ggplot2, tidyr, stringr
library(lubridate) #for working with date variables (tidyverse but not loaded as core library)


################################################################################

## SPECIFY FOLDER 

#Specify a folder which will contain all the input data required 
#This code assumes that input data will be loaded from flat files rather than (e.g.) directly from databases

folder <- 
  file.path(
    "Data",
    fsep = "/"
  )

################################################################################

## SPECIFY DATA FILENAMES

#These input files should all be located within the Data folder (unless otherwise specified)
#Within this project, sample/dummy files have been loaded to show the format of the data - these should allow the code to run but will not produce meaningful results

data_tarn <- "Data_TARN_dummy.xlsx"  #this is made up data, 10 records, showing the format of the TARN data used (without postcode information)
data_tarn_amendment <- "TARN_amendments_template.xlsx"  #this is a blank template showing the format for reading in any amendments required to road user type in TARN
data_stats19 <- "Data_STATS19_sample.xlsx" #this is a sample of real STATS19 open data, 100 rows, without the postcode information, to show the format of the file

lookup_probabilities <- "Lookup_u_probabilities.xlsx" #probabilities of agreement on linkage variables (full file)
lookup_postcode <- "Lookup_postcode_sample.csv"  #this is a sample of the postcode lookup, 10 records only, showing the file format
lookup_postcode_district <- "Lookup_postcode_district.xlsx" #postcode districts with Eastings and Northings added (full file)

matches_review <- "Manual_review_template.xlsx" #this is a blank template showing the format for reading in any amendments required as a result of manual review

#Also specify names for saving outputs

save_match_best <- "Output_best_matches.xlsx"
save_match_TARN <- "Output_TARN_outcome.xlsx"

################################################################################

## LOAD LOOKUP FILES 

#These are files other than the data which are used in the matching process 
#Read in from pre-prepared spreadsheets 

#Postcode location lookups 
#These list respectively full postcodes and postcode districts, with a lookup to Easting/Northing based on centroid
#For districts, this is taken as the average across all constituent postcodes
#Also identify valid districts 

postcode <- read.csv(paste0(folder,"/",lookup_postcode), header = FALSE) %>% 
  dplyr::rename("Fullcode_ONS_formatch" = V1,"Fullcode_ONS" = V2,"Easting_ONS" = V3,"Northing_ONS"=V4)
postcode_district <- readxl::read_excel(paste0(folder,"/",lookup_postcode_district), sheet = "District")
postcode_district_valid <- dplyr::mutate(select(postcode_district, District), valid = 1) 

#'U probabilities'
#These are files listing Pr(agreement on matching variable, given records are not matched)
#Mostly calculated based on frequencies within STATS19 (the larger dataset here)

U_age <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_age")
U_sex <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_sex")
U_time <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_time")
U_distance <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_distance")
U_class <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_class")
U_type <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_type")
U_severity <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_severity")
U_hospital <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_hospital")
U_district <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_district")
U_date <- readxl::read_excel(paste0(folder,"/",lookup_probabilities), sheet = "U_date")

################################################################################

## RUN SCRIPTS

source("01_Prepare_TARN_data.R") #runs quickly
source("02_Prepare_STATS19_data.R") #runs quickly

source("03_linking.R") #takes 1hr+ to run

################################################################################
