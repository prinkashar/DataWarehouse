**********************************************************************

*TEAM HEARTLAND
*LOCAL FOOD MANUFACTURING GAP INDEX
*KANSAS STATE UNIVERSITY

*PURPOSE OF FILE - PREDICTION

Priyanka Sharma, Jiyeon Kim, Walter Ac Pangan (2024-07-19). Drivers of New Local Food Business Establishment: The Case of the Small Food Manufacturing Industry (NAICS 311) in the Heartland Region, v1.0. USDA AMS Data Warehouse.
**********************************************************************

**********************************************************************
*This Do file do random forest analysis and provide final data for new business development index.

*Last Edited July 18, 2024
**********************************************************************

*Define the main directory for this project
*Desktop:
global data "C:\Users\Priyanka\OneDrive - Kansas State University\AAEA Data Visualization\Challenge Deliverables"

*Set the current working directory
cd "$data"

clear all
set more off


**********************************************************************
*Random Forest
**********************************************************************
import delimited using "3. InputFile.csv", clear

*Replace
replace small_business=0 if small_business==.&_merge_cfs!=""

ssc install rforest, replace

*Display names of all variables
ds, varwidth(32)

*Estimation
local varlist shipvalueperdistance shipvalueperdistance_tempco value_d2c_farms value_d2c_farms_pct value_d2c_sales value_d2c_sales_pct value_intermediated_farms value_intermediated_farms_pct value_intermediated_sales value_intermediated_sales_pct value_local_sales value_local_sales_pct value_valueadded_farms value_valueadded_farms_pct value_valueadded_sales value_valueadded_sales_pct value_total_acres_operated value_total_number_operations value_total_number_producers value_2023_number_csa value_2023_number_farmersmarket value_2023_number_onfarmmarket selfemploymentoutoftotal annual_avg_estabs_count annual_avg_emplvl total_annual_wages scaledsci pop2020 median_household_income_2021 gdppercapita

rforest small_business `varlist' if small_business!=., type(reg) seed(1123)

predict pSmall_Business_importance1 
gen gap_importance1=pSmall_Business_importance1-small_business
gen gap_pct_importance1=gap_importance1/small_business
replace gap_pct_importance1=gap_importance1/(small_business+1) if small_business==0
/*
*Estimation
rforest small_business ShipValuePerDistance ShipValuePerDistance_TempCo value_d2c_farms value_d2c_farms_pct value_d2c_sales value_d2c_sales_pct value_intermediated_farms value_intermediated_farms_pct value_intermediated_sales value_intermediated_sales_pct value_local_sales value_local_sales_pct value_valueadded_farms value_valueadded_farms_pct value_valueadded_sales value_valueadded_sales_pct value_total_acres_operated value_total_number_operations value_total_number_producers value_2023_number_csa value_2023_number_farmersmarket value_2023_number_onfarmmarket selfemploymentoutoftotal annual_avg_estabs_count annual_avg_emplvl total_annual_wages avg_annual_pay ScaledSCI pop2020 Median_Household_Income_2021 GDPpercapita, type(reg) seed(1123)
*/

matrix importance = e(importance)

svmat importance

gen id=""
local mynames : rownames importance
local k : word count `mynames'

forvalues j = 1(1)`k' {
	local aword : word `j' of `mynames'
	local alabel : variable label `aword'
	if ("`alabel'"!="") qui replace id= "`alabel'" in `j'
	else qui replace id= "`aword'" in `j'
}

graph hbar (mean) importance, over(id, sort(1) descending label(labsize(2))) ytitle(Importance) graphregion(color(white)) name(importance1)

 
**********************************************************************
* Prediction
**********************************************************************
********************************************
*1) Including all control vars except SCI
********************************************
reg small_business shipvalueperdistance shipvalueperdistance_tempco value_local_sales_pct value_2023_number_csa value_2023_number_farmersmarket value_2023_number_onfarmmarket selfemploymentoutoftotal total_annual_wages median_household_income_2021 pop2020 gdppercapita

predict pSmall_Business_all

*Generate gaps
gen gap_all=pSmall_Business_all-small_business /* if pSmall_Business_all>0 */
gen gap_pct_all=gap_all/small_business
replace gap_pct_all=gap_all/(small_business+1) if small_business==0

********************************************
*2) Including important vars: importance > 0.3
********************************************
tab id if importance1>0.3

reg small_business annual_avg_emplvl annual_avg_estabs_count pop2020 total_annual_wages value_2023_number_farmersmarket value_2023_number_csa

predict pSmall_Business_importance2

*Generate gaps
gen gap_importance2=pSmall_Business_importance2-small_business
gen gap_pct_importance2=gap_importance2/small_business
replace gap_pct_importance2=gap_importance2/(small_business+1) if small_business==0

*Keep key variables
keep fips state county small_business shipvalueperdistance shipvalueperdistance_tempco value_local_sales value_local_sales_pct value_2023_number_csa value_2023_number_farmersmarket value_2023_number_onfarmmarket selfemploymentoutoftotal annual_avg_estabs_count annual_avg_emplvl total_annual_wages real_gdp_2020 gdppercapita pSmall_Business_importance1 importance1 id pSmall_Business_importance2 pSmall_Business_all gap_importance1 gap_pct_importance1 gap_all gap_pct_all gap_importance2 gap_pct_importance2

order fips state county small_business gap* pSmall*

drop gap_pct_importance1 gap_all gap_pct_all gap_importance2 gap_pct_importance2 pSmall_Business_all pSmall_Business_importance2

export delimited using "FinalData.csv", replace
