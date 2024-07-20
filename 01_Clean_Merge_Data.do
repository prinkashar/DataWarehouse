**********************************************************************

*TEAM HEARTLAND
*LOCAL FOOD MANUFACTURING GAP INDEX
*KANSAS STATE UNIVERSITY

*PURPOSE OF FILE - DATA CLEANING  
**********************************************************************

*This Do file cleans and compiles all data for new business development index.

*Last Edited July 18, 2024
**********************************************************************

*Define the main directory for this project
*Desktop:
global data "C:\Users\Jiyeon\OneDrive - Kansas State University\AAEA Data Visualization\Challenge Deliverables"

*Set the current working directory
cd "$data"

clear all
set more off


**********************************************************************
*CBP: # of small business
**********************************************************************
import delimited "Data_Raw\cbp18co.txt", clear

*Keep only NAICS 311
keep if naics=="311///"
rename naics Naics

*Display all variables
ds

*Label key variables
label var est "Total Number of Establishments"
label var n5 "# Establishments: Less than 5 Employee Size Class"
label var n5_9 "# Establishments: 5-9 Employee Size Class"
label var n10_19 "# Establishments: 10-19 Employee Size Class"
label var n20_49 "# Establishments: 20-49 Employee Size Class"
label var n50_99 "# Establishments: 50-99 Employee Size Class"
label var n100_249 "# Establishments: 100-249 Employee Size Class"
label var n250_499 "# Establishments: 250-499 Employee Size Class"
label var n500_999 "# Establishments: 500-999 Employee Size Class"
label var n1000 "# Establishments: 1000 or More Employee Size Class"
label var n1000_1 "# Establishments: 1000-1499 Employee Size Class"
label var n1000_2 "# Establishments: 1500-2499 Employee Size Class"
label var n1000_3 "# Establishments: 2500-4999 Employee Size Class"
label var n1000_4 "# Establishments: 5000 or More Employee Size Class"

*Destring variables for # establishments
destring n*, replace force

*Generate state and county FIPS codes as strings
gen state_fips_str = string(fipstate, "%02.0f")
gen county_fips_str = string(fipscty, "%03.0f")

*Generate the final FIPS code
gen fips = state_fips_str + county_fips_str

*Generate variable for # of small business (employee < 50)
replace n5=0 if n5==.
replace n5_9=0 if n5_9==.
replace n10_19=0 if n10_19==.
replace n20_49=0 if n20_49==.
replace est=0 if est==.

gen Small_Business=n5+n5_9+n10_19+n20_49

*Keep key variables
keep fips Small_Business* est*

*Save as tempfile
tempfile cbp
save `cbp', replace


**********************************************************************
*CFS (2017): Shipment value or distance by CFS regions 
**********************************************************************
*Match CFS regions with US counties
import excel using "Data_Raw\cfs_list_county_2017.xlsx", sheet("CFSAreas") first clear

*Rename
rename *, lower
rename (st cnty cfs17_area cfs17_geoid) (fipstate fipscty orig_ma geoid)

*Keep key variables
keep fipstate fipscty orig_ma geoid

*********************************
*Clean CFS 2017
*********************************
preserve
import delimited "Data_Raw\CFS 2017 PUF CSV.csv", clear

*Keep NAICS 311
keep if naics==311

*Restrict transported goods to agricultural and food products (SCTG 01-09)
destring sctg, gen(sctg_destring) force
keep if sctg_destring<10

*Check average distance between origin and destination
sum shipmt_dist* 

*Keep routed distance between origin and destination less than 100 miles
keep if shipmt_dist_routed<100

*Aggregate shipment values by original CFS regions, indicator of temperature controlled
collapse (sum) shipmt_value shipmt_dist_routed, by(orig_state orig_ma temp_cntl_yn) 

*Reshape long to wide
rename (shipmt_value shipmt_dist_routed) (shipmt_value_ dist_)
reshape wide shipmt_value_ dist_, i(orig_state orig_ma) j(temp_cntl_yn) string

*Rename
rename (orig_state) (fipstate)

*Save as tempfile
tempfile cfs2017
save `cfs2017', replace
restore

