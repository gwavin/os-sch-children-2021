/*==============================================================================
DO FILE NAME:			02_an_data_checks
PROJECT:				Exposure children and COVID risk
AUTHOR:					HFORBES Adapted from A Wong, A Schultze, C Rentsch
						 K Baskharan, E Williamson
DATE: 					30th June 2020 
DESCRIPTION OF FILE:	Run sanity checks on all variables
							- Check variables take expected ranges 
							- Cross-check logical relationships 
							- Explore expected relationships 
							- Check stsettings 
DATASETS USED:			$tempdir/`analysis_dataset'.dta
DATASETS CREATED: 		None
OTHER OUTPUT: 			Log file: $logdir/02_an_data_checks
							
==============================================================================*/

global outdir  	  "output"
global logdir     "logs"
global tempdir    "tempdata"




*first argument main W2 
local dataset `1'
if "`dataset'"=="MAIN" local fileextension
else local fileextension "`1'"
local inputfile "analysis_dataset`dataset'"

* Open a log file

capture log close
log using $logdir/02_an_data_checks`fileextension', replace t

* Open Stata dataset
use $tempdir/`inputfile', clear

*run ssc install if not on local machine - server needs datacheck.ado file
*ssc install datacheck 

*Duplicate patient check
datacheck _n==1, by(patient_id) nol


/* CHECK INCLUSION AND EXCLUSION CRITERIA=====================================*/ 

* DATA STRUCTURE: Confirm one row per patient 
duplicates tag patient_id, generate(dup_check)
assert dup_check == 0 
drop dup_check

* INCLUSION 1: >=18 and <=110 at 1 March 2020 
assert age < .
assert age >= 18 
assert age <= 110


* EXCLUDE 1:  MISSING IMD
assert inlist(imd, 1, 2, 3, 4, 5)

* EXCLUDE 2:  HH with more than 10 people
datacheck inlist(household_size, 1, 2, 3, 4, 5,6, 7, 8, 9, 10), nol

/* EXPECTED VALUES============================================================*/ 

*HH
datacheck kids_cat4<., nol
datacheck inlist(kids_cat4, 0,1, 2), nol

datacheck number_kids<., nol
datacheck inlist(number_kids, 0,1,2,3,4,5,6,7,8,9), nol

* Age
datacheck age<., nol
datacheck inlist(agegroup, 1, 2, 3, 4, 5, 6,7), nol
datacheck inlist(age66, 0, 1), nol

* Sex
datacheck inlist(male, 0, 1), nol

* BMI 
datacheck inlist(obese4cat, 1, 2, 3, 4), nol
datacheck inlist(bmicat, 1, 2, 3, 4, 5, 6, .u), nol

* IMD
datacheck inlist(imd, 1, 2, 3, 4, 5), nol

* Ethnicity
datacheck inlist(ethnicity, 1, 2, 3, 4, 5, .u), nol

* Smoking
datacheck inlist(smoke, 1, 2, 3, .u), nol
datacheck inlist(smoke_nomiss, 1, 2, 3), nol 


* Check date ranges for all comorbidities 

foreach var of varlist  chronic_respiratory_disease 	///
					chronic_cardiac_disease		///
					chronic_liver_disease  		///
					other_neuro 			///
					stroke_dementia ///
					ra_sle_psoriasis				///
					perm_immunodef  ///
					temp_immunodef  ///
					other_transplant 			/// 
					asplenia 			/// 
					hypertension			 	///
					{
						
	summ `var'_date, format

}

foreach comorb in $varlist { 
	local comorb: subinstr local comorb "i." ""
	safetab `comorb', m
}

*summarise end dates for each outcome
foreach outcome in date_covid_tpp_prob	date_covid_test_ever date_non_covid_death	date_covid_death	date_covidadmission	died_date_onscovid_part1	 {
sum `outcome', format
}

foreach outcome in date_covid_tpp_prob	date_non_covid_death	date_covid_death	date_covidadmission	died_date_onscovid_part1	 {
gen `outcome'_month=mofd(`outcome') 
 lab define `outcome'_month 731 "Dec 2020" 734 "March 2020"  738 "July 2020"
lab val `outcome'_month `outcome'_month
tab `outcome'_month
drop `outcome'_month
}

*Outcome dates
di d(1jan2021) /*study start*/
*22281
di d(01mar2021) 
*22340
di d(01may2021)
*22401
di d(01july2021)
*22462
di d(01sept2021) 
*22524
di d(22oct2021) 
*22575

gen agegp=0 if age<=65
replace agegp=1 if age>65
tab agegp, miss

