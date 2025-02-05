/*==============================================================================
DO FILE NAME:			01_cr_analysis_dataset
PROJECT:				Exposure children and COVID risk
DATE: 					25th June 2020 
AUTHOR:					Harriet Forbes adapted from A Wong, A Schultze, C Rentsch,
						 K Baskharan, E Williamson 										
DESCRIPTION OF FILE:	program 01, data management for project  
						reformat variables 
						categorise variables
						label variables 
						apply exclusion criteria
DATASETS USED:			data in memory (from analysis/input.csv)
DATASETS CREATED: 		none
OTHER OUTPUT: 			logfiles, printed to folder analysis/$logdir
							
==============================================================================*/
global outdir  	  "output"
global logdir     "logs"
global tempdir    "tempdata"

*Start dates
global indexdate = "20/12/2020"

*Censor dates
global study_end_censor   	= "21/10/2021"

* Open a log file
cap log close
log using "$logdir/01_cr_analysis_dataset", replace t


*Import dataset into STATA
import delimited "output/input", clear
/* CONVERT STRINGS TO DATE====================================================*/
/* Comorb dates and TPP case outcome dates are given with month only, so adding day 
15 to enable  them to be processed as dates 											  */

*cr date for diabetes based on adjudicated type
gen diabetes=type1_diabetes if diabetes_type=="T1DM"
replace diabetes=type2_diabetes if diabetes_type=="T2DM"
replace diabetes=unknown_diabetes if diabetes_type=="UNKNOWN_DM"

drop type1_diabetes type2_diabetes unknown_diabetes

foreach var of varlist 	chronic_respiratory_disease ///
						chronic_cardiac_disease  ///
						diabetes ///
						cancer_haem  ///
						cancer_nonhaem  ///
						permanent_immunodeficiency  ///
						temporary_immunodeficiency  ///
						dialysis					///
						kidney_transplant			///
						other_transplant 			/// 
						asplenia 			/// 
						chronic_liver_disease  ///
						other_neuro  ///
						stroke_dementia				///
						esrf  ///
						hypertension  ///
						ra_sle_psoriasis  ///
						bmi_date_measured   ///
						bp_sys_date_measured   ///
						bp_dias_date_measured   ///
						creatinine_date  ///
						smoking_status_date ///
						dereg_date  ///
						{
							
		capture confirm string variable `var'
		if _rc!=0 {
			assert `var'==.
			rename `var' `var'_date
		}
	
		else {
				replace `var' = `var' + "-15"
				rename `var' `var'_dstr
				replace `var'_dstr = " " if `var'_dstr == "-15"
				gen `var'_date = date(`var'_dstr, "YMD") 
				order `var'_date, after(`var'_dstr)
				drop `var'_dstr
		}
	
	format `var'_date %td
}

* Recode to dates from the strings 
foreach var of varlist  positive_covid_test covid_test_ever	///
covid_tpp_codes_clinical covid_tpp_codes_test covid_tpp_codes_seq ///
died_date_ons covid_admission_date covid_tpp_probable ///
covid_vacc_date  covid_vacc_second_dose_date	{
						
	confirm string variable `var'
	rename `var' `var'_dstr
	gen `var' = date(`var'_dstr, "YMD")
	drop `var'_dstr
	format `var' %td 	
}

*Amend vaccine dates
replace covid_vacc_second_dose_date=. if covid_vacc_date>=covid_vacc_second_dose_date
replace covid_vacc_second_dose_date=. if covid_vacc_date==. 

gen covid_admission_primary_date = covid_admission_date ///
if (covid_admission_primary_diagnosi == "U071"| covid_admission_primary_diagnosi == "U072")

gen  covid_primary_care_codes_only=covid_tpp_probable
format covid_primary_care_codes_only %td
replace covid_tpp_probable=positive_covid_test_ever if covid_tpp_probable==. & covid_tpp_probable>positive_covid_test


/*Tab all variables in initial extract*/
sum, d f


/*Flag earliest date under18s vaccinated*/
gen under18vacc_temp=covid_vacc_date if age<18
bysort household_id: egen under18vacc=min(under18vacc_temp)
format under18vacc* %td
/* CREATE VARIABLES===========================================================*/

/* DEMOGRAPHICS */ 

* Sex
gen male = 1 if sex == "M"
replace male = 0 if sex == "F"

* Ethnicity 
replace ethnicity = .u if ethnicity == .

label define ethnicity 	1 "White"  					///
						2 "Mixed" 					///
						3 "Asian or Asian British"	///
						4 "Black"  					///
						5 "Other"					///
						.u "Unknown"

label values ethnicity ethnicity

* STP 
rename stp stp_old
bysort stp_old: gen stp = 1 if _n==1
replace stp = sum(stp)
drop stp_old

/*  IMD  */
* Group into 5 groups
rename imd imd_o
egen imd = cut(imd_o), group(5) icodes

* add one to create groups 1 - 5 
replace imd = imd + 1