*********************************
*Merge
*********************************
merge m:m fipstate orig_ma using `cfs2017'
keep if _merge==3
drop _merge orig_ma

*Generate shipment value per distance miles
gen ShipValuePerDistance=shipmt_value_N/dist_N
gen ShipValuePerDistance_TempCo=shipmt_value_Y/dist_Y

*Labelling variables
label var shipmt_value_N "Value of the shipment ($), not temperature controlled"
label var shipmt_value_Y "Value of the shipment ($), temperature controlled"
label var dist_N "Routed distance between origin and destination (in miles)"
label var dist_Y "Routed distance between origin and destination (in miles)"
label var ShipValuePerDistance "Shipment value per distance ($/mile), No Temperature controlled"
label var ShipValuePerDistance_TempCo "Shipment value per distance ($/mile), Temperature controlled"

*Generate state and county FIPS codes as strings
gen state_fips_str = string(fipstate, "%02.0f")
gen county_fips_str = string(fipscty, "%03.0f")

*Final FIPS code
gen fips = state_fips_str + county_fips_str

*Keep key variables

drop *_str fipstate fipscty
order fips

*Save as tempfile
tempfile cfs
save `cfs', replace

**********************************************************************
*LocalFoodSales
**********************************************************************
import delimited "Data_Raw\df_localfoodsales.csv", clear

*Rename variables
rename (county_name state_name variable_name value) (county state variable value_)


*Destring values
destring value_, replace force

drop category topic_area

*********************************
*Split variables into demographics and food retail
*********************************
**1) Demographics
preserve
keep if variable=="total_acres_operated"|variable=="total_number_operations"|variable=="total_number_producers"

*Reshape long to wide
reshape wide value_, i(fips county state year value_codes) j(variable) string

*save as tempfile
tempfile demographics
save `demographics'
restore

**2) Number of CSA, Farmers market, on-farm market
preserve
keep if variable=="number_csa"|variable=="number_farmersmarket"|variable=="number_onfarmmarket"
rename value_ value_2023_
drop year
reshape wide value_2023_, i(fips county state value_codes) j(variable) string

*save as tempfile
tempfile number
save `number'
restore

**3) Food retail
keep if variable=="d2c_farms"|variable=="d2c_farms_pct"|variable=="d2c_sales"|variable=="d2c_sales_pct"|variable=="intermediated_farms"|variable=="intermediated_farms_pct"|variable=="intermediated_sales"|variable=="intermediated_sales_pct"|variable=="local_sales"|variable=="local_sales_pct"|variable=="valueadded_farms"|variable=="valueadded_farms_pct"|variable=="valueadded_sales"|variable=="valueadded_sales_pct"

*Reshape long to wide
reshape wide value_, i(fips county state year value_codes) j(variable) string

*********************************
*Merge
*********************************
merge m:m fips county state year using `demographics'
drop _merge
merge m:m fips county state using `number'
drop _merge

*Drop observations for states
drop if county=="NA"

*Keep key variables in 2017
keep if year==2017&value_codes=="NA"
drop year value_codes

*Generate string fips code
tostring fips, replace format(%05.0f)

*Save as a tempfile
tempfile localfood
save `localfood', replace


**********************************************************************
*SelfEmployment (Source: 2018 ACS 5-year estimates detailed table)
**********************************************************************
import delimited using "Data_Raw\Self-Employment_ACSDT5Y2018.B19053-Data.csv", varnames(2) clear
drop v9

*********************************
*Clean data to get key variables
*********************************
*Generate fips code
gen fips = substr(geography, 10, 5)

*Destring
destring estimatetotal estimatetotalwithselfemploymenti, replace force

*Generate self-employment/total_employment
gen selfemploymentoutoftotal=estimatetotalwithselfemploymenti/estimatetotal

*Keep key variables
keep fips selfemploymentoutoftotal

*Save as a tempfile
tempfile SelfEmployment
save `SelfEmployment', replace


