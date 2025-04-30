/********************************/
/* Virtual Care */
/* 01.clean.data.sas */
/* Maryann Rogers - April 2025 */
/********************************/

/* To run this code, access to the following administrative datasets is required:

   1. BC MSP Dataset – Contains records of all medically necessary services provided 
      by practitioners under the province's fee-for-service system, including associated 
      diagnostic codes (ICD-9).

   2. MSP Consolidation File – Provides demographic information for MSP clients, 
      including age, sex, and geographic indicators of residence.

   3. BC PharmaNet File – Includes data on all prescription drug dispensations from 
      community pharmacies and physicians’ offices in BC, along with claims adjudication 
      details.

   4. Vital Events and Statistics: Births and Deaths – Captures all registered births 
      and deaths in the province.
*/

/* A dataset listing all common antibiotics, their DINs, and classification as 
   broad- or narrow-spectrum is also required. This dataset should be organized by 
   spectrum type and is available upon request from the author. */

/* The Charlson Comorbidity Index must be calculated prior to running the analysis. 
   Code to generate the index is available at: 
   http://mchp-appserv.cpe.umanitoba.ca/viewConcept.php?conceptID=1098 */
   
/* The file allfiles.zip, which contains information on drug active ingredients from 
   Health Canada's Drug Product Database, is also required. It can be downloaded from: 
   https://www.canada.ca/en/health-canada/services/drugs-health-products/drug-products/drug-product-database/what-data-extract-drug-product-database.html */

/*************************************************/

/* Executing this code without optional steps 10 and 17 will produce the dataset 
   required to answer Research Question 1: What is the likelihood of an antibiotic being prescribed
   in virtual versus in-person visits for UTI?

   Perform step 10 (but not 17) to create the dataset for Research Question 2: 
   What is the likelihood of a broad-spectrum antibiotic being prescribed in virtual 
   versus in-person visits for UTI?

   Perform all optional steps (10 and 17) to generate the dataset for Research Question 3: 
   Do virtual visits impact the number of days of Nitrofurantoin prescribed for UTI?

   All three datasets will be required to utilize 02.analytic_model.sas */

/*************************************************/

/* NOTE: The following code was run on data where individuals born or deceased 
   during the analytic year of interest were excluded. To replicate this analysis, 
   ensure that individuals born or deceased during your study period are removed. */
   
/*************************************************/
/*************************************************/

libname TMP1 'R:\working';

/* 1. Create a variable called priot_rx_count which counts the number of prescriptions
an individual had prior to a prescription for a UTI in 2022*/

data tmp1.rpt; /*rpt is the PharmaNet file*/
	set tmp1.rpt;
	by studyid;
	count+1;
	if first.studyid then count=1;
run;

data tmp1.rpt;
set tmp1.rpt;
prior_rx_count=count-1;
drop count;
run;

 /* 2. Extract Pre-existing variables from PharmaNet into a new dataset called UTI_DATASET */


data uti_dataset;
	set TMP1.rpt(keep=studyid Gender CLNT_BRTH Age_Label Patient_HA Patient_HA_Area Practitioner_Type DIN_PIN
	Servdate Quantity_Dispensed Days_Supply_Dispensed prior_rx_count);
run;

proc datasets;
modify uti_dataset;
rename servdate=prescription_date;
run;

data 'R:\working/UTI_DATASET.sas7bdat';
	set work.uti_dataset;
run;

/* 3. Create a dataset from MSP called MSP_UTI which includes visits associated with the following ICD-9 codes:
5990, 599, 788, 7880, 7881, 7884, 7886 */

data MSP_UTI;
	set TMP1.MSP;
	where DIAGCD in ('5990','788','7881','7884','7886')
		or DIAGCD2 in ('5990','788','7881','7884','7886')
		or DIAGCD3 in ('5990','788','7881','7884','7886');
run;

/* Save MSP_UTI as a CSV */