* - 1 is missing, should be excluded from population 
replace imd = .u if imd_o == -1
drop imd_o

* Reverse the order (so high is more deprived)
recode imd 5 = 1 4 = 2 3 = 3 2 = 4 1 = 5 .u = .u

label define imd 1 "1 least deprived" 2 "2" 3 "3" 4 "4" 5 "5 most deprived" .u "Unknown"
label values imd imd 

/*  Age variables  */ 

* Create categorised age 
recode age 18/29.9999 = 1 /// 
		   30/39.9999 = 2 /// 
           40/49.9999 = 3 ///
		   50/59.9999 = 4 ///
	       60/69.9999 = 5 ///
		   70/79.9999 = 6 ///
		   80/max = 7, gen(agegroup) 

label define agegroup 	1 "18-<30" ///
						2 "30-<40" ///
						3 "40-<50" ///
						4 "50-<60" ///
						5 "60-<70" ///
						6 "70-<80" ///
						7 "80+"
						
label values agegroup agegroup

* Create binary age (for age stratification)
recode age min/65.999999999 = 0 ///
           66/max = 1, gen(age66)

* Check there are no missing ages
assert age < .
assert agegroup < .
assert age66 < .


/* APPLY HH level INCLUSION/EXCLUIONS==================================================*/ 

noi di "DROP if HH ID==0"
count if household_id==0
drop if household_id==0
count

drop if care_home_type!="U"
count

noi di "DROP HH>=10 persons:"
sum household_size, d
drop if household_size>=10
count

noi di "DROP AGE MISSING:"
recode age .=9
recode age .u=9
bysort household_id: egen age_drop=max(age)
drop if age_drop==9
count

**************************** HOUSEHOLD VARS*******************************************
***KIDS_CAT5 (5 categories)
*Identify kids under 5/5-11/12-18
gen no_of_kids=1 if age<5
recode no_of_kids .=2 if age<12
recode no_of_kids .=3 if age<18 

*Make seperate files with only kids and household number
preserve
keep if age<18
keep household_id no_of_kids
*Drop duplicates (i.e. for hh with kids of same age, keep only one)
duplicates drop
*If a hh has >1 record, there must be mixed ages in it: flag these as category 4
bysort household_id: replace no_of_kids=4 if _N>1
duplicates drop
rename no_of_kids kids_cat5
save kids_mixed_category, replace
restore

*merge in kids identifier
merge m:1 household_id using kids_mixed_category, nogen keep(master match)

*label variable
lab define   kids_cat5 0 none  1 "only <5 years" ///
2 "only 5-11" 3 "12-<18" 4 "mixed"
lab val kids_cat5 kids_cat5
recode kids_cat5 .=0
tab kids_cat5
drop no_of_kids

***KIDS_CAT4 (4 categories)
*Identify kids under 0-11/12-18
gen no_of_kids=1 if age<12
recode no_of_kids .=2 if age<18 

*Make seperate files with only kids and household number
preserve
keep if age<18
keep household_id no_of_kids
*Drop duplicates (i.e. for hh with kids of same age, keep only one)
duplicates drop
*If a hh has >1 record, there must be mixed ages in it: flag these as category 4
bysort household_id: replace no_of_kids=3 if _N>1
duplicates drop
rename no_of_kids kids_cat4
list in 1/100
save kids_mixed_category, replace
restore

*merge in kids identifier
merge m:1 household_id using kids_mixed_category, nogen keep(master match)

*label variable
lab define   kids_cat4 0 none  1 "only <12 years" ///
2 "only 12-18" ///
3 "mixed"
lab val kids_cat4 kids_cat4
recode kids_cat4 .=0
tab kids_cat4

*Dose-response exposure: identify number of kids in hh where there are ONLY under 11 yr olds
bysort household_id: egen number_kids=sum(no_of_kids) if kids_cat4==1

gen gp_number_kids=number_kids
recode gp_number_kids 4/max=4

lab var gp_number_kids "Number kids under 12 years in hh"
lab define   gp_number_kids 0 none ///
1 "1 child <12" ///
2 "2 children <12" ///
3 "3 children <12" ///
4 "4+ children <12"
lab val gp_number_kids gp_number_kids

tab kids_cat4 
tab kids_cat5
tab kids_cat*


/* DROP ALL KIDS, AS HH COMPOSITION VARS ARE NOW MADE */
drop if age<18

*Total number adults in household (to check hh size)
bysort household_id: gen tot_adults_hh=_N
recode tot_adults_hh 3/max=3

tab kids_cat4
tab gp_num if kids_cat4==1

erase kids_mixed_category.dta

/* SET FU DATES===============================================================*/ 
* Censoring dates for each outcome (largely, last date outcome data available)
*****NEEDS UPDATING WHEN INFO AVAILABLE*******************

* Note - outcome dates are handled separtely below 

