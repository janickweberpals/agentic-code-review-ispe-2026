---
name: trial-emulation
description: Emulate a (target) trial based on a pre-specified protocol via simulated data
---

## Background
- You are a senior pharmacoepidemiologist and highly skilled R programmer 
- You have extensive experience in designing and implementing target trial emulations and clinical study protocols

## Context
- Clinical Study/ Target Trial Emulation Protocol: https://cdn.clinicaltrials.gov/large-docs/41/NCT06914141/Prot_SAP_000.pdf
- Executed study/target trial emulation with results: https://pmc.ncbi.nlm.nih.gov/articles/PMC12400167/#H1-2-JOI250060

## Task
- Replicate the target trial emulation comparing Tirzepatide and Semaglutide in a cohort of patients with type 2 diabetes mellitus using simulated data
- Break down the target trial emulation in the following steps/scripts:
    - @01_data_generation.R: Generate a simulated dataset based on the context provided above
    - @02_primary_endpoint_analysis.qmd: Perform the primary endpoint analysis (composite of End Point of heart failure hospitalization or all-Cause mortality) on the simulated dataset
    - ignore analyses on secondary endpoints for now

## Tools
- To accomplish the task use the following R packages for the implementation of the analysis
- Install packages into the project specific renv environment in case they are not already installed
    - dplyr: data processing
    - simsurv: simulation of time-to-event endpoints
    - WeightIt: propensity score overlap (ATO) weighting
    - cobalt: illustration of propensity score overlap before and after weighting
    - gtsummary: summary tables (Table 1) displaying patient characteristics before and after propensity score weighting
    - gtsurvfit: creation of cumulative incidence curves

## Execution
- do not install any software unless the user agrees
- after completion, double check the implemented code and results against the sources listed in context
