################################################################################
# LINKING STATS19 AND TARN: DATA LINKING
################################################################################

#This script runs the matchjing process, broadly implementing the Fellegi-Sunter method
#It requires the prepared STATS19 and TARN files as well as the lookup tables 
#Outputs are saved back to the pre-specified data folder

################################################################################

## STAGE 1 - GENERATE CANDIDATE LINKS

#For each entry in TARN subset find the STATS19 records with matching date
#Create variables for difference between STATS19 and TARN records on age, sex, distance etc

#Loop through the TARN records one row at a time
for (idx in 1:nrow(TARN)){
  
  print(paste("working on row",idx,"out of",nrow(TARN)))
  TARN_record <- TARN %>% slice(idx) #this just identifies the current record being worked on 
  
  #Get corresponding details to use in filtering 
  TARN_Year <- TARN$TARN_Year[idx]
  TARN_YearDay <- TARN$TARN_YearDay[idx]
  TARN_Age <- TARN$TARN_Age[idx]
  
  #Find potential matches in STATS19 based on date (STATS19 same as TARN, or the day before to allow for delay between collision and admission)
  #Also restrict to cases where the difference in casualty age is less than 5 years as prelim work suggested few cases with a bigger discrepancy are likely to be true matches
  STATS19_record <- STATS19 %>% filter(STATS19_Year == TARN_Year & STATS19_YearDay <= TARN_YearDay & STATS19_YearDay >= TARN_YearDay - 1
                                               & abs(STATS19_Age - TARN_Age) < 5)
  
  #Compute distance between collision location and TARN location coordinate derived from postcode
  distances_miles <- (((STATS19_record$STATS19_LocationNorthing - TARN_record$TARN_LocationNorthing)^2.0 +
                         (STATS19_record$STATS19_LocationEasting - TARN_record$TARN_LocationEasting)^2.0)^0.5)/(1.6093*1000.)
  
  #Compute distance between collision location and TARN hospital location (based on postcode district)
  distances_hospital <- (((STATS19_record$STATS19_LocationNorthing- TARN_record$HospitalNorthing)^2.0 +
                            (STATS19_record$STATS19_LocationEasting - TARN_record$HospitalEasting)^2.0)^0.5)/(1.6093*1000.)
  
  #Flag agreement on postcode district
  district_agree <- case_when(is.na(TARN_record$TARN_HomePostcode_valid) ~ 9999,
                              is.na(STATS19_record$STATS19_HomePostcode_valid) ~ 9999,
                              TARN_record$TARN_HomePostcode == STATS19_record$STATS19_HomePostcode ~ 1,
                              TRUE ~ 0)
  
  #Corresponding differences in age
  age_difference <- abs(STATS19_record$STATS19_Age- TARN_record$TARN_Age)
  
  #Gender-sex agreement flag
  gender_sex_agree <- case_when(STATS19_record$STATS19_Sex == 1 ~ "Male",
                                STATS19_record$STATS19_Sex == 2 ~ "Female",
                                TRUE ~ "Other") == TARN_record$TARN_Gender
  
  #Difference in collision time (note, we must use incident time from TARN here if available, as arrival time will always be later)
  time_difference_minutes <- case_when(TARN_record$TARN_Time == -999 ~ 9999,
                                       TRUE ~ abs(STATS19_record$STATS19_Time - TARN_record$TARN_Time)*24*60)
  
  #Difference in c16sum (if there is one for TARN)
  c16sum_agree <- case_when(!is.na(TARN_record$TARN_CasType) ~ STATS19_record$STATS19_CasType == TARN_record$TARN_CasType)
  
  #Date agreement flag
  date_agree <- case_when(TARN_record$TARN_YearDay == STATS19_record$STATS19_YearDay ~ "Exact",
                          TRUE ~ "Not exact")
  
  #Severity agreement flag
  severity_agree <- case_when(TARN_record$TARN_Severity == "Dead" & STATS19_record$STATS19_Severity == 1 ~ "Match",
                              TARN_record$TARN_Severity == "Alive" & STATS19_record$STATS19_Severity == 2 ~ "Match",
                              TRUE ~ "Non match")
  
  
  #Make a vector repeating the TARN ID
  TARN_ID <- rep(TARN_record$TARN_ID,nrow(STATS19_record))
  
  #Now put them together into a data frame
  if (idx == 1) {
    match_candidates <- data.frame(TARN_ID, distances_miles, distances_hospital, district_agree, date_agree, age_difference, 
                          time_difference_minutes, gender_sex_agree, c16sum_agree, severity_agree,
                          STATS19_record$STATS19_Year, STATS19_record$accid, STATS19_record$accref, STATS19_record$casref, STATS19_record$vehref, STATS19_record$casualtyid)
  } else {
    match_candidates_record <- data.frame(TARN_ID, distances_miles, distances_hospital, district_agree, date_agree, age_difference, 
                        time_difference_minutes, gender_sex_agree, c16sum_agree, severity_agree,
                        STATS19_record$STATS19_Year, STATS19_record$accid, STATS19_record$accref, STATS19_record$casref, STATS19_record$vehref, STATS19_record$casualtyid)
    match_candidates <- rbind(match_candidates,match_candidates_record)
  }
}