* Some names too long for loops below, shorten
rename permanent_immunodeficiency_date 	perm_immunodef_date
rename temporary_immunodeficiency_date 	temp_immunodef_date
rename bmi_date_measured_date  			bmi_measured_date
rename dereg_date_date 						dereg_date

/* CREATE BINARY VARIABLES====================================================*/
*  Make indicator variables for all conditions where relevant 

foreach var of varlist 	chronic_respiratory_disease ///
						chronic_cardiac_disease  ///
						diabetes_date  ///
						cancer_haem  ///
						cancer_nonhaem  ///
						perm_immunodef  ///
						temp_immunodef  ///
						dialysis					///
						kidney_transplant			///
						other_transplant 			/// 
						asplenia 			/// 
						chronic_liver_disease  ///
						other_neuro  ///
						stroke_dementia				///
						esrf  ///
						hypertension  ///
						ra_sle_psoriasis  ///
						bmi_measured_date   ///
						bp_sys_date_measured   ///
						bp_dias_date_measured   ///
						creatinine_date  ///
						smoking_status_date ///
						{
						
	/* date ranges are applied in python, so presence of date indicates presence of 
	  disease in the correct time frame */ 
	local newvar =  substr("`var'", 1, length("`var'") - 5)
	gen `newvar' = (`var'!=. )
	order `newvar', after(`var')
	
}




/*  Body Mass Index  */
* NB: watch for missingness

* Recode strange values 
replace bmi = . if bmi == 0 
replace bmi = . if !inrange(bmi, 15, 50)

* Restrict to within 10 years of index and aged > 16 
gen bmi_time = (date("$indexdate", "DMY") - bmi_measured_date)/365.25
gen bmi_age = age - bmi_time

replace bmi = . if bmi_age < 16 
replace bmi = . if bmi_time > 10 & bmi_time != . 

* Set to missing if no date, and vice versa 
replace bmi = . if bmi_measured_date == . 
replace bmi_measured_date = . if bmi == . 
replace bmi_measured = . if bmi == . 

gen 	bmicat = .
recode  bmicat . = 1 if bmi < 18.5
recode  bmicat . = 2 if bmi < 25
recode  bmicat . = 3 if bmi < 30
recode  bmicat . = 4 if bmi < 35
recode  bmicat . = 5 if bmi < 40
recode  bmicat . = 6 if bmi < .
replace bmicat = .u if bmi >= .

label define bmicat 1 "Underweight (<18.5)" 	///
					2 "Normal (18.5-24.9)"		///
					3 "Overweight (25-29.9)"	///
					4 "Obese I (30-34.9)"		///
					5 "Obese II (35-39.9)"		///
					6 "Obese III (40+)"			///
					.u "Unknown (.u)"
					
label values bmicat bmicat

* Create less  granular categorisation
recode bmicat 1/3 .u = 1 4 = 2 5 = 3 6 = 4, gen(obese4cat)

label define obese4cat 	1 "No record of obesity" 	///
						2 "Obese I (30-34.9)"		///
						3 "Obese II (35-39.9)"		///
						4 "Obese III (40+)"		

label values obese4cat obese4cat
order obese4cat, after(bmicat)


/*  Smoking  */

* Smoking 
label define smoke 1 "Never" 2 "Former" 3 "Current" .u "Unknown (.u)"

gen     smoke = 1  if smoking_status == "N"
replace smoke = 2  if smoking_status == "E"
replace smoke = 3  if smoking_status == "S"
replace smoke = .u if smoking_status == "M"
replace smoke = .u if smoking_status == "" 

label values smoke smoke
drop smoking_status

* Create non-missing 3-category variable for current smoking
* Assumes missing smoking is never smoking 
recode smoke .u = 1, gen(smoke_nomiss)
order smoke_nomiss, after(smoke)
label values smoke_nomiss smoke

/* CLINICAL COMORBIDITIES */ 

/*  Cancer */
label define cancer 1 "Never" 2 "Last year" 3 "2-5 years ago" 4 "5+ years"

* Haematological malignancies
gen     cancer_haem_cat = 4 if inrange(cancer_haem_date, d(1/1/1900), d(1/2/2015))
replace cancer_haem_cat = 3 if inrange(cancer_haem_date, d(1/2/2015), d(1/2/2019))
replace cancer_haem_cat = 2 if inrange(cancer_haem_date, d(1/2/2019), d(1/2/2020))
recode  cancer_haem_cat . = 1
label values cancer_haem_cat cancer


* All other cancers
gen     cancer_exhaem_cat = 4 if inrange(cancer_nonhaem_date,  d(1/1/1900), d(1/2/2015)) 
replace cancer_exhaem_cat = 3 if inrange(cancer_nonhaem_date,  d(1/2/2015), d(1/2/2019))
replace cancer_exhaem_cat = 2 if inrange(cancer_nonhaem_date,  d(1/2/2019), d(1/2/2020)) 
recode  cancer_exhaem_cat . = 1
label values cancer_exhaem_cat cancer


