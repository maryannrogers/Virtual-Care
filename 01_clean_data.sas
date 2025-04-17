/********************************/
/* Virtual Care */
/* 01.clean.data.sas */
/* Maryann Rogers - April 2025 */
/********************************/

/* To run this code, access to the following administrative datasets is required:

   1. BC MSP Dataset – Contains records of all medically necessary services provided 
      by practitioners through the province's fee-for-service system, including 
      associated diagnostic codes (ICD-9).

   2. MSP Consolidation File – Includes demographic information for MSP clients, 
      such as age, sex, and geographic indicators for place of residence.

   3. BC PharmaNet File – Contains data on all prescription drug dispensations from 
      community pharmacies and physicians' offices in BC, along with claims adjudication 
      details.

   4. Vital Events and Statistics: Births and Deaths – Includes all births and deaths 
      registered in the province.
*/

/* NOTE: The following code was run on data where individuals born or deceased 
   during the analytic year of interest were excluded. If you are replicating 
   this analysis, you will need to remove individuals who were born or died 
   during your study period. */


/* ICD Code Specific Data Creation */

/* 1. Create a dataset from MSP called MSP_UTI which includes visits associated with the following ICD-9 codes:
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

/* 2. Merge HSDA and HA from Registry into MSP_UTI*/

proc sql;
	Create table MSP_UTI as
		såelect a.*,
		b.HSDA,
		b.HA
	from MSP_UTI as a
	left join TMP2.registry as b
	on a.studyid=b.studyid
	and year(a.ServDate)=b.YEAR;
quit;

/*2.  Merge QNBTIPPE and DNBTIPPE from Census into MSP_UTI*/

proc sql;
	Create table MSP_UTI as
		select a.*,
		b.QNBTIPPE,
		b.DNBTIPPE
	from MSP_UTI as a
	left join TMP2.census as b
	on a.studyid=b.studyid
	and year(a.ServDate)=b.YEAR;
quit;

data 'R:\working/MSP_UTI.sas7bdat';
	set work.Msp_uti;
run;

 /* 3. Extract Pre-existing variables from PharmaNet into a new dataset called UTI_DATASET */


data UTI_DATASET_march20_anti;
	set TMP1.rpt(keep=studyid Gender CLNT_BRTH Age_Label Patient_HA Patient_HA_Area Practitioner_Type DIN_PIN
	Servdate Quantity_Dispensed Days_Supply_Dispensed Drug_Cost_Accepted Drug_Cost_Claimed Drug_Cost_Paid
	Professional_Fee_Accepted Professional_Fee_Paid TOT_Patient_PAID TOT_PCARE_PAID SPEC_AUTHY_FLG 
	Accumulated_Expenditure Claim_Status prior_rx_count);
run;

proc datasets;
modify uti_dataset_march20_anti;
rename servdate=prescription_date;
run;

data 'R:\working/UTI_DATASET.sas7bdat';
	set work.uti_dataset;
run;

/* Create a variable called RX_YEAR which counts the number of RX an individual had in the year prior to a prescription for a UTI in 2022 */

data tmp3.rpt;
	set tmp3.rpt;
	by studyid;
	count+1;
	if first.studyid then count=1;
run;

data tmp1.rpt;
set tmp1.rpt;
prior_rx_count=count-1;
drop count;
run;

proc sql;
	create table merge_rx as
		select A.*,
		B.prior_rx_count
	from WANT as A
		left join tmp1.rpt as B
	on A.studyid=B.studyid
		and
		abs (A.visit_date-B.servdate)=(select min(abs(A.visit_date-servdate))
			from WANT as B
			where A.studyid=B.studyid);
quit;


proc sql;
create table RX_YEAR2 as
select distinct * from want A left join tmp2.rpt B
on A.studyid=B.studyid and A.Prescription_Date=B.Servdate
order by studyid,visit_date
;quit;

/* 4. Assign VIRTUAL = 1 for specified virtual visit codes */

data Tmp3.MSP_UTI;    
	set Tmp3.MSP_UTI;
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

/* 5. Merge MSP_UTI into UTI_DATASET */

/*Full join MSP_UTI with Pharmanet_UTI*/

