################################################################################
# LINKING STATS19 AND TARN: PREPARE STATS19 DATA
################################################################################

#This script reads in the STATS19 data file, filters appropriately and adds additional 
#variables required for matching to TARN

################################################################################

## READ IN STATS19 DATA

#In this case, the data is stored in an Excel file names 'Data_STATS19.xlsx' 

#Filters as follows 
# - restricted to motorcyclists, pedal cyclist, mobility scooter or 'other' casualties (to mirror the coverage of the TARN file)
# - England and Wales only (as TARN does not cover Scotland aim to avoid spurious matches)
# - Data for 2020 to mid-2022 (again, broadly matching TARN data)

#With column names as listed below

# accid	
# accref	
# vehref	
# casref	
# casualtyid
# PoliceForce	[variable a1; not currently used in the matching]

# STATS19_Year [variable accyr renamed on creation of Excel file]	
# STATS19_Month [accmth]	
# STATS19_Day [accday]	
# STATS19_Time [time]	
# STATS19_Hour [a8h]

# STATS19_LSOA [lsoa_a; this is the Lower Super Output Area code for the collision location]	
# STATS19_LocationEasting	[a10]
# STATS19_LocationNorthing [a11]	

# STATS19_CasType [c16sum]	
# STATS19_OtherCasText [c16a; not currently used in the matching but identifies e-scooter casualties]
# STATS19_Sex [c6]
# STATS19_Age [c7]	
# STATS19_Severity [c8]
# STATS19_HomePostcode [c18a; this is first part of postcode]

#Read in data, specifying column types (careful if order of columns in input data changes) 
STATS19 <- readxl::read_xlsx(base::paste0(folder,"/",data_stats19),
                             col_types = c("numeric","text","numeric","numeric","numeric","numeric","numeric",
                                           "numeric","numeric","numeric","numeric","numeric","numeric","text",
                                           "numeric","text","numeric","numeric","numeric","text")) %>% 
  
#Filter to select cases to match scope of TARN data (pedal cycle, motorcycle and 'other' casualties; 2020 to mid-2022)
  dplyr::filter(STATS19_CasType %in% c(1,5,90)) %>% 
  dplyr::filter(STATS19_Year == 2020 | STATS19_Year==2021 | (STATS19_Year = 2022 & STATS19_Month <= 7)) %>%   
  
#Need to convert date to date format (time should read in as a fraction of the day as needed) 
  dplyr::mutate(STATS19_Date = lubridate::make_datetime(STATS19_Year, STATS19_Month, STATS19_Day)) %>%  
  
#Calculate the day of the year from the date
  dplyr::mutate(STATS19_YearDay = lubridate::yday(STATS19_Date))  %>%  
  
#Add a flag for validity of postcode 
  dplyr::left_join(postcode_district_valid,by = c("STATS19_HomePostcode"="District")) %>% 
  dplyr::rename(STATS19_HomePostcode_valid = valid) %>% 
  
#Tidy the file 
  select(-STATS19_Month, -STATS19_Day)
  
################################################################################