/*  Immunosuppression  */

* Immunosuppressed:
* Permanent immunodeficiency ever, OR 
* Temporary immunodeficiency  last year
gen temp1  = 1 if perm_immunodef_date!=.
gen temp2  = inrange(temp_immunodef_date, (date("$indexdate", "DMY") - 365), date("$indexdate", "DMY"))

egen other_immuno = rowmax(temp1 temp2)
drop temp1 temp2 
order other_immuno, after(temp_immunodef)

/*  Blood pressure   */

* Categorise
gen     bpcat = 1 if bp_sys < 120 &  bp_dias < 80
replace bpcat = 2 if inrange(bp_sys, 120, 130) & bp_dias<80
replace bpcat = 3 if inrange(bp_sys, 130, 140) | inrange(bp_dias, 80, 90)
replace bpcat = 4 if (bp_sys>=140 & bp_sys<.) | (bp_dias>=90 & bp_dias<.) 
replace bpcat = .u if bp_sys>=. | bp_dias>=. | bp_sys==0 | bp_dias==0

label define bpcat 1 "Normal" 2 "Elevated" 3 "High, stage I"	///
					4 "High, stage II" .u "Unknown"
label values bpcat bpcat

recode bpcat .u=1, gen(bpcat_nomiss)
label values bpcat_nomiss bpcat

* Create non-missing indicator of known high blood pressure
gen bphigh = (bpcat==4)

/*  Hypertension  */

gen htdiag_or_highbp = bphigh
recode htdiag_or_highbp 0 = 1 if hypertension==1 


************
*   eGFR   *
************

* Set implausible creatinine values to missing (Note: zero changed to missing)
replace creatinine = . if !inrange(creatinine, 20, 3000) 
	
* Divide by 88.4 (to convert umol/l to mg/dl)
gen SCr_adj = creatinine/88.4

gen min=.
replace min = SCr_adj/0.7 if male==0
replace min = SCr_adj/0.9 if male==1
replace min = min^-0.329  if male==0
replace min = min^-0.411  if male==1
replace min = 1 if min<1

gen max=.
replace max=SCr_adj/0.7 if male==0
replace max=SCr_adj/0.9 if male==1
replace max=max^-1.209
replace max=1 if max>1

gen egfr=min*max*141
replace egfr=egfr*(0.993^age)
replace egfr=egfr*1.018 if male==0
label var egfr "egfr calculated using CKD-EPI formula with no eth"

* Categorise into ckd stages
egen egfr_cat = cut(egfr), at(0, 15, 30, 45, 60, 5000)
recode egfr_cat 0=5 15=4 30=3 45=2 60=0, generate(ckd)
* 0 = "No CKD" 	2 "stage 3a" 3 "stage 3b" 4 "stage 4" 5 "stage 5"
label define ckd 0 "No CKD" 1 "CKD"
label values ckd ckd
*label var ckd "CKD stage calc without eth"

* Convert into CKD group
*recode ckd 2/5=1, gen(chronic_kidney_disease)
*replace chronic_kidney_disease = 0 if creatinine==. 
	
recode ckd 0=1 2/3=2 4/5=3, gen(reduced_kidney_function_cat)
replace reduced_kidney_function_cat = 1 if creatinine==. 
label define reduced_kidney_function_catlab ///
	1 "None" 2 "Stage 3a/3b egfr 30-60	" 3 "Stage 4/5 egfr<30"
label values reduced_kidney_function_cat reduced_kidney_function_catlab 
lab var  reduced "Reduced kidney function"


/*ESDR: dialysis or kidney transplant*/
gen esrd=1 if dialysis==1 | kidney_transplant==1
recode esrd .=0



***************************
/* DM / Hb1AC */
***************************


/*  Diabetes severity  */

* Set zero or negative to missing
replace hba1c_percentage   = . if hba1c_percentage <= 0
replace hba1c_mmol_per_mol = . if hba1c_mmol_per_mol <= 0

/* Express  HbA1c as percentage  */ 

* Express all values as perecentage 
noi summ hba1c_percentage hba1c_mmol_per_mol 
gen 	hba1c_pct = hba1c_percentage 
replace hba1c_pct = (hba1c_mmol_per_mol/10.929)+2.15 if hba1c_mmol_per_mol<. 

* Valid % range between 0-20  /195 mmol/mol
replace hba1c_pct = . if !inrange(hba1c_pct, 0, 20) 
replace hba1c_pct = round(hba1c_pct, 0.1)


/* Categorise hba1c and diabetes  */
/* Diabetes type */
gen dm_type=1 if diabetes_type=="T1DM"
replace dm_type=2 if diabetes_type=="T2DM"
replace dm_type=3 if diabetes_type=="UNKNOWN_DM"
replace dm_type=0 if diabetes_type=="NO_DM"

safetab dm_type diabetes_type
label define dm_type 0"No DM" 1"T1DM" 2"T2DM" 3"UNKNOWN_DM"
label values dm_type dm_type