proc sql;
	create table WANT as
	select coalesce(A.studyid,B.studyid) as studyid, A.*, B.* from
	TMP1.MSP_UTI A FULL JOIN uti_dataset_march20_anti B 
	on A.studyid=B.studyid and B.Prescription_Date>=A.visit_date and B.Prescription_Date<=(A.visit_date+14)
	order by studyid,visit_date;
quit;

data WANT;
	set WANT;
	if Prescription_Date^=. and visit_date=. then delete;
run;

data 'R:\working/UTI_DATASETfeb27.sas7bdat';
	set work.WANT;
run;


/*6. Create the BROAD Variable and a variable called 
ANTIBIOTIC which checks to see if an antibiotic was prescribed */

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
	create table uti_dataset_march20 as
	select a.*,
	case
	when b.DIN is not null and BROAD=1 then 1
	when b.DIN is not null and BROAD=0 then 0
	when a.DIN_PIN is not null and b.DIN is null then 3
	else .
	end as BROAD,
	case when b.DIN is not null then 1 else 0 end as ANTIBIOTIC
	from Want as a
	left join din_list as b
	on a.DIN_PIN=b.DIN
	order by a.studyid;
quit;

/* Remove rows where BROAD=3 */

data uti_dataset_march13;
	set uti_dataset_march13;
	if BROAD ne 3;
run;

/* 7. Create a flag called PRIOR_RX_FLAG which identifies individuals who had a prescription for a UTI in 2022
who also had a prescription for a UTI in the year prior */

proc sort data=uti_dataset_march20;by studyid Prescription_Date;run;

data WANT;
set uti_dataset_march20;
format Pre1 yymmddd10.;
by studyid;Pre1=lag(Prescription_Date);
if first.studyid then Pre1=.;
run;

data WANT;
set WANT;
if Year(Prescription_Date)=2022 and Pre1>=(Prescription_Date-365) and Pre1<=Prescription_Date
then PRIOR_RX_FLAG=1; else PRIOR_RX_FLAG=0;
run;

/* 8. Create a flag called PRIOR_VISIT_FLAG which identifies individuals who had a visit for a UTI in 2022
who also had a visit for a UTI in the year prior */

data want;
set want;
format Pre yymmddd10.;
by studyid;Pre=lag(visit_date);
if first.studyid then Pre=.;
run;

data want;
set want;
if Year(visit_date)=2022 and Pre>=(visit_date-365) and Pre<=visit_date
then PRIOR_VISIT_FLAG=1; else PRIOR_VISIT_FLAG=0;
run;

data want;
	set want;
	drop pre pre1;
run;

data 'R:\working/UTI_DATASETfeb27.sas7bdat';
	set work.WANT;
run;

/* 9. Create a variable called PROP_VIRTUAL with the proportion of visits a physician performs virtually */

data visit_counts;
	set Tmp4.msp;

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
	create table want as 
	select a.*,
	b.PROP_VIRTUAL
	from want as a 
	left join prop_virtual_output as b
	on a.PRACNUM = b.PRACNUM;
quit;

proc sort data=WANT;by studyid Prescription_Date;run;

data 'R:\working/UTI_DATASET.sas7bdat';
	set WANT;
run;

/* 10. Merge in previously calculated Charslon Comorbidity Index data */

proc sql;
	create table WANT as
	select a.*,
	b.totalcc,
	b.wgtcc,
	wgtccup
from WANT as a
left join Tmp2.CC_tot_index as b
on a.studyid=b.studyid;
quit;

data 'R:\working/UTI_DATASETfeb27.sas7bdat';
	set WANTcc;
run;

/* Create a new dataset called most_resp_MD with visit counts for each studyid and PRACNUM */
proc sql;    
	create table visit_counts as    
	select studyid, PRACNUM, count(*) as visit_count
	from Tmp4.msp
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
	create table Tmp1.uti_dataset_march20 as
	select a.*,
		coalesce (b.MRP, 0) as MRP
	from want as a
	left join MRP as b
on a.studyid=b.studyid and a.PRACNUM=b.PRACNUM;
quit;


/* restrict the dataset to 2022 */

