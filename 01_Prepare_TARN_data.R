################################################################################
# LINKING STATS19 AND TARN: PREPARE TARN DATA
################################################################################

#This script reads in the TARN data file, filters appropriately and adds additional 
#variables required for matching to STATS19

################################################################################

## READ IN TARN DATA

#In this case, the data is stored in an Excel file names 'Data_TARN.xlsx' 
#With column names as listed below - these are as provided by TARN

# Case ID	
# Age	
# Gender	
# Position in Vehicle	
# Outcome	
# Incident Location	
# Incident Description	
# Incident Date	
# Incident Time	
# Arrival Date	
# Arrival Time	
# Incident Post Code	
# Hospital Location	[this is a postcode sector]
# Home Post Code [first part only]

#Read in data, specifying column types (careful if order of columns in input data changes) 
TARN <- readxl::read_xlsx(base::paste0(folder,"/",data_tarn),
                          col_types = c("text","numeric","text","text","text","text","text",
                                        "date","text","date","text","text","text","text")) %>% 

#Rename columns to remove spaces
  dplyr::rename(
    TARN_ID = `Case ID`,
    Position = `Position in Vehicle`,
    Incident_Location = `Incident Location`,
    Incident_Description = `Incident Description`,
    Incident_Date = `Incident Date`,
    Incident_Time = `Incident Time`,
    Arrival_Date = `Arrival Date`,
    Arrival_Time = `Arrival Time`,
    Incident_Postcode = `Incident Post Code`,
    Hospital_Location = `Hospital Location`,
    Home_Postcode = `Home Post Code`) %>% 
  
#Create numeric versions of Incident_Time and Arrival_Time for matching
    dplyr::mutate_at(c('Incident_Time', 'Arrival_Time'), as.numeric) %>%
  
#Change postcodes to upper case 
    dplyr::mutate_at(c('Incident_Postcode', 'Home_Postcode'), toupper) %>% 
  
#Split the date columns into year, month, day (Incident_Date, Arrival_Date)
    tidyr::separate(Incident_Date, # the column we want to split
                    into = c("Incident_Year", "Incident_Month", "Incident_Day"), # the new columns we want to split it into
                    sep = "-", remove = FALSE) %>%  # the character we want to split the variables on
  
    tidyr::separate(Arrival_Date, 
                    into = c("Arrival_Year", "Arrival_Month", "Arrival_Day"),
                    sep = "-" , remove = FALSE) %>%
  
#Convert new year, month, day columns to numeric and calculate day within the year  
    dplyr::mutate_at(c('Incident_Year','Incident_Month', 'Incident_Day', 
                       'Arrival_Year','Arrival_Month','Arrival_Day'), as.numeric) %>%
    dplyr::mutate(Arrival_YearDay = lubridate::yday(Arrival_Date), Incident_YearDay = lubridate::yday(Incident_Date)) %>%

#Restrict to arrival at hosp up to mid-2022 only, where assume TARN data substantially complete.  Use arrival as incident year often missing
dplyr::filter((Arrival_Year == 2020 | Arrival_Year == 2021 | Arrival_Year == 2022 & Arrival_Month <= 6)) %>% 
  
  #Create additional date variable for matching, which takes incident date if available, else arrival date (only day, not time)
  dplyr::mutate(Match_Year = dplyr::if_else(Incident_Year < 2020, Arrival_Year, Incident_Year),
                Match_Month = dplyr::if_else(Incident_Month < 0, Arrival_Month, Incident_Month),
                Match_Day = dplyr::if_else(Incident_Day < 0, Arrival_Day, Incident_Day),
                Match_YearDay = dplyr::if_else(Incident_YearDay < 0, Arrival_YearDay, Incident_YearDay)) %>%
  
  #Format the postcode variable for matching to STATS19 (e.g. removing spaces) and flag where postcode district is valid
  dplyr::mutate(Home_PostcodeDistrict = stringr::word(Home_Postcode,1)) %>% 
  dplyr::left_join(postcode_district_valid, by = c("Home_PostcodeDistrict"="District"))
  
#Replace NAs with appropriate values (-999) in each column
TARN$Incident_Year[is.na(TARN$Incident_Year)] <- -999
TARN$Incident_Month[is.na(TARN$Incident_Month)] <- -999
TARN$Incident_Day[is.na(TARN$Incident_Day)] <- -999
TARN$Incident_YearDay[is.na(TARN$Incident_YearDay)] <- -999
TARN$Incident_Time[is.na(TARN$Incident_Time)] <- -999
TARN$Arrival_Year[is.na(TARN$Arrival_Year)] <- -999
TARN$Arrival_Month[is.na(TARN$Arrival_Month)] <- -999
TARN$Arrival_Day[is.na(TARN$Arrival_Day)] <- -999
TARN$Incident_YearDay[is.na(TARN$Arrival_YearDay)] <- -999
TARN$Arrival_Time[is.na(TARN$Arrival_Time)] <- -999