/*Open safely diabetes codes with exeter algorithm
gen dm_type_exeter_os=1 if diabetes_exeter_os=="T1DM_EX_OS"
replace dm_type_exeter_os=2 if diabetes_exeter_os=="T2DM_EX_OS"
replace dm_type_exeter_os=0 if diabetes_exeter_os=="NO_DM"
label values  dm_type_exeter_os dm_type*/

* Group hba1c
gen 	hba1ccat = 0 if hba1c_pct <  6.5
replace hba1ccat = 1 if hba1c_pct >= 6.5  & hba1c_pct < 7.5
replace hba1ccat = 2 if hba1c_pct >= 7.5  & hba1c_pct < 8
replace hba1ccat = 3 if hba1c_pct >= 8    & hba1c_pct < 9
replace hba1ccat = 4 if hba1c_pct >= 9    & hba1c_pct !=.
label define hba1ccat 0 "<6.5%" 1">=6.5-7.4" 2">=7.5-7.9" 3">=8-8.9" 4">=9"
label values hba1ccat hba1ccat
safetab hba1ccat

gen hba1c75=0 if hba1c_pct<7.5
replace hba1c75=1 if hba1c_pct>=7.5 & hba1c_pct!=.
label define hba1c75 0"<7.5" 1">=7.5"
safetab hba1c75, m

* Create diabetes, split by control/not
gen     diabcat = 1 if dm_type==0 | dm_type==.
replace diabcat = 2 if dm_type==1 & inlist(hba1ccat, 0, 1)
replace diabcat = 3 if dm_type==1 & inlist(hba1ccat, 2, 3, 4)
replace diabcat = 4 if dm_type==2 & inlist(hba1ccat, 0, 1)
replace diabcat = 5 if dm_type==2 & inlist(hba1ccat, 2, 3, 4)
replace diabcat = 6 if dm_type==1 & hba1c_pct==. | dm_type==2 & hba1c_pct==.


label define diabcat 	1 "No diabetes" 			///
						2 "T1DM, controlled"		///
						3 "T1DM, uncontrolled" 		///
						4 "T2DM, controlled"		///
						5 "T2DM, uncontrolled"		///
						6 "Diabetes, no HbA1c"
label values diabcat diabcat
safetab diabcat, m
recode diabcat .=1



/*  Asthma  */


* Asthma  (coded: 0 No, 1 Yes no OCS, 2 Yes with OCS)
rename asthma asthmacat
recode asthmacat 0=1 1=2 2=3
label define asthmacat 1 "No" 2 "Yes, no OCS" 3 "Yes with OCS"
label values asthmacat asthmacat

gen asthma = (asthmacat==2|asthmacat==3)

/*  Probable shielding  */
gen shield=1 if esrd==1 | other_transplant==1 | asthmacat==2 | asthmacat==3 | ///
chronic_respiratory_disease==1 | cancer_haem==1 | cancer_nonhaem==1 | ///
asplenia==1 | other_immuno==1
recode shield .=0

/*Any comorbidity*/

gen anycomorb=1 if chronic_respiratory_disease==1 | ///
                    asthmacat==2 | asthmacat==3 | ///
					chronic_cardiac_disease==1  | ///
					diabcat==2 | diabcat==3 | diabcat==4 | diabcat==5 | diabcat==6 | ///
					cancer_haem==1 | cancer_nonhaem==1 | ///
					esrd==1 | ///
					chronic_liver_disease==1 | ///
					stroke_dementia==1 | ///
					other_neuro==1 | ///
					other_transplant==1 | ///
					asplenia==1 | ///
					ra_sle_psoriasis==1 | ///
					other_immuno==1 
recode anycomorb .=0
tab anyco

* Comorbidities of interest 
label var asthma						"Asthma category"
label var egfr_cat						"Calculated eGFR"
label var hypertension				    "Diagnosed hypertension"
label var chronic_respiratory_disease 	"Chronic Respiratory Diseases"
label var chronic_cardiac_disease 		"Chronic Cardiac Diseases"
label var diabcat						"Diabetes"
label var cancer_haem_cat						"Haematological cancer"
label var cancer_exhaem_cat						"Non-haematological cancer"
label var kidney_transplant						"Kidney transplant"	
label var other_transplant 	 					"Other solid organ transplant"
label var asplenia 						"Asplenia"
label var other_immuno					"Immunosuppressed (combination algorithm)"
label var chronic_liver_disease 		"Chronic liver disease"
label var other_neuro 			"Neurological disease"			
label var stroke_dementia 			    "Stroke or dementia"							
label var ra_sle_psoriasis				"Autoimmune disease"
lab var egfr							eGFR
lab var perm_immunodef  				"Permanent immunosuppression"
lab var temp_immunodef  				"Temporary immunosuppression"
lab var esrd 							"End-stage renal disease"