data tmp1.uti_dataset_march20;
	set want;
	where year(visit_date)=2022;
run;

/* Resrict the dataset to only GP visits */

data tmp1.uti_dataset_march20;
	set tmp1.uti_dataset_march20;
	where clmspec = 0;
run;

data tmp1.uti_dataset_march20_ant;
	set tmp1.uti_dataset_march20_ant;
	if ANTIBIOTIC = 1;
run;
/* Merge in demographic data */

proc contents data = tmp1.uti_dataset_mar13 out=var_list(keep=name) noprint;
run;

data demo_new;
	set tmp3.demo;
	DOB=mdy(dobmm, 1, dobyyyy);
	format DOB yymmdd10.;
run;

data tmp1.uti_dataset_march20;
merge demo_new (in=a) tmp1.uti_dataset_march20(in=b);
by studyid;
if a and b;
run;

data 
	set tmp1.uti_dataset_march20;
	drop CLNT_BRTH;
run;

data 'R:\working/UTI_DATASET_march20.sas7bdat';
	set tmp1.uti_dataset_march20;
run;
proc freq data=tmp1.uti_dataset_march20_mrp;
	tables DNBTIPPE;
run;

/* Create Dummies */

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_march20_anti;
	if HSDA= 11 then hsda1=1;
	else hsda1=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 12 then hsda2=1;
	else hsda2=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 13 then hsda3=1;
	else hsda3=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 14 then hsda4=1;
	else hsda4=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 21 then hsda5=1;
	else hsda5=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 22 then hsda6=1;
	else hsda6=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 23 then hsda7=1;
	else hsda7=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 31 then hsda8=1;
	else hsda8=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 32 then hsda9=1;
	else hsda9=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 33 then hsda10=1;
	else hsda10=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 41 then hsda11=1;
	else hsda11=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 42 then hsda12=1;
	else hsda12=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 43 then hsda13=1;
	else hsda13=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 51 then hsda14=1;
	else hsda14=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 52 then hsda15=1;
	else hsda15=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 53 then hsda16=1;
	else hsda16=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if HSDA= 99 then hsda17=1;
	else hsda17=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 1 then DNBTIPPE1=1;
	else DNBTIPPE1=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 2 then DNBTIPPE2=1;
	else DNBTIPPE2=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 3 then DNBTIPPE3=1;
	else DNBTIPPE3=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 4 then DNBTIPPE4=1;
	else DNBTIPPE4=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 5 then DNBTIPPE5=1;
	else DNBTIPPE5=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 6 then DNBTIPPE6=1;
	else DNBTIPPE6=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 7 then DNBTIPPE7=1;
	else DNBTIPPE7=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 8 then DNBTIPPE8=1;
	else DNBTIPPE8=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 9 then DNBTIPPE9=1;
	else DNBTIPPE9=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 10 then DNBTIPPE10=1;
	else DNBTIPPE10=0;
run;

data tmp1.uti_dataset_dummies;
	set tmp1.uti_dataset_dummies;
	if DNBTIPPE= 999 then DNBTIPPE11=1;
	else DNBTIPPE11=0;
run;

data 'R:\working/UTI_DATASET_march20_ant.sas7bdat';
	set tmp1.uti_dataset_dummies;
run;

proc export data=tmp1.uti_dataset_march25
outfile='R:\working/UTI_DATASET_march25.csv'
dbms=csv;
run;

/* import and merge DPD date */

proc import datafile='R:\working\DPD.csv'
out=dpd
dbms=csv;
run;

proc sql;
	create table uti_dataset_april8 as
	select a.*, b.INGREDIENT
	from tmp1.uti_dataset_march25 as a
		left join dpd as b
		on a.DIN_PIN=b.Din_pin;
quit;

/* restrict to nitrofurantion */

data uti_dataset_april8_nitro;
	set uti_dataset_april8;
	where INGREDIENT = 'NITROFURANTOIN';
run;

data 'R:\working/UTI_DATASET_april8_nitro.sas7bdat';
	set uti_dataset_april8_nitro;
run;

proc export data=tmp1.uti_dataset_anti
outfile='R:\working/uti_dataset_anti.csv'
dbms=csv;
run;