data 'R:\working/MSP_UTI.sas7bdat';
	set work.Msp_uti;
run;

/* 4. Merge HSDA and HA from the MSP Consolidation File (registry) into MSP_UTI*/

proc sql;
	Create table MSP_UTI as
		såelect a.*,
		b.HSDA,
		b.HA
	from MSP_UTI as a
	left join tmp1.registry as b
	on a.studyid=b.studyid
	and year(a.ServDate)=b.YEAR;
quit;

/* 5.  Merge QNBTIPPE and DNBTIPPE from the MSP Consolidation File Consolidation (census) into MSP_UTI*/

proc sql;
	Create table MSP_UTI as
		select a.*,
		b.QNBTIPPE,
		b.DNBTIPPE
	from MSP_UTI as a
	left join tmp1.census as b
	on a.studyid=b.studyid
	and year(a.ServDate)=b.YEAR;
quit;

data 'R:\working/MSP_UTI.sas7bdat';
	set work.Msp_uti;
run;

/* 6. Merge in demographic data from MSP Consolodation file (demo)*/

data demo_new;
	set tmp1.demo;
	DOB=mdy(dobmm, 1, dobyyyy);
	format DOB yymmdd10.;
run;

data MSP_UTI;
merge demo_new (in=a) MSP_UTI(in=b);
by studyid;
if a and b;
run;

data 
	set MSP_UTI;
	drop CLNT_BRTH;
run;

/* 7. Assign VIRTUAL = 1 for specified virtual visit codes */

data MSP_UTI;    
	set MSP_UTI;
	by studyid;    
	if FITM in(
		13036, 13236, 13436, 13536, 13636, 13736, 13836, /* In-office consultation */
		13037, 13237, 13437, 13537, 13637, 13737, 13837, /* In-office visit */
		13038, 13238, 13438, 13538, 13638, 13738, 13838, /* In-office counseling */
		13016, /* Out-of-office consultation */
		13017, /* Out-of-office visit */
		13018, /* Out-of-office counseling */
		14076, 14078, 13706, 13707, /* Telephone management fee */
		14023 /* Telephone follow-up */)
		then VIRTUAL=1;
	else if FITM in (
		12100, 00100, 15300, 16100, 17100, 18100, /* In-office visits */
		12110, 00110, 15310, 16110, 17110, 18110, /* In-office consultation */
		12101, 00100, 15301, 16101, 17101, 18101, /* In-office complete visits */
		12120, 00120, 15320, 16120, 17120, 18120, /* In-office counseling */
		12200, 13200, 15200, 16200, 17200, 18200, /* Out-of-office visit */
		12210, 13210, 15210, 16210, 17210, 18210, /* Out-of-office consultation */
		12201, 13201, 15201, 16201, 17201, 18201, /* Out-of-office complete exams */
		12220, 13220, 15220, 16220, 17220, 18220  /* Out-of-office counseling */)
		then VIRTUAL=0;
	if VIRTUAL=. then delete;
	run;

/* 8. Merge MSP_UTI into UTI_DATASET */

/* This code joins a visit from MSP_UTI with a prescription from PharmaNet if the prescription was filled within
two weeks of a physician visit for UTI */

/*Full join MSP_UTI with Pharmanet_UTI*/

proc sql;
	create table uti_dataset as
	select coalesce(A.studyid,B.studyid) as studyid, A.*, B.* from
	MSP_UTI A FULL JOIN uti_dataset B 
	on A.studyid=B.studyid and B.Prescription_Date>=A.visit_date and B.Prescription_Date<=(A.visit_date+14)
	order by studyid,visit_date;
quit;

data WANT;
	set WANT;
	if Prescription_Date^=. and visit_date=. then delete;
run;

data 'R:\working/uti_dataset.sas7bdat';
	set work.uti_dataset;
run;