rm(match_candidates_record, TARN_record, STATS19_record) #no longer need to keep the individual record details after looping through all cases

################################################################################

## STAGE 2 - ASSIGN PROBABILITIES TO CANDIDATE LINKS

#The approach used here is probabilistic, which requires probabilities of agreement on common variables 
#conditional on whether the candidate records are a true match or not 
#These are respectively 'M probabilities' and 'U probabilities'

#First add the match and non-match probabilities to each record in the linked file 

match_candidates_probs <- match_candidates %>%  
  dplyr::inner_join(y = select(TARN,TARN_ID,TARN_Hospital),
                    by = c("TARN_ID" = "TARN_ID")) %>% 
  dplyr::inner_join(y = select(STATS19, accref, casref, vehref, STATS19_Year, STATS19_Age, STATS19_Sex, STATS19_Hour, STATS19_LSOA, STATS19_CasType,
                               STATS19_Severity,STATS19_HomePostcode), 
                    by = c( "STATS19_record.accref" = "accref",
                            "STATS19_record.casref" = "casref",
                            "STATS19_record.vehref" = "vehref",
                            "STATS19_record.STATS19_Year" = "STATS19_Year")) %>%
  
#Add the non-match (U) probabilities to each record in the linked file by joining to lookup tables 
  dplyr::left_join(y=U_age,by = c("STATS19_Age"="c7")) %>%
  dplyr::left_join(y=U_sex,by = c("STATS19_Sex"="c6")) %>%
  dplyr::left_join(y=U_time,by = c("STATS19_Hour"="a8h")) %>%
  dplyr::left_join(y=U_distance,by = c("STATS19_LSOA"="lsoa_a")) %>% 
    dplyr::mutate(u_distance = case_when(STATS19_LSOA == "-1" ~ 0.00003,TRUE ~ u_distance)) %>% #Use an average value for u_distance when LSOA not present in STATS19 
  dplyr::left_join(y=U_type,by = c("STATS19_CasType"="c16sum")) %>%
  dplyr::left_join(y=U_severity,by = c("STATS19_Severity"="c8")) %>%
  dplyr::left_join(y=U_hospital,by = c("TARN_Hospital"="district")) %>%
  dplyr::left_join(y=U_district,by = c("STATS19_HomePostcode"="c18a")) %>%
  dplyr::mutate(u_date = 0.5) %>% #this assumes 50% chance of match on date given we have selected only day and day before to match to
  
#Add the match probabilities; these have been pre-calculated but don't vary by value (unlike the U-probabilities) so no lookup required
  dplyr::mutate(m_sex = 0.994, m_age=0.981, m_time=0.969,m_distance=0.966,
                m_type=0.958,m_severity=0.889, m_district = 0.96, m_date = 0.9, m_hospital= 0.94) 

rm(match_candidates) #this dataframe now superseded by the one with probabilities added

################################################################################

## STAGE 3 - CALCULATE MATCHING WEIGHTS FOR EACH CANDIDATE LINK

#Calculate match weights for each common variable, based on the Fellegi-Sunter approach 

#Sex
match_candidates_probs$w_sex <- case_when(is.na(match_candidates_probs$u_sex) ~ 0,
                                 match_candidates_probs$gender_sex_agree == TRUE ~ log(match_candidates_probs$m_sex/match_candidates_probs$u_sex),
                                 match_candidates_probs$gender_sex_agree == FALSE ~ log((1 - match_candidates_probs$m_sex)/(1-match_candidates_probs$u_sex)),
                                 TRUE ~ 0)

#Age
match_candidates_probs$w_age <- case_when(is.na(match_candidates_probs$u_age) ~ 0,
                                 match_candidates_probs$age_difference <= 1 ~ log(match_candidates_probs$m_age/match_candidates_probs$u_age),
                                 match_candidates_probs$age_difference >= 1 ~ log((1 - match_candidates_probs$m_age)/(1-match_candidates_probs$u_age)),
                                 TRUE ~ 0)