lab var covid_vacc_date 			"First vacc date"
lab var covid_vacc_second_dose_date "Second vacc date"

/* OUTCOME AND SURVIVAL TIME==================================================*/

gen enter_date = date("$indexdate", "DMY")
gen study_end_censor =date("$study_end_censor", "DMY")

* Format the dates
format 	enter_date					///
		study_end_censor  
		
			/****   Outcome definitions   ****/

* Date of Covid death in ONS
gen died_date_onscovid = died_date_ons if died_ons_covid_flag_any == 1
gen died_date_onscovid_part1 = died_date_ons if died_ons_covid_flag_underlying == 1

* Date of non-COVID death in ONS 
* If missing date of death resulting died_date will also be missing
gen died_date_onsnoncovid = died_date_ons if died_ons_covid_flag_any != 1 

*Date probable covid in TPP
rename covid_tpp_probable date_covid_tpp_prob
rename covid_test_ever date_covid_test_ever

format died_date_ons %td
format died_date_onscovid %td 
format died_date_onsnoncovid %td
format died_date_onscovid_part1 %td
format covid_admission_primary_date %td
format date_covid_test_ever %td

* Binary indicators (0/1) for outcomes
gen covid_tpp_prob = (date_covid_tpp_prob < .)
gen non_covid_death = (died_date_onsnoncovid < .)
gen covid_death = (died_date_onscovid < .)
gen covidadmission = (covid_admission_primary_date < .)
gen covid_death_part1 = (died_date_onscovid_part1 < .)
gen covid_test_ever = (date_covid_test_ever < .)

					/**** Create survival times  ****/
* For looping later, name must be stime_binary_outcome_name

* Survival time = last followup date (first: end study, death, or that outcome)
*gen stime_onscoviddeath = min(onscoviddeathcensor_date, 				died_date_ons)
gen stime_covid_death_part1 	= min(study_end_censor   , died_date_onscovid_part1, died_date_ons, dereg_date)
gen stime_covid_tpp_prob = min(study_end_censor   , died_date_ons, date_covid_tpp_prob, dereg_date)
gen stime_non_covid_death = min(study_end_censor   , died_date_ons, died_date_onsnoncovid, dereg_date)
gen stime_covid_death = min(study_end_censor   , died_date_ons, died_date_onscovid, dereg_date)
gen stime_covidadmission 	= min(study_end_censor   , covid_admission_primary_date, died_date_ons, dereg_date)
gen stime_covid_test_ever = min(study_end_censor, died_date_ons, date_covid_test_ever, dereg_date)


* If outcome was after censoring occurred, set to zero
replace covid_tpp_prob = 0 if (date_covid_tpp_prob > study_end_censor ) 
replace non_covid_death = 0 if (died_date_onsnoncovid > study_end_censor )
replace covid_death = 0 if (died_date_onscovid > study_end_censor )
replace covidadmission 	= 0 if (covid_admission_primary_date > study_end_censor  | covid_admission_primary_date > died_date_ons) 
replace covid_death_part1 = 0 if (died_date_onscovid_part1 > study_end_censor )
replace covid_test_ever = 0 if (date_covid_test_ever > study_end_censor )


* If outcome was after censoring occurred, set date to missing
replace date_covid_tpp_prob = . if (date_covid_tpp_prob > study_end_censor ) 
replace died_date_onsnoncovid = . if (died_date_onsnoncovid > study_end_censor )
replace died_date_onscovid = . if (died_date_onscovid > study_end_censor )
replace covid_admission_primary_date 	= . if (covid_admission_primary_date > study_end_censor  | covid_admission_primary_date > died_date_ons) 
replace died_date_onscovid_part1 = . if (died_date_onscovid_part1 > study_end_censor )
replace date_covid_test_ever = . if (date_covid_test_ever > study_end_censor ) 


* Format date variables
format  stime* %td  
gen positive_SGSS = (positive_covid_test_ever < .)
gen covid_primary_care_codes = (covid_primary_care_codes_only < .)
rename positive_covid_test_ever date_positive_SGSS
rename covid_primary_care_codes_only date_covid_primary_care_codes
replace covid_primary_care_codes = 0 if (date_covid_primary_care_codes > study_end_censor )
replace positive_SGSS = 0 if (date_positive_SGSS > study_end_censor )

replace date_covid_primary_care_codes = . if (date_covid_primary_care_codes > study_end_censor )
replace date_positive_SGSS = . if (date_positive_SGSS > study_end_censor )


gen reported_infection_source=1 if covid_tpp_prob==1
recode reported_infection_source 1=2 if date_covid_tpp_prob== covid_tpp_codes_test 
recode reported_infection_source 1=3 if date_covid_tpp_prob==covid_tpp_codes_seq 
recode reported_infection_source 1=4 if date_covid_tpp_prob==covid_tpp_codes_clinical 
lab define reported_infection_source 1 SGSS 2 test_code 3 sequalae_code 4 diagnosis_code
lab val reported_infection_source reported_infection_source