################################################################################

## ADD VARIABLES FOR MATCHING

#The following joins additional variables required for matching to the TARN file 

#Postcode lookup to Easting, Northing
#Where TARN records incident location, this is as a postcode 
#For comparision with STATS19 (which records co-ordinates of the collision location) we convert to Easting, Northing
#This is based on the postcode centroid, looked up from a lookup table 

TARN <- dplyr::left_join(x = TARN, y = postcode, 
                          by = c("Incident_Postcode" = "Fullcode_ONS_formatch")) %>% 
  
#Lookup approximate hospital location (Easting,Northing) based on postcode district, which is all we have in TARN
#This will be used to calculate the distance between collision and hospital
  dplyr::left_join(postcode_district, by = c("Hospital_Location"="District")) %>% 

#Road user type and casualty class 
#Map TARN Position_in_Vehicle to c16sum (casualty type) and c5 (casualty class) equivalents
#In this case, as we only have vulnerable road users, c5 mapping is not likely to be helpful  
  dplyr::mutate(TARN_CasType = case_when(Position == "Pedalcyclist" ~ 1,
                                        Position == "Motorcyclist" ~ 5, #in the past has included quad bikes
                                        Position == "Powered Personal Transport/e-Scooter" ~ 90))

################################################################################

## APPLY AMENDMENTS TO ROAD USER TYPE CODING - IDENTIFY E-SCOOTERS

#In TARN, escooters are not explicitly identified so have to be coded from within the PPT/e-scooter category
#We create a flag for e-scooter casualties based on the incident description, and use this to update the c16sum_TARN coding
#In a small number of cases with apparent mismatches, use the TARN reference (read from a file) to revert e-scooter flag back to 0
#This file 'Data_TARN_amendments' has two columns - CaseID, and escooter_amend which has the value 0 and used to amend the flag

TARN_amend <- readxl::read_xlsx(base::paste0(folder,"/",data_tarn_amendment))

#To identify e-scooters, search incident description text for keywords
#Not currently including 'motorised scooter', 'powered scooter' here - though relatively few cases with this description

escooters_to_match <- c("escooter", "e-scooter", "electric scooter", "e scooter", "Beryl scooter",
                        "electric push scooter", "electric scoter", "electric shooter","rental scooter",
                        "elctric scooter","electronic scooter", "electronical scooter", "electrical scooter", "electiric scooter",
                        "electricscooter", "VOI scooter", "elec scooter","'E' scooter", "electric  scooter",
                        "electric stand up scooter", "electric-scooter","electic scooter") 

#Create list of possible matches (refine iteratively by QA in Excel)
TARN <- dplyr::mutate(TARN, 
                      escooter = dplyr::case_when(base::grepl(paste(escooters_to_match,collapse="|"),
                                                                       Incident_Description, ignore.case= TRUE) == TRUE ~ 1,
                                                                 TRUE ~ 0)) %>% 
  
#To check the coding, cases were manually checked using the incident description
#For example, the description may refer to a pedal cycle whereas the code is 'powered personal transporter'
#These mismatches are listed in the amendments file  
  dplyr::left_join(TARN_amend, by = c("TARN_ID" = "CaseID")) %>%
  dplyr::mutate(escooter = dplyr::case_when(escooter_amend == 0 ~ 0, TRUE ~ escooter)) %>%
  
#Tweak c16sum coding where have identified as e-scooter, coding as 90 to be consistent with STATS19
  dplyr::mutate(TARN_CasType = dplyr::case_when(escooter == 1 ~ 90, TRUE ~ TARN_CasType)) %>% 
  dplyr::select(-escooter_amend)

################################################################################

## TIDY THE ENVIRONMENT 

#Keep only the variables needed for matching, and rename for clarity when linking

TARN_outcome <- TARN #retain a 'full' version of the file to save for analysis

TARN <- TARN %>% 
  dplyr::select(TARN_ID,
                TARN_Age = Age, TARN_Gender = Gender, TARN_CasType, TARN_Severity = Outcome,
                TARN_Time = Incident_Time, TARN_Year = Match_Year, TARN_YearDay = Match_YearDay,
                TARN_HomePostcode = Home_PostcodeDistrict, TARN_HomePostcode_valid = valid, 
                TARN_LocationEasting = Easting_ONS, TARN_LocationNorthing = Northing_ONS, 
                TARN_Hospital = Hospital_Location,
                HospitalEasting = EastingDistrict, HospitalNorthing = NorthingDistrict)

rm(TARN_amend)