#Casualty road user type (e.g. pedal cyclist, motorcyclist, e-scooter user)
match_candidates_probs$w_type <- case_when(is.na(match_candidates_probs$u_type) ~ 0,
                                  match_candidates_probs$c16sum_agree == TRUE ~ log(match_candidates_probs$m_type/match_candidates_probs$u_type),
                                  match_candidates_probs$c16sum_agree == FALSE ~ log((1 - match_candidates_probs$m_type)/(1-match_candidates_probs$u_type)),
                                  TRUE ~ 0)

#Casualty severity
match_candidates_probs$w_severity <- case_when(is.na(match_candidates_probs$u_severity) ~ 0,
                                      match_candidates_probs$severity_agree == "Match" ~ log(match_candidates_probs$m_severity/match_candidates_probs$u_severity),
                                      match_candidates_probs$severity_agree == "Non match" ~ log((1 - match_candidates_probs$m_severity)/(1-match_candidates_probs$u_severity)),
                                      TRUE ~ 0)

#Date and time
match_candidates_probs$w_date <- case_when(is.na(match_candidates_probs$u_date) ~ 0,
                                  match_candidates_probs$date_agree =="Exact" ~ log(match_candidates_probs$m_date/match_candidates_probs$u_date),
                                  match_candidates_probs$date_agree =="Not exact" ~ log((1 - match_candidates_probs$m_date)/(1-match_candidates_probs$u_date)),
                                  TRUE ~ 0)
match_candidates_probs$w_time <- case_when(is.na(match_candidates_probs$u_time) ~ 0,
                                  match_candidates_probs$date_agree =="Not exact" ~ 0, #Ignore time when date doesn't match
                                  match_candidates_probs$time_difference_minutes <= 60 ~ log(match_candidates_probs$m_time/match_candidates_probs$u_time),
                                  match_candidates_probs$time_difference_minutes > 60 & match_candidates_probs$time_difference_minutes < 9999   ~ log((1 - match_candidates_probs$m_time)/(1-match_candidates_probs$u_time)),
                                  TRUE ~ 0)

#Distance based on collision location if available; otherwise distance between hospital (TARN) and collision location (STATS19)
match_candidates_probs$w_distance <- case_when(is.na(match_candidates_probs$u_distance) ~ 0, 
                                      match_candidates_probs$distances_miles <= 2 ~ log(match_candidates_probs$m_distance/match_candidates_probs$u_distance),
                                      match_candidates_probs$distances_miles  > 2  ~ log((1 - match_candidates_probs$m_distance)/(1-match_candidates_probs$u_distance)),
                                      TRUE ~ 0)
match_candidates_probs$w_hospital <- case_when(is.na(match_candidates_probs$u_hospital) ~ 0, 
                                      match_candidates_probs$distances_hospital <= 30 ~ log(match_candidates_probs$m_hospital/match_candidates_probs$u_hospital),
                                      match_candidates_probs$distances_hospital  > 30  ~ log((1 - match_candidates_probs$m_hospital)/(1-match_candidates_probs$u_hospital)),
                                      TRUE ~ 0)

#Home postcode (district) agreement
match_candidates_probs$w_district <- case_when(is.na(match_candidates_probs$u_district) ~ 0, #no valid district in STATS19, this applies
                                      match_candidates_probs$district_agree == 1 ~ log(match_candidates_probs$m_district/match_candidates_probs$u_district),
                                      match_candidates_probs$district_agree == 0  ~ log((1 - match_candidates_probs$m_district)/(1-match_candidates_probs$u_district)),
                                      TRUE ~ 0)

#Combine all the individual weights (add)
#There's an additional step here which avoids two candidate matches having the same weight 
#(in this case, we're effectively selecting from equally weighted candidates at 'random'; this is a relatively rare occurrence)

for (idx in 1:nrow(match_candidates_probs)){
  set.seed = idx
  match_candidates_probs$rand[idx] <- runif(1,min=0.0001, max=0.0002)
}

match_candidates_probs$w_overall <- match_candidates_probs$w_sex + match_candidates_probs$w_age + match_candidates_probs$w_time + match_candidates_probs$w_distance +
  match_candidates_probs$w_type + match_candidates_probs$w_severity + match_candidates_probs$w_district + match_candidates_probs$w_date + match_candidates_probs$w_hospital + match_candidates_probs$rand

################################################################################

## STAGE 4 - SELECT HEIGHEST WEIGHTED CANDIDATE STATS19 MATCH FOR EACH TARN RECORD


#Get TARN_ID and corresponding best ranked match
#Then join back to matches file, and select only records with the best rank
#Note that as one TARN record could link to more than one STATS19 record, need to flag this somehow
#Here a *very* crude approach to selecting just one from equally good matches - a random choice