/* LABEL VARIABLES============================================================*/
*  Label variables you are intending to keep, drop the rest 

*HH variable
label var  number_kids "Number of children aged 1-<12 years in household"
label var  household_size "Number people in household"
label var  household_id "Household ID"


* Demographics
label var patient_id				"Patient ID"
label var age 						"Age (years)"
label var agegroup					"Grouped age"
label var age66 					"66 years and older"
label var male 						"Male"
label var bmi 						"Body Mass Index (BMI, kg/m2)"
label var bmicat 					"Grouped BMI"
label var bmi_measured_date  		"Body Mass Index (BMI, kg/m2), date measured"
label var obese4cat					"Evidence of obesity (4 categories)"
label var smoke		 				"Smoking status"
label var smoke_nomiss	 			"Smoking status (missing set to non)"
label var imd 						"Index of Multiple Deprivation (IMD)"
label var ethnicity					"Ethnicity"
label var stp 						"Sustainability and Transformation Partnership"
lab var tot_adults_hh 				"Total number adults in hh"
lab var kids_cat4					"Exposure (v2) with 4-cats"
lab var kids_cat5					 "Exposure (v3) with 5-cats"

* Comorbidities of interest 
label var asthma						"Asthma category"
label var egfr_cat						"Calculated eGFR"
label var hypertension				    "Diagnosed hypertension"
label var chronic_respiratory_disease 	"Chronic Respiratory Diseases"
label var chronic_cardiac_disease 		"Chronic Cardiac Diseases"
label var diabcat						"Diabetes"
label var cancer_haem_cat						"Haematological cancer"
label var cancer_exhaem_cat						"Non-haematological cancer"
label var kidney_transplant						"Kidney transplant"	
label var other_transplant 	 					"Other solid organ transplant"
label var asplenia 						"Asplenia"
label var other_immuno					"Immunosuppressed (combination algorithm)"
label var chronic_liver_disease 		"Chronic liver disease"
label var other_neuro 			"Neurological disease"			
label var stroke_dementia 			    "Stroke or dementia"							
label var ra_sle_psoriasis				"Autoimmune disease"
lab var egfr							eGFR
lab var perm_immunodef  				"Permanent immunosuppression"
lab var temp_immunodef  				"Temporary immunosuppression"
lab var esrd 							"End-stage renal disease"
lab var anycomorb						"Any comorbidity"

label var hypertension_date			   		"Diagnosed hypertension Date"
label var chronic_respiratory_disease_date 	"Other Respiratory Diseases Date"
label var chronic_cardiac_disease_date		"Other Heart Diseases Date"
label var diabetes_date						"Diabetes Date"
label var cancer_haem_date 					"Haem cancer Date"
label var cancer_nonhaem_date 				"Non-haem cancer Date"
label var chronic_liver_disease_date  		"Chronic liver disease Date"
label var other_neuro_date 		"Neurological disease  Date"
label var stroke_dementia_date			    "Stroke or dementia date"							
label var ra_sle_psoriasis_date 			"Autoimmune disease  Date"
lab var perm_immunodef_date  				"Permanent immunosuppression date"
lab var temp_immunodef_date   				"Temporary immunosuppression date"
label var kidney_transplant_date						"Kidney transplant"	
label var other_transplant_date 					"Other solid organ transplant"
label var asplenia_date  						"Asplenia date"
lab var  bphigh "non-missing indicator of known high blood pressure"
lab var bpcat "Blood pressure four levels, non-missing"
lab var htdiag_or_highbp "High blood pressure or hypertension diagnosis"
lab var shield "Probable shielding"

* Outcomes and follow-up
label var enter_date					"Date of study entry"
label var study_end_censor    			"Date of admin censoring for outcomes"

label var  covid_tpp_prob				"Failure/censoring indicator for outcome: covid prob case"
label var  non_covid_death				"Failure/censoring indicator for outcome: non-covid death"
label var  covid_death				    "Failure/censoring indicator for outcome: covid death"
label var  covid_test_ever				    "Failure/censoring indicator for outcome: covid test ever"
lab var covidadmission 					"Failure/censoring indicator for outcome: covid SUS admission"
lab var covid_death_part1				"Failure/censoring indicator for outcome: covid death part1"
lab var  positive_SGSS		"Indicator positive covid test"
lab var  covid_primary_care_codes		"Indicator positive primary care code COVID infection"
lab var reported_infection_source 		"Reported Infection Source"
lab var lft_pcr "Type of test taken"

rename died_date_onsnoncovid date_non_covid_death
rename died_date_onscovid date_covid_death
rename covid_admission_primary_date date_covidadmission
label var date_covid_tpp_prob			"Date of probable COVID-19 clinical infection"
label var date_non_covid_death	 		"Date of ONS non-COVID-19 Death"
label var  date_covid_death			"Date of ONS COVID-19 Death"
lab var date_covidadmission			"Date of admission to hospital for COVID-19" 
label var  died_date_onscovid_part1			"Date of ONS COVID Death part1"
lab var  date_positive_SGSS		"Date of positive SGSS test"
lab var   date_covid_primary_care_codes "Date of COVID-19 primary care code"
lab var   date_covid_test_ever  "Date of COVID-19 test"

