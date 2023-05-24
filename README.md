# STATS19 and TARN data linking

This is a repository containing code developed by DfT to link the Department's road casualty data (STATS19) with data on hospital patients following road collisions supplied by the Trauma Audit Research Network (TARN).  This acts as documentation of the Department's approach, as well as a basis for related work or development.

The basic approach followed is as set out in the Department's [feasibility study](https://www.gov.uk/government/statistics/linking-stats19-and-tarn-an-initial-feasibility-study), though the method has been developed as more data has become available.  This code specifically relates to data covering vulnerable road users - e-scooter users, pedal cyclists and motorcyclists - but will be extended to other road user types (notably vehicle occupants and pedestrians) in future.

## To use 

To use this repo and the code, it will be necessary to obtain the relevant datasets.  Fundamentally, these are STATS19 and TARN data files but there are additional inputs used as detailed below.

Core data inputs:
* STATS19 - the majority of the data required is available as [open data](https://www.data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-safety-data) as available from data.gov.  The exception is the casualty home postcode field, for which an application to DfT is required.  The code can be run without this field, but amendmentments will be required in this case 
* TARN - the TARN data for this work was an extract supplied by the [TARN team](https://www.tarn.ac.uk/) at the University of Manchester following an approved application by DfT.  To obtain equivalent data a request would need to be submitted

Additional inputs:
* Lookup tables for matching probabilities - this method uses an approach which follows the established [Fellegi-Sunter](https://www.robinlinacre.com/maths_of_fellegi_sunter/) probabilistic matching method, and requires conditional probabilities for agreement on matching variables given a true link, or otherwise.  These have been created from historical data and are essentially read in here as static tables.  As they are largely derived from published or publically available information, these probabilities can be included as part of this repo
* Manual review cases - probabalistic matching of this nature is unlikely to produce perfect results; a threshold is set for what is deemed to be a 'match' or 'non-match' but this results in both false positive (non-matching cases deemed to be a match) and false negative (missed match) cases.  Cases which fall close to the threshold can be manually reviewed using additional information in one or other of the datasets (for example, what is captured in the incident desciption in TARN).  Where this review leads to a change in the designation of a match, this is recorded in a spreadsheet and read back in to the process.  However, this spreadsheet contains TARN record IDs so cannot be provided here.     

## Features

### Raising issues

The repository contains two issue templates which are loaded automatically; one for bug reporting, and one for feature suggestions. These can be used to record any issues with code or suggested improvements for consideration by DfT.  It is worth noting that there is no single definitive linking method, and that this represents an initial attempt to develop and share the code with a view to seeking feedback and suggestions for development.

## Contact 

Aside from directly in Git by raising an issue, any feedback can be provided to the [road safty statistics team](mailto:roadacc.stats@dft.gov.uk) at DfT

## Acknowledgements 

We are grateful to the TARN team for the provision of data to facilitate the development of this linkage.  All work and any errors are the responisbility of the road safety statistics team at DfT.

ONS Postcode data obtained from the ONS Postcode Directory is used in the linkage methodiology 
Contains OS data © Crown copyright and database right [2023]
Contains Royal Mail data © Royal Mail copyright and database right [2023]
Source: Office for National Statistics licensed under the Open Government Licence v.3.0




