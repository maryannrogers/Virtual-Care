# Virtual Care

This repository contains SAS code used in my MSc thesis project analyzing prescribing patterns associated with virtual primary care visits in British Columbia.

## Project Overview

**Objective:** To examine whether the shift to virtual care during and after the COVID-19 pandemic has impacted antibiotic prescribing for acute conditions.
**Data Sources:** BC PharmaNet, Medical Services Plan (MSP), Discharge Abstracts Database (DAD), MSP Consolidation File, Vital Statistics Births/Deaths
**Time Period:** January 2022 – December 2022
**Conditions Studied:** Urinary Tract Infection (UTI), Otitis Media

## Repository Structure

- `01_clean_data.sas`: Cleaning steps and variable creation
- `02_analytic_models.sas`: Propensity score matching and outcome modeling

## Requirements

- SAS 9.4
- Appropriate access credentials to BC health administrative datasets

## Data Dictionary

**Datasets:**
- 'UTI_Dataset_Overall': Contains all visits and prescriptions for individuals who had a UTI in 2022
- 'UTI_Dataset_Anti': Contains all visits and prescriptions for individuals who were prescribed an antibiotic for UTI in 2022
- 'UTI_Dataset_Nitro': Contains all visits and prescriptions for individuals who were prescribed Nitrofurantoin for UTI in 2022

**Variables**
- Active Ingredient: Drug active ingredient from the Canadian Drug Products Database  
- BROAD: Indicator where BROAD = 1 when the prescription is considered broad-spectrum, and BROAD = 0 when the prescription is considered narrow-spectrum  
- CLMSPEC: Claim Specialty Code, which describes a practitioner's specialty associated with a claim  
- Days_Supply_Dispensed: Days of medication supplied by BC pharmacy  
- DIAGCD - DIAGCD3: ICD-9 Diagnostic Codes are intended to indicate the condition for which the patient is treated  
- DIAGX1 – DIAGX25: ICD-10 Diagnostic Codes are intended to indicate the condition for which the patient is treated  
- DIN_PIN: Drug Identification Number  
- DOBYYYY: An individual’s year of birth  
- DNBTIPPE 1-11: Neighbourhood income decile before tax  
- FITM: Paid for Item (Fee Item) is a numeric code used to identify each service provided by a practitioner. Each fee item has an associated fee that is paid to the payee for the service provided  
- HSDA 1-16: BC health service delivery area  
- MRP: Binary variable where 1 = the physician visit was with an individual's most responsible physician, 0 = it was not  
- prior_rx_count: Count of how many prescriptions an individual had in the year prior to one for UTI  
- prior_rx_flag: Binary variable where 1 = an individual had a prescription for UTI in the prior year, 0 = they did not  
- prior_visit_flag: Binary variable where 1 = an individual saw a physician for UTI in the prior year, 0 = they did not  
- prop_virtual: Proportion of visits a physician provides virtually in their practice  
- SERVDT: Service Date is the date on which the service was rendered by an outpatient practitioner  
- Sex: Sex assigned at birth  
- StudyID: ID assigned to each individual in the dataset by PopData BC  
- VIRTUAL: Binary variable for virtual visits where VIRTUAL = 1 for visits associated with a fee item code for a virtual visit, and VIRTUAL = 0 for visits associated with a fee item code for an in-person visit  
- wgtccup: Weighted Charlson Comorbidity Index  
  - Note: This code was adapted from the Manitoba Centre for Health Policy (MCHP).
    Original source: [MCHP Concept: Propensity Score Matching](http://mchp-appserv.cpe.umanitoba.ca/viewConcept.php?conceptID=1098)


## Citation

If you use this code, please cite:

Rogers M. The impact of virtual care on prescribing practices for acute conditions: a global scoping review and regional analysis of British Columbia [master’s thesis].
Vancouver (BC): University of British Columbia; 2025. Available from: https://github.com/maryannrogers/Virtual-Care