* Survival times
label var  stime_covid_tpp_prob				"Survival tme (date); outcome "
label var  stime_non_covid_death			"Survival tme (date); outcome non_covid_death	"
label var  stime_covid_death				"Survival time (date); outcome covid death"
label var  stime_covidadmission				"Survival time (date); outcome covid hosp admission"
label var  stime_covid_death_part1				"Survival time (date); outcome covid death part1"
label var  stime_covid_test_ever				"Survival time (date); outcome covid test"

*Key DATES
label var   died_date_ons				"Date death ONS"
label var  has_12_m_follow_up			"Has 12 months follow-up"
lab var  dereg_date						"Date deregistration from practice"
lab var under18vacc						"Date first child in hh vaccinated"



/* TIDY DATA==================================================================*/
*  Drop variables that are not needed (those not labelled)
ds, not(varlabel)
drop `r(varlist)'
drop covid_admission_primary_diagnosi	

	

/* APPLY INCLUSION/EXCLUIONS==================================================*/ 

*************TEMP DROP TO INVESTIGATE ASSOCIATIONS MORE EASILY******************
noi di "DROP AGE >110:"
drop if age > 110 & age != .
count

noi di "DROP IF DIED BEFORE INDEX"
drop if died_date_ons <=enter_date
count

noi di "DROP IF COVID IN TPP BEFORE INDEX"
drop if date_covid_tpp_prob <=enter_date
count

noi di "DROP IMD MISSING"
recode imd .=9
recode imd .u=9
drop if imd==9
count

noi di "DROP MISSING GENDER:"
recode male .=9
recode male .u=9
drop if male==9
count	
	
***************
*  Save data  *
***************
sort patient_id
save $tempdir/analysis_dataset_with_missing_ethnicity, replace

noi di "DROP NO ETHNICITY DATA"
keep if ethnicity!=.u	

save $tempdir/analysis_dataset, replace



use  $tempdir/analysis_dataset, clear
keep if age<=65
* Create restricted cubic splines for age
mkspline age = age, cubic nknots(4)
save $tempdir/analysis_dataset_ageband_0, replace


use  $tempdir/analysis_dataset, clear
keep if age>65
* Create restricted cubic splines for age
mkspline age = age, cubic nknots(4)
save $tempdir/analysis_dataset_ageband_1, replace



forvalues x=0/1 {

use $tempdir/analysis_dataset_ageband_`x', clear
	
/*no longer using composite outcome
use $tempdir/analysis_dataset_ageband_`x', clear
* Save a version set on covid death/icu  outcome
stset stime_covid_death_icu, fail(covid_death_icu) 				///
	id(patient_id) enter(enter_date) origin(enter_date)
save "$tempdir/cr_create_analysis_dataset_STSET_covid_death_icu_ageband_`x'.dta", replace
*/
use $tempdir/analysis_dataset_ageband_`x', clear
* Save a version set on covid test ever  outcome only
stset stime_covid_test_ever, fail(covid_test_ever) 				///
	id(patient_id) enter(enter_date) origin(enter_date)
save "$tempdir/cr_create_analysis_dataset_STSET_covid_test_ever_ageband_`x'.dta", replace

use $tempdir/analysis_dataset_ageband_`x', clear
* Save a version set on covid death only
stset stime_covid_death, fail(covid_death) 				///
	id(patient_id) enter(enter_date) origin(enter_date)
save "$tempdir/cr_create_analysis_dataset_STSET_covid_death_ageband_`x'.dta", replace

/*this was created for investigation only
use $tempdir/analysis_dataset_ageband_`x', clear
* Save a version set on covid death only
stset stime_covid_death_part1, fail(covid_death_part1) 				///
	id(patient_id) enter(enter_date) origin(enter_date)
save "$tempdir/cr_create_analysis_dataset_STSET_covid_death_part1_ageband_`x'.dta", replace
*/
use $tempdir/analysis_dataset_ageband_`x', clear
* Save a version set on probable covid
stset stime_covid_tpp_prob, fail(covid_tpp_prob) 				///
	id(patient_id) enter(enter_date) origin(enter_date)
save "$tempdir/cr_create_analysis_dataset_STSET_covid_tpp_prob_ageband_`x'.dta", replace	

use $tempdir/analysis_dataset_ageband_`x', clear
* Save a version set on hosp admission for covid
stset stime_covidadmission, fail(covidadmission) 				///
	id(patient_id) enter(enter_date) origin(enter_date)
save "$tempdir/cr_create_analysis_dataset_STSET_covidadmission_ageband_`x'.dta", replace	

}

* Close log file 
log close