foreach age in 0 1 {
foreach outcome of any covid_tpp_prob covidadmission covid_death    {
summ  `outcome' if agegp==`age', format d 
summ patient_id if `outcome'==1 & date_`outcome'<=22576 & agegp==`age'
local total_`outcome'=`r(N)'
hist date_`outcome' if date_`outcome'<=22576 & agegp==`age', saving(output/`outcome'_age`age', replace) ///
xlabel(22281 22340 22401 22462 22524,labsize(tiny))  xtitle(, size(vsmall)) ///
graphregion(color(white))  legend(off) freq  ///
ylabel(0 5000,labsize(tiny))  ytitle("Number", size(vsmall)) ///
title("N=`total_`outcome''", size(vsmall)) width(5) yline(5, lcolor(black%100)  lwidth(thick)) color(black%100)
}
}


di (5/4000)*100
*addplot(pci 0 20 .1 20): With the 2 supplied coordinates, we are just 
*connecting the line from the point (y=0,x=20) to (y=.1,x=20) -- a 
*vertical line at x=20. 

* Combine histograms
graph combine output/covid_tpp_prob_age0.gph output/covid_tpp_prob_age1.gph ///
output/covidadmission_age0.gph output/covidadmission_age1.gph ///
output/covid_death_age0.gph output/covid_death_age1.gph, graphregion(color(white)) col(2) ysize(10)
graph export "output/01_histogram_outcomes.svg", as(svg) replace 

*censor dates
summ dereg_date, format
summ has_12_m

count if covid_vacc_date>=covid_vacc_second_dose_date
*Vacc data
foreach age in 0 1 {
foreach vacc of any covid_vacc_date covid_vacc_second_dose_date   {
summ  `vacc'  if agegp==`age', format d 
summ patient_id if `vacc'!=. & `vacc'<=22576 & agegp==`age'
local total=`r(N)' 
hist `vacc' if `vacc'<=22576  & agegp==`age', saving(output/`vacc'_age`age', replace) ///
xlabel(22281 22340 22401 22462 22524,labsize(tiny))  xtitle(, size(vsmall)) ///
graphregion(color(white))  legend(off) freq ylabel(0 500000,labsize(tiny)) ///
ytitle("Number", size(vsmall))   ///
title("N=`total'", size(vsmall))  yline(5, lcolor(black%100)  lwidth(thick)) color(black%100)
}
}

*Combine histograms
graph combine output/covid_vacc_date_age0.gph output/covid_vacc_date_age1.gph  output/covid_vacc_second_dose_date_age0.gph output/covid_vacc_second_dose_date_age1.gph, ///
 graphregion(color(white)) col(2)
graph export "output/01_histogram_vaccinations.svg", as(svg) replace 

tab lft_pcr
tab lft_pcr if date_covid_tpp_prob!=.
tab kids_cat4 lft_pcr if date_covid_tpp_prob!=., col chi



/* LOGICAL RELATIONSHIPS======================================================*/ 

*HH variables
safetab kids_cat4 tot_adults_hh
safetab number_kids tot_adults_hh
safetab household_size tot_adults_hh

* BMI
bysort bmicat: summ bmi
safetab bmicat obese4cat, m

* Age
bysort agegroup: summ age
safetab agegroup age66, m

* Smoking
safetab smoke smoke_nomiss, m

* Diabetes
*safetab diabcat diabetes, m

* CKD
safetab reduced egfr_cat, m
* CKD
safetab reduced esrd, m

/* EXPECTED RELATIONSHIPS=====================================================*/ 

/*  Relationships between demographic/lifestyle variables  */
safetab agegroup bmicat, 	row 
safetab agegroup smoke, 	row  
safetab agegroup ethnicity, row 
safetab agegroup imd, 		row 
safetab agegroup shield,    row 

safetab bmicat smoke, 		 row   
safetab bmicat ethnicity, 	 row 
safetab bmicat imd, 	 	 row 
safetab bmicat hypertension, row 
safetab bmicat shield,    row 

                            
safetab smoke ethnicity, 	row 
safetab smoke imd, 			row 
safetab smoke hypertension, row 
safetab smoke shield,    row 
                      
safetab ethnicity imd, 		row 
safetab shield imd, 		row 

safetab shield ethnicity, 		row 



* Relationships with age
foreach var of varlist  asthma						///
					chronic_respiratory_disease 	///
					chronic_cardiac_disease		///
					diabcat 						///
					chronic_liver_disease  		///
					other_neuro 			///
					stroke_dementia ///
					ra_sle_psoriasis				///
					other_immuno 				///
					other_transplant 			/// 
					asplenia 			/// 
					cancer_exhaem_cat 						///
					cancer_haem_cat 						///
					reduced_kidney_function_cat ///
					esrd 					///
					hypertension		///	 	
										{

		
 	safetab agegroup `var', row 
 }


*Relationships with sex
foreach var of varlist asthma						///
					chronic_respiratory_disease 	///
					chronic_cardiac_disease		///
					diabcat						///
					chronic_liver_disease  		///
					other_neuro 			///
					stroke_dementia ///
					ra_sle_psoriasis				///
					other_immuno 				///
					other_transplant 			/// 
					asplenia 			/// 
					cancer_exhaem_cat 						///
					cancer_haem_cat 						///
					reduced_kidney_function_cat ///
					esrd 					///
					hypertension			 ///	
										{
						
 	safetab male `var', row 
}

*Relationships with smoking
foreach var of varlist  asthma						///
					chronic_respiratory_disease 	///
					chronic_cardiac_disease		///
					diabcat						///
					chronic_liver_disease  		///
					other_neuro 			///
					stroke_dementia ///
					ra_sle_psoriasis				///
					other_immuno 				///
					other_transplant 			/// 
					asplenia 			/// 
					cancer_exhaem_cat 						///
					cancer_haem_cat 						///
					reduced_kidney_function_cat ///
					esrd					///
					hypertension			 	///
					{
	
 	safetab smoke `var', row 
}


/* SENSE CHECK OUTCOMES=======================================================*/


safecount if covidadmission==1 & covid_death==1

sum positive_SGSS
sum positive_SGSS if date_positive_SGSS<=22267

safetab positive_SGSS covid_primary_care_codes, row col miss
safetab positive_SGSS covid_primary_care_codes if date_positive_SGSS<=22267 & date_covid_primary_care_codes<=22267, row col miss
gen diff=date_positive_SGSS-date_covid_primary_care_codes 
sum diff, d

tab reported if kids_cat4!=0 & age<=65
tab reported if kids_cat4==0 & age<=65


/* DEATHS by STP=======================================================*/
tab  stp covid_death, col

* Close log file 
log close


