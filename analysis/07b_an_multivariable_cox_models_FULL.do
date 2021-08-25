********************************************************************************
*
*	Do-file:		07b_an_multivariable_cox_models.do
*
*	Project:		Exposure children and COVID risk
*
*	Programmed by:	Hforbes, based on files from Fizz & Krishnan
*
*	Data used:		analysis_dataset.dta
*
*	Data created:	None
*
*	Other output:	Log file:  an_multivariable_cox_models.log
*
********************************************************************************
*
*	Purpose:		This do-file performs multivariable (fully adjusted) 
*					Cox models. 
*  
********************************************************************************
*	
*	Stata routines needed:	stbrier	  
*
********************************************************************************

* Set globals that will print in programs and direct output
global outdir  	  "output" 
global logdir     "logs"
global tempdir    "tempdata"
global demogadjlist  age1 age2 age3 i.male i.obese4cat i.smoke_nomiss i.imd i.tot_adults_hh i.ethnicity
global comordidadjlist  i.htdiag_or_highbp				///
			i.chronic_respiratory_disease 	///
			i.asthma						///
			i.chronic_cardiac_disease 		///
			i.diabcat						///
			i.cancer_exhaem_cat	 			///
			i.cancer_haem_cat  				///
			i.chronic_liver_disease 		///
			i.stroke_dementia		 		///
			i.other_neuro					///
			i.reduced_kidney_function_cat	///
			i.esrd							///
			i.other_transplant 				///
			i.asplenia 						///
			i.ra_sle_psoriasis  			///
			i.other_immuno		

local outcome `1' 

************************************************************************************
*First clean up all old saved estimates for this outcome
*This is to guard against accidentally displaying left-behind results from old runs
************************************************************************************

* Open a log file
capture log close
log using "$logdir/07b_an_multivariable_cox_models_`outcome'", text replace


*************************************************************************************

*************************************************************************************
local outcome `1'

* Open dataset and fit specified model(s)
forvalues x=0/1 {
use "$tempdir/cr_create_analysis_dataset_STSET_`outcome'_ageband_`x'.dta", clear
forvalues period=0/2 {

*Split data by time of study period: 
*-School closure: 20th December 2020 (previous analysis up to 19th December 2020) 
*-alpha variant 15th March 2021 
*-delta variant 24th May 2021 

if "`outcome'"=="covid_tpp_prob" {
stsplit cat_time, at(0,85,154,400)
recode cat_time 85=1 154=2 400=3
recode `outcome' .=0 
tab cat_time
tab cat_time `outcome'
}

*-School closure: 20th December 2020 (previous analysis up to 19th December 2020) 
*-alpha variant 22nd March 2021 
*-delta variant 31st May 2021 
if "`outcome'"=="covidadmission" | "`outcome'"=="covid_death" {
stsplit cat_time, at(0,92,161,400)
recode cat_time 92=1 161=2 400=3
recode `outcome' .=0 
tab cat_time
tab cat_time `outcome'
}
 
******************************
*  Multivariable Cox models  *
******************************



foreach exposure_type in kids_cat4  {

*Age spline model (not adj ethnicity)
stcox 	i.`exposure_type' 	age1 age2 age3			///
			$demogadjlist	 			  	///
			$comordidadjlist				///
			if cat_time==`period'							///
			, strata(stp) vce(cluster household_id)
if _rc==0{
estimates
estimates save "./output/an_multivariate_cox_models_`outcome'_`exposure_type'_FULLYADJMODEL_ageband_`x'_timeperiod`period'", replace
	/*  Proportional Hazards test 
	* Based on Schoenfeld residuals	
	timer clear 
	timer on 1
	if e(N_fail)>0 estat phtest, d
	timer off 1
	timer list */
	
}
else di "WARNING AGE SPLINE MODEL DID NOT FIT (OUTCOME `outcome')"

}
drop cat_time
}
}
log close
exit, clear