/*9. Create two variables, BROAD and ANTBIOTIC. Broad is a binary variable  which =1 if a broad-spectrum antibiotic
was prescribed and =0 if a narrow-spectrum antibiotic was prescribed. ANTIBIOTIC is a binary variable which =1 if an 
antibiotic was prescribed and =0 if not */

/* Import BROAD_DIN */

proc import datafile='R:\working/Broad_Din.csv'
	out=broad_din
	dbms=csv
	replace;
	getnames=yes;
run;

/* Import Narrow_DIN */

proc import datafile='R:\working/Narrow_Din.csv'
	out=narrow_din
	dbms=csv
	replace;
	getnames=yes;
run;

proc sql;
	create table BROAD_DIN as
	select distinct DIN, 1 as BROAD
	from broad_DIN;

	create table NARROW_DIN as
	select distinct DIN, 0 as BROAD
	from narrow_DIN;
quit;

data din_list;
	set broad_din narrow_din;
run;

proc sql;
	create table uuti_dataset as
	select a.*,
	case
	when b.DIN is not null and BROAD=1 then 1
	when b.DIN is not null and BROAD=0 then 0
	when a.DIN_PIN is not null and b.DIN is null then 3
	else .
	end as BROAD,
	case when b.DIN is not null then 1 else 0 end as ANTIBIOTIC
	from uti_dataset as a
	left join din_list as b
	on a.DIN_PIN=b.DIN
	order by a.studyid;
quit;

/* 10. OPTIONAL: Remove rows where an antibiotic was not prescribed (BROAD=3) */
/* This step should not be performed if you seek to determine the liklihood of
an antibiotic being prescribed */

data uuti_dataset;
	set uuti_dataset;
	if BROAD ne 3;
run;

/* 11. Create a flag called PRIOR_RX_FLAG which identifies individuals who had a prescription for a UTI in 2022
who also had a prescription for a UTI in the year prior */

proc sort data=uti_dataset;by studyid Prescription_Date;run;

data uti_dataset;
set uti_dataset;
format Pre1 yymmddd10.;
by studyid;Pre1=lag(Prescription_Date);
if first.studyid then Pre1=.;
run;

data uti_dataset;
set uti_dataset;
if Year(Prescription_Date)=2022 and Pre1>=(Prescription_Date-365) and Pre1<=Prescription_Date
then PRIOR_RX_FLAG=1; else PRIOR_RX_FLAG=0;
run;

/* 12. Create a flag called PRIOR_VISIT_FLAG which identifies individuals who had a visit for a UTI in 2022
who also had a visit for a UTI in the year prior */

data uti_dataset;
set uti_dataset;
format Pre yymmddd10.;
by studyid;Pre=lag(visit_date);
if first.studyid then Pre=.;
run;

data uti_dataset;
set uti_dataset;
if Year(visit_date)=2022 and Pre>=(visit_date-365) and Pre<=visit_date
then PRIOR_VISIT_FLAG=1; else PRIOR_VISIT_FLAG=0;
run;

data uti_dataset;
	set uti_dataset;
	drop pre pre1;
run;

data 'R:\working/Uuti_dataset.sas7bdat';
	set work.uti_dataset;
run;

/* 13. Create a variable called PROP_VIRTUAL, which represents the proportion of visits a physician performs virtually */