#Start with the file containing all candidate matches (which will be many to many)
#For each TARN record, find the STATS19 record with the highest overall weight  
matches_best <- match_candidates_probs %>% 
  dplyr::group_by(TARN_ID) %>% #this selects each TARN record 
  dplyr::summarise(max_weight = max(w_overall)) %>% #this finds the highest weight 
  dplyr::inner_join(y=select(match_candidates_probs, TARN_ID, w_overall, STATS19_record.STATS19_Year,STATS19_record.accref,STATS19_record.vehref,STATS19_record.casref),
                    by = c("TARN_ID" = "TARN_ID", "max_weight" = "w_overall")) %>%  #add back the details of candidate matches with the highest weights, as need STATS19 ID for next part 

#Now the same for STATS19, select only the highest weighted candidate link for each STATS19 record
  dplyr::group_by(STATS19_record.STATS19_Year,STATS19_record.accref,STATS19_record.vehref,STATS19_record.casref) %>% #these variables identify a STATS19 record 
  dplyr::summarise(max_weight = max(max_weight)) %>%  #this finds the highest weight across the STATS19 records which are the best match for at least one TARN record
  dplyr::inner_join(y=match_candidates_probs, 
                  by = c("STATS19_record.STATS19_Year"="STATS19_record.STATS19_Year", "STATS19_record.accref"="STATS19_record.accref", 
                         "STATS19_record.vehref"="STATS19_record.vehref", "STATS19_record.casref"="STATS19_record.casref", "max_weight"="w_overall")) %>% #add back the details of candidate matches with the highest weights 
  dplyr::select(-c(u_age:m_hospital)) %>% #remove unnecessary columns with the probabilities used to calculate weights
  dplyr::rename(weight = max_weight) %>% 
  dplyr::ungroup()  %>%

#Assign match status based on pre-determined thresholds (identified based on analysis completed outside of this code)  
#Note that when distance is available, it provides more confidence in whether a link is a true match or not, so the need to review is reduced  
  dplyr::mutate(match_status = case_when(w_distance !=0 & weight >= 8 ~ 'Match',
                                         w_distance !=0 & weight < 8 ~ 'Non match',
                                         w_distance ==0 & weight >= 8 ~ 'Match',
                                         w_distance ==0 & weight >= 5 & weight <8 ~ 'Review match',
                                         w_distance ==0 & weight < 5 ~ 'Non match')) %>%


#Some tidying of the resulting file of best matches 
  dplyr::relocate("TARN_ID") %>% #bring the TARN identifier to the front
  dplyr::relocate("match_status", .after = "weight") #bring the match_status next to the weight

################################################################################

## STAGE 5 - APPLY ANY AMENDMENTS FOLLOWING MANUAL REVIEW

#Now make any manual amendments following review

#Read in file that will be used to amend (some of the) records flagged as for 'review' - two columns, TARN_ID and 'match_amend' which takes values 'Match', 'Non match'
#Currently there are 12 cases where manual amendments are made, focussing on e-scooters
#The number of review matches for pedal cyclists and motorcyclists is larger and has not yet been addressed  

TARN_review <- readxl::read_xlsx(paste0(folder, "/", matches_review),
                                 col_types = c("text","text"))

#Update the list of matches with the new status as amended by manual review

matches_best <- matches_best %>% 
  dplyr::left_join(TARN_review, by = c("TARN_ID" = "CaseID")) %>%
  dplyr::mutate(match_status = case_when(!is.na(match_amend) ~ match_amend, TRUE ~ match_status)) %>%
  dplyr::select(-match_amend)

################################################################################

## STAGE 6 - SAVE RESULTS

#For analysis, add the details of matches back to the *original* TARN file 
TARN_outcome <-  TARN_outcome %>% 
  dplyr::inner_join(y=select(matches_best,TARN_ID, weight, match_status),
                    by = c("TARN_ID" = "TARN_ID"))

#Save output files back to the previously specified folder and with pre-specified names
writexl::write_xlsx(matches_best, paste0(folder,"/",save_match_best)) 
writexl::write_xlsx(TARN_outcome, paste0(folder,"/",save_match_TARN))

################################################################################

# TIDY ENVIRONMENT

rm(set.seed,idx,age_difference,gender_sex_agree,c16sum_agree,district_agree,date_agree,distances_miles,distances_hospital,severity_agree,
   TARN_Age,TARN_ID,TARN_Year, TARN_YearDay, time_difference_minutes)
rm(postcode, postcode_district_valid)
rm(U_age, U_class, U_date, U_distance, U_district, U_hospital, U_severity, U_sex, U_time, U_type)
rm(TARN_review)

################################################################################