**********************************************************************
*Wage
**********************************************************************
import delimited using "Data_Raw\2018.annual 311 NAICS 311 Food manufacturing.csv", clear

rename area_fips fips

*Keep observations at county-level
keep if agglvl_title=="County, NAICS 3-digit -- by ownership sector"

*Labelling variables
label var annual_avg_estabs "Avg. of quarterly establishment counts"
label var annual_avg_emplvl "Avg. of monthly employment levels"
label var total_annual_wages "Sum of the four quarterly total wage levels"

*Keep key variables
keep fips annual_avg_estabs annual_avg_emplvl total_annual_wages

tempfile Wage
save `Wage', replace

**********************************************************************
*SCI: Need update
**********************************************************************
import excel using "C:\Users\Jiyeon\OneDrive - Kansas State University\AAEA Data Visualization\Datasets\New Business Development Index\Combined Data July 13.xlsx", first sheet("SCI") clear // RAW FILE NAME FOR WAGE AND KEEP THE FILE IN DATA_RAW

*Generate string fips code
gen fips=string(CountyCode,"%05.0f")

tempfile SCI
save `SCI', replace

**********************************************************************
*Pop
********************************************************************** 
import excel using "C:\Users\Jiyeon\OneDrive - Kansas State University\AAEA Data Visualization\Datasets\New Business Development Index\Combined Data July 13.xlsx", first sheet("Pop") cellrange(A5:I3288) clear // RAW FILE NAME FOR WAGE AND KEEP THE FILE IN DATA_RAW

rename (FIPStxt CENSUS_2020_POP) (fips_code pop2020)

*Drop values for states
gen fips = string(fips_code,"%05.0f")
gen county_fips = substr(fips, 3,3)
drop if county_fips=="000"

keep fips pop2020

tempfile Pop
save `Pop', replace

**********************************************************************
*Income 
**********************************************************************
import excel using "C:\Users\Jiyeon\OneDrive - Kansas State University\AAEA Data Visualization\Datasets\New Business Development Index\Combined Data July 13.xlsx", first sheet("Income") cellrange(A5:CV3203) clear // RAW FILE NAME FOR WAGE AND KEEP THE FILE IN DATA_RAW

rename FIPS_Code fips_code

*Drop values for states
gen fips = string(fips_code,"%05.0f")
gen county_fips_str = substr(fips, 3,3)
drop if county_fips_str=="000"

keep fips Employed_2018	Unemployed_2018	Unemployment_rate_2018 Median_Household_Income_2021	Med_HH_Income_Percent_of_State_T

tempfile Income
save `Income', replace

**********************************************************************
*GDP
**********************************************************************
import excel using "C:\Users\Jiyeon\OneDrive - Kansas State University\AAEA Data Visualization\Datasets\New Business Development Index\Combined Data July 13.xlsx", first sheet("GDP") cellrange(D7:H3224) clear // RAW FILE NAME FOR WAGE AND KEEP THE FILE IN DATA_RAW

rename FIPS fips_code

gen fips = string(fips_code,"%05.0f")

*Drop values for states
drop if fips=="."
destring real*, replace force


tempfile GDP
save `GDP', replace

**********************************************************************
** Compile all data
**********************************************************************
use `cbp', clear

foreach data in cfs localfood SelfEmployment Wage SCI Pop Income GDP {
    merge m:m fips using ``data''
	rename _merge _merge_`data'
}

*Generate real GDP per capita (real GDP/population)
gen GDPpercapita=real_gdp_2020/pop2020

order fips state county

*Save
export delimited using "Combined_full.csv", replace