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
    "~",
    "g","AFP","RLTDAll","STS","007 ROAD SAFETY STATISTICS","017 HOSPITAL DATA","0002 TARN_public",
    fsep = "/"
  )

################################################################################

## SPECIFY DATA FILENAMES

#These input files should all be located within the above specified folder

data_tarn <- "Data_TARN.xlsx"
data_tarn_amendment <- "Data_TARN_amendments.xlsx"
data_stats19 <- "Data_STATS19.xlsx"

lookup_probabilities <- "Lookup_u_probabilities.xlsx"
lookup_postcode <- "Lookup_postcode.csv"
lookup_postcode_district <- "Lookup_postcode_district.xlsx"

matches_review <- "Matches_ManualReview.xlsx"

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