data visit_counts;
	set tmp1.msp;

	if FITM in(
		13036, 13236, 13436, 13536, 13636, 13736, 13836, /* In-office consultation */
		13037, 13237, 13437, 13537, 13637, 13737, 13837, /* In-office visit */
		13038, 13238, 13438, 13538, 13638, 13738, 13838, /* In-office counseling */
		13016, /* Out-of-office consultation */
		13017, /* Out-of-office visit */
		13018, /* Out-of-office counseling */
		14076, 14078, 13706, 13707, /* Telephone management fee */
		14023 /* Telephone follow-up */)
		then VIRTUAL=1;
	else if FITM in (
		12100, 00100, 15300, 16100, 17100, 18100, /* In-office visits */
		12110, 00110, 15310, 16110, 17110, 18110, /* In-office consultation */
		12101, 00100, 15301, 16101, 17101, 18101, /* In-office complete visits */
		12120, 00120, 15320, 16120, 17120, 18120, /* In-office counseling */
		12200, 13200, 15200, 16200, 17200, 18200, /* Out-of-office visit */
		12210, 13210, 15210, 16210, 17210, 18210, /* Out-of-office consultation */
		12201, 13201, 15201, 16201, 17201, 18201, /* Out-of-office complete exams */
		12220, 13220, 15220, 16220, 17220, 18220  /* Out-of-office counseling */)
		then VIRTUAL=0;
	if VIRTUAL=. then delete;
	run;

	proc sql;
		create table visit_summary as
		select 
		PRACNUM,
		count(*) as total_visits,
		sum(VIRTUAL=1) as virtual_visits
		from visit_counts
		group by PRACNUM;
	quit;

data prop_virtual_output;
		set visit_summary;
		if PRACNUM ne . then do;
			if total_visits >0 then
			PROP_VIRTUAL = virtual_visits/total_visits;
			else PROP_VIRTUAL = .;
		end;
	else do;
		PROP_VIRTUAL=.;
	end;
run;

proc sql;
	create table uti_dataset as 
	select a.*,
	b.PROP_VIRTUAL
	from uti_dataset as a 
	left join prop_virtual_output as b
	on a.PRACNUM = b.PRACNUM;
quit;

proc sort data=uti_dataset;by studyid Prescription_Date;run;

data 'R:\working/UTI_DATASET.sas7bdat';
	set uti_dataset;
run;

/* 14. Merge in previously calculated Charslon Comorbidity Index data */

proc sql;
	create table uti_dataset as
	select a.*,
	b.totalcc,
	b.wgtcc,
	wgtccup
from uti_dataset as a
left join Tmp1.CC_tot_index as b
on a.studyid=b.studyid;
quit;

data 'R:\working/uti_dataset.sas7bdat';
	set uti_dataset;
run;

/* 15. Create a binary variable called MRP, which = 1 if the UTI-related physician visit 
      was conducted by the patient’s most responsible physician. This designation is assigned 
      based on the physician with whom the patient had the most visits during the study period. */
      
proc SQL;
	create table visit_counts as    
	select studyid, PRACNUM, count(*) as visit_count
	from Tmp41.msp
	group by studyid, PRACNUM;   
quit;

/* Create a dataset with the maximum visit count for each studyid and PRACNUM */
proc sql;
	create table max_visits as
	select studyid, max(visit_count) as max_visit_count
	from visit_counts
	group by studyid;
quit;

/* Join visit counts with max visit counts to find MRP */

proc sql;
	create table MRP as
	select a.studyid, a.PRACNUM, a.visit_count, 1 as MRP
	from visit_counts as a
	inner join max_visits as b
	on a.studyid=b.studyid and a.visit_count=b.max_visit_count;
quit;

/* Join MRP with the full dataset */

proc sql; 
	create table Tuti_dataset as
	select a.*,
		coalesce (b.MRP, 0) as MRP
	from uti_dataset as a
	left join MRP as b
on a.studyid=b.studyid and a.PRACNUM=b.PRACNUM;
quit;

/* 16. import and merge active ingredient data from DPD with uti_dataset */

proc import datafile='R:\working\DPD.csv'
out=dpd
dbms=csv;
run;

proc sql;
	create table uti_dataset as
	select a.*, b.INGREDIENT
	from uti_dataset as a
		left join dpd as b
		on a.DIN_PIN=b.Din_pin;
quit;

/* 17. OPTIONAL - If you would like to look at prescribing patterns for one
common active ingredient */
/* Restrict the active ingredient to nitrofurantoin */

data uti_dataset;
	set uti_dataset;
	where INGREDIENT = 'NITROFURANTOIN';
run;

data 'R:\working/uti_dataset.sas7bdat';
	set uti_dataset;
run;

proc export data=uti_dataset
outfile='R:\working/uti_dataset.csv'
dbms=csv;
run;


/* 18. restrict uti_dataset to 2022 */

data uti_dataset;
	set uti_dataset;
	where year(visit_date)=2022;
run;

/* 19. Restrict uti_dataset to only GP visits */

data uti_dataset;
	set uti_dataset;
	where clmspec = 0;
run;

/* 20. Create dummies for HSDA and DNBTIPPE for use in proc psmatch*/

data uti_dataset;
	set uti_dataset;
	if HSDA= 11 then hsda1=1;
	else hsda1=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 12 then hsda2=1;
	else hsda2=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 13 then hsda3=1;
	else hsda3=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 14 then hsda4=1;
	else hsda4=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 21 then hsda5=1;
	else hsda5=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 22 then hsda6=1;
	else hsda6=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 23 then hsda7=1;
	else hsda7=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 31 then hsda8=1;
	else hsda8=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 32 then hsda9=1;
	else hsda9=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 33 then hsda10=1;
	else hsda10=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 41 then hsda11=1;
	else hsda11=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 42 then hsda12=1;
	else hsda12=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 43 then hsda13=1;
	else hsda13=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 51 then hsda14=1;
	else hsda14=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 52 then hsda15=1;
	else hsda15=0;
run;

data uti_dataset;
	set uti_dataset;
	if HSDA= 53 then hsda16=1;
	else hsda16=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 1 then DNBTIPPE1=1;
	else DNBTIPPE1=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 2 then DNBTIPPE2=1;
	else DNBTIPPE2=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 3 then DNBTIPPE3=1;
	else DNBTIPPE3=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 4 then DNBTIPPE4=1;
	else DNBTIPPE4=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 5 then DNBTIPPE5=1;
	else DNBTIPPE5=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 6 then DNBTIPPE6=1;
	else DNBTIPPE6=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 7 then DNBTIPPE7=1;
	else DNBTIPPE7=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 8 then DNBTIPPE8=1;
	else DNBTIPPE8=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 9 then DNBTIPPE9=1;
	else DNBTIPPE9=0;
run;

data uti_dataset;
	set uti_dataset;
	if DNBTIPPE= 10 then DNBTIPPE10=1;
	else DNBTIPPE10=0;
run;

data uti_dataset;
	set tuti_dataset;
	if DNBTIPPE= 999 then DNBTIPPE11=1;
	else DNBTIPPE11=0;
run;

/* Running the code without optional steps 10 and 17 will produce the dataset 
   required for Research Question 1: What is the likelihood of an antibiotic being prescribed?
   This dataset should be named: uti_dataset_overall.

   Example:
   data 'R:\working/uti_dataset.sas7bdat';
	set uti_dataset;
   run;

   proc export data=uti_dataset
	outfile='R:\working/uti_dataset.csv'
	dbms=csv;
   run;

/* Repeat all steps including optional step 10 (but excluding step 17) to create the dataset 
   for Research Question 2: What is the likelihood of a broad-spectrum antibiotic being 
   prescribed in virtual vs. in-person visits?
   This dataset should be named: uti_dataset_anti.

   Example:
   data 'R:\working/uti_dataset_anti.sas7bdat';
	set uti_dataset;
   run;

   proc export data=uti_dataset
	outfile='R:\working/uti_dataset_anti.csv'
	dbms=csv;
   run;

/* Repeat all steps including optional steps 10 and 17 to create the dataset 
   for Research Question 3: Do virtual visits impact the number of days of 
   Nitrofurantoin prescribed for UTI?
   This dataset should be named: uti_dataset_nitro.

   Example:
   data 'R:\working/uti_dataset_nitro.sas7bdat';
	set uti_dataset;
   run;

   proc export data=uti_dataset
	outfile='R:\working/uti_dataset_nitro.csv'
	dbms=csv;
   run;

   */
