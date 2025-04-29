/********************************/
/* Virtual Care */
/* 02.analytic.models.sas */
/* Maryann Rogers - April 2025 */
/********************************/

/********************************/
/*Propensity Score Matching */
/********************************/

libname TMP1 'R:\working';

/* Import Analytic Datasets */
/* 1. UTI_dataset_overall.csv which contains information on all visits for UTI and their associated prescriptions in BC in 2022 */

proc import datafile='R:\working/uti_dataset_overall.csv'
	out=uti_dataset_overall
	dbms=csv
	replace;
	getnames=yes;
run;

/* 2.  UTI_dataset_anti.csv which contains information on all visits for UTI and their associated antibiotic prescriptions in BC in 2022 */
proc import datafile='R:\working/uti_dataset_anti.csv'
	out=uti_dataset_anti
	dbms=csv
	replace;
	getnames=yes;
run;

/* 3.  UTI_dataset_nitro.csv which contains information on all visits for UTI and their associated Nitrofurantoin prescriptions in BC in 2022 */
proc import datafile='R:\working/uti_dataset_nitro.csv'
	out=uti_dataset_nitro
	dbms=csv
	replace;
	getnames=yes;
run;

/* 4. edit ods graphics to fit propensity score matching love plots */

Ods graphics on / height=8in width=6in;

/* 5. Create macros for the dummy variables for HSDA and DNBTIPPE */

%let hsda_vars = hsda1 hsda2 hsda3 hsda4 hsda5 hsda6 hsda7 hsda8 hsda9 hsda10 hsda11 hsda12 hsda13 hsda14 hsda15 hsda16;

%let DNBTIPPE_vars = DNBTIPPE1 DNBTIPPE2 DNBTIPPE3 DNBTIPPE4 DNBTIPPE5 DNBTIPPE6 DNBTIPPE7 DNBTIPPE8 DNBTIPPE9 DNBTIPPE10 DNBTIPPE11;

/*************************************************************************************************/
/* For research question 1 with the larger dataset with all prescriptions associated with UTI */
/*************************************************************************************************/

/* 6. Calculate the propensity score for the larger dataset with all prescriptions associated with UTI */
proc logistic data=tmp1.uti_dataset_overall;
  class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL &hsda_vars &DNBTIPPE_vars;
  model VIRTUAL(REF='0') = Sex prior_rx_flag prior_visit_flag MRP DOBYYYY wgtccup prior_rx_count &hsda_vars &DNBTIPPE_vars prop_virtual
  /link=glogit rsquare;
  output out = tmp1.uti_dataset_overall pred = ps;
run;


/* 7. Perform propensity score matching with greedy k=1 matching and a caliper of 0.25 */

proc psmatch data=tmp1.uti_dataset_overall;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL &hsda_vars &DNBTIPPE_vars;
	psmodel VIRTUAL (Treated='1') = Sex prior_rx_flag prior_visit_flag prior_rx_count MRP DOBYYYY wgtccup &hsda_vars &DNBTIPPE_vars prop_virtual;
	match method=greedy(k=1 order=random(seed=12345)) distance=lps caliper=0.25;
	assess lps allcov/ plots=(STDDIFF);
	output out(obs=match)=uti_matched lps=LPS matchid=MID;
run;

/* Save the matched dataset */

data 'R:\working/uti_matched.sas7bdat';
	set work.uti_matched;
run;

proc export data=Tmp1.uti_matched
  outfile='uti_matched.csv'
  dbms=csv;
run;

/* 8. Visualize propensity score distribution on unmatched and matched data */

title "Propensity Score Distribution of Unmatched Overall Data";
proc sgplot data=tmp1.uti_dataset_overall;
	histogram ps / group=VIRTUAL transparency=0.5;
	density ps /group=VIRTUAL;
	xaxis label="Propensity score";
	yaxis label="Frequency";
run;
title;

title 'Propensity Score Distribution of Matched Overall Data';
proc sgplot data=tmp1.uti_matched;
	histogram _PS_ / group=VIRTUAL transparency=0.5;
	density _PS_ /group=VIRTUAL;
	xaxis label="Propensity score";
	yaxis label="Frequency";
run;
title;


/* 9. Run logistic regression on research question 1 - likelihood of antibiotic prescribing on both the matched and unmatched datasets*/

/* Unmatched data */

proc logistic data=tmp1.uti_dataset_overall;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (REF='0') &hsda_vars &DNBTIPPE_vars;
	model ANTIBIOTIC (event='1')=VIRTUAL Sex prior_visit_flag MRP DOBYYYY prior_rx_count wgtccup &hsda_vars &DNBTIPPE_vars prop_virtual;
	oddsratio VIRTUAL;
run;

/* Matched data */

proc logistic data=tmp1.uti_matched;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL(REF='0') &hsda_vars &DNBTIPPE_vars;
	model ANTIBIOTIC (event='1')=VIRTUAL Sex prior_visit_flag MRP DOBYYYY prior_rx_count wgtccup &hsda_vars &DNBTIPPE_vars prop_virtual;
	oddsratio VIRTUAL;
run;

/* 10. Run sensitivity analysis with Inverse Propensity Treatment Weighting (IPTW) on research question 1 */

/* Create the Propensity Scores */

proc logistic data=tmp1.uti_dataset_overall;
  class Sex (missing) prior_rx_flag (missing) prior_visit_flag(missing) MRP(missing) VIRTUAL(missing) &hsda_vars(missing) &DNBTIPPE_vars(missing);
  model VIRTUAL(REF='0') = Sex prior_rx_flag prior_visit_flag MRP DOBYYYY wgtccup prior_rx_count &hsda_vars &DNBTIPPE_vars prop_virtual
  /link=glogit rsquare;
  output out = ps_overall pred = ps;
run;

/* Calculate Inverse Probability Weight */
data ps_weight_overall;
  set ps_overall;
  ps_weight_overall=1/ps;
run;

/* Adjust the weight for the cohort */
proc sql;
  create table ps_weight_adj_overall as
  select *, (count(*)/358389)*ps_weight_overall as ps_weight_adj_overall /* Replace the value here with the number of observations in the ps_weight_overall dataset */
  from ps_weight_overall group by VIRTUAL;
quit;

/* 11. Run the logistic regression model with the weighted data */
proc logistic data=ps_weight_adj_overall;
  class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL(REF='0') &hsda_vars &DNBTIPPE_vars;
  model ANTIBIOTIC (event='1')=VIRTUAL Sex prior_rx_flag prior_visit_flag prior_rx_count MRP DOBYYYY wgtccup &hsda_vars &DNBTIPPE_vars prop_virtual
  / rsquare clodds=wald lackfit;
  weight ps_weight_adj_overall / normalize;
run;

/* 12. Visualize the distribution of the adjusted inverse propensity score */
title 'Propensity Score Distribution of Inverse PS Weighted Overall Data';
  proc sgplot data=ps_weight_adj_oversll;
	histogram ps_weight_adj_overall / group=VIRTUAL transparency=0.5;
	density ps_weight_adj_overall /group=VIRTUAL;
	xaxis label="propensity score";
	yaxis label="frequency";
run;
title;

/*************************************************************************************************/
/* For research question 2 with the dataset restricted to antibiotic prescriptions */
/*************************************************************************************************/

/* 13. Calculate the propensity with the larger dataset with all antibiotic prescriptions associated with UTI */
proc logistic data=tmp1.uti_dataset_anti;
	class Sex (missing) prior_rx_flag (missing) prior_visit_flag(missing) MRP(missing) VIRTUAL(missing) &hsda_vars(missing) &DNBTIPPE_vars(missing);
	model VIRTUAL(REF='0') = Sex prior_rx_flag prior_visit_flag MRP DOBYYYY wgtccup prior_rx_count &hsda_vars &DNBTIPPE_vars prop_virtual
	/link=glogit rsquare;
	output out = tmp1.uti_dataset_anti pred = ps;
run;

/* 14. Perform propensity score matching with greedy k=1 matching and a caliper of 0.25 */

proc psmatch data=tmp1.uti_dataset_anti;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL &hsda_vars &DNBTIPPE_vars;
	psmodel VIRTUAL (Treated='1') = Sex prior_rx_flag prior_visit_flag MRP DOBYYYY prior_rx_count wgtccup &hsda_vars &DNBTIPPE_vars prop_virtual;
	match method=greedy(k=1 order=random(seed=12345)) distance=lps caliper=0.25;
	assess lps allcov/ plots=(STDDIFF);
	output out(obs=match)=uti_matched_anti lps=LPS matchid=MID;
run;

/* Save the matched data */

data 'R:\working/uti_matched_anti.sas7bdat';
	set uti_matched_anti;
run;

proc export data=uti_matched_anti
  outfile='uti_matched_anti.csv'
  dbms=csv;
run;

/* 15. Visualize propensity score distribution on unmatched and matched data */

title "Propensity Score Distribution of Unmatched Data for Individuals Prescribed an Antibiotic";
  proc sgplot data=tmp1.uti_dataset_anti;
	histogram ps / group=VIRTUAL transparency=0.5;
	density ps /group=VIRTUAL;
	xaxis label="Propensity score";
	yaxis label="Frequency";
run;
title;

title 'Propensity Score Distribution of Matched Data Individuals Prescribed an Antibiotic';
  proc sgplot data=tmp1.uti_matched_anti;
	histogram _PS_ / group=VIRTUAL transparency=0.5;
	density _PS_ /group=VIRTUAL;
	xaxis label="Propensity score";
	yaxis label="Frequency";
run;
title;

/* 16. Run logistic regression on research question 2 - type of antibiotic prescribed */

/* Unmatched Data */
proc logistic data=tmp1.uti_dataset_anti;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (ref='0') BROAD &hsda_vars &DNBTIPPE_vars;
	model BROAD (event='1')=VIRTUAL Sex prior_rx_flag prior_visit_flag MRP prior_rx_count DOBYYYY &DNBTIPPE_vars prop_virtual;
	oddsratio VIRTUAL;
run;

/* Matched Data */
proc logistic data=tmp1.uti_matched_anti;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (ref='0') BROAD &hsda_vars &DNBTIPPE_vars;
	model BROAD (event='1')=VIRTUAL Sex prior_rx_flag prior_visit_flag MRP prior_rx_count DOBYYYY &DNBTIPPE_vars prop_virtual;
	oddsratio VIRTUAL;
run;

/* 17. Sensitivity analysis with IPSW */

/* Create the Propensity Scores */

proc logistic data=tmp1.uti_dataset_anti;
  class Sex prior_rx_flag prior_visit_flag MRP BROAD VIRTUAL (ref='0') &hsda_vars &DNBTIPPE_vars;
  model VIRTUAL = Sex prior_rx_flag prior_visit_flag MRP DOBYYYY wgtccup prior_rx_count &hsda_vars &DNBTIPPE_vars prop_virtual
  /link=glogit rsquare;
  output out = ps_anti pred = ps;
run;

/* Calculate Inverse Probability Weight */
data ps_weight_anti;
  set ps_anti;
  ps_weight_anti=1/ps_anti;
run;

/* Adjust the weight for the cohort */
proc sql;
  create table ps_weight_adj_anti as
  select *, (count(*)/76906)*ps_weight_anti as ps_weight_adj_anti /* Replace the value here with the number of observations in the ps_weight_overall dataset */
  from ps_weight_anti group by VIRTUAL;
quit;

/* 18. Run the model */
proc logistic data=ps_weight_adj_anti;
  class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (ref='0') BROAD &hsda_vars &DNBTIPPE_vars;
  model BROAD (event='1')=VIRTUAL Sex prior_rx_flag prior_visit_flag MRP prior_rx_count DOBYYYY wgtccup &DNBTIPPE_vars prop_virtual
  / rsquare clodds=wald lackfit;
  weight ps_weight_adj_anti / normalize;
run;

/* 19. Visualize the distribution of the adjusted inverse propensity score */
title 'Propensity Score Distribution of Inverse PS Weighted Data for Individuals Prescribed an Antibiotic';
  proc sgplot data=ps_weight_adj_anti;
	histogram ps_weight_adj_anti / group=VIRTUAL transparency=0.5;
	density ps_weight_adj_anti /group=VIRTUAL;
	xaxis label="propensity score";
	yaxis label="frequency";
run;
title;

/*************************************************************************************************/
/* For research question 3 with the dataset restricted to only Nitrofurantoin prescription */
/*************************************************************************************************/

/* 20. Calculate the propensity with the larger dataset with all antibiotic prescriptions associated with UTI */
proc logistic data=tmp1.uti_dataset_nitro;
	class Sex (missing) prior_rx_flag (missing) prior_visit_flag(missing) MRP(missing) VIRTUAL(missing) &hsda_vars(missing) &DNBTIPPE_vars(missing);
	model VIRTUAL(REF='0') = Sex prior_rx_flag prior_visit_flag MRP DOBYYYY wgtccup prior_rx_count &hsda_vars &DNBTIPPE_vars prop_virtual
	/link=glogit rsquare;
	output out = tmp1.uti_dataset_nitro pred = ps;
run;

/* 21. Perform propensity score matching with greedy k=1 matching and a caliper of 0.25 */

proc psmatch data=tmp1.uti_dataset_nitro;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL &hsda_vars &DNBTIPPE_vars;
	psmodel VIRTUAL (Treated='1') = Sex prior_rx_flag prior_visit_flag MRP DOBYYYY prior_rx_count wgtccup &hsda_vars &DNBTIPPE_vars prop_virtual;
	match method=greedy(k=1 order=random(seed=12345)) distance=lps caliper=0.25;
	assess lps allcov/ plots=(STDDIFF);
	output out(obs=match)=uti_matched_nitro lps=LPS matchid=MID;
run;

/* Save the matched data */

data 'R:\working/uti_matched_nitro.sas7bdat';
	set uti_matched_nitro;
run;

proc export data=uti_matched_nitro
  outfile='uti_matched_nitro.csv'
  dbms=csv;
run;

/* 22. Visualize propensity score distribution on unmatched and matched data */

title "Propensity Score Distribution of Unmatched Data for Individuals Prescribed Nitrofuranoin";
proc sgplot data=tmp1.uti_dataset_nitro;
	histogram ps / group=VIRTUAL transparency=0.5;
	density ps /group=VIRTUAL;
	xaxis label="Propensity score";
	yaxis label="Frequency";
run;
title;

title 'Propensity Score Distribution of Matched Data Individuals Prescribed an Nitrofuranoin';
proc sgplot data=tmp1.uti_matched_nitro;
	histogram _PS_ / group=VIRTUAL transparency=0.5;
	density _PS_ /group=VIRTUAL;
	xaxis label="Propensity score";
	yaxis label="Frequency";
run;
title;

/* 23. Run linear regression on research question 3 - days of Nitrofurantoin prescribed */

/* Unmatched Data */
proc glm data=tmp1.uti_dataset_nitro;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (ref='0') &hsda_vars &DNBTIPPE_vars;
	model Days_Supply_Dispensed=VIRTUAL Sex prior_rx_flag prior_visit_flag MRP DOBYYYY prior_rx_count wgtccup &hsda_vars prop_virtual / solution;
	lsmeans VIRTUAL / pdiff=all cl;
run;

/* Matched Data */
proc glm data=tmp1.uti_matched_nitro;
	class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (ref='0') &hsda_vars &DNBTIPPE_vars;
	model Days_Supply_Dispensed=VIRTUAL Sex prior_rx_flag prior_visit_flag MRP DOBYYYY prior_rx_count wgtccup &hsda_vars prop_virtual / solution;
	lsmeans VIRTUAL / pdiff=all cl;
run;


/* 24. Sensitivity analysis with IPSW */

/* Create the Propensity Scores */

proc logistic data=tmp1.uti_dataset_nitro;
  class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (ref='0') BROAD &hsda_vars &DNBTIPPE_vars;
  model VIRTUAL = Sex prior_rx_flag prior_visit_flag prior_rx_count MRP DOBYYYY wgtccup &hsda_vars &DNBTIPPE_vars prop_virtual
  /link=glogit rsquare;
  output out = ps_nitro pred = ps;
run;

/* Calculate Inverse Probability Weight */
data ps_weight_nitro;
  set ps_nitro;
  ps_weight_nitro=1/ps_nitro;
run;

/* Adjust the weight for the cohort */
proc sql;
  create table ps_weight_adj_nitro as
  select *, (count(*)/30791)*ps_weight_nitro as ps_weight_adj_nitro /* Replace the value here with the number of observations in the ps_weight_overall dataset */
  from ps_weight_nitro group by VIRTUAL;
quit;

/* 25. Run the model */
proc glm data=ps_weight_adj_nitro;
  class Sex prior_rx_flag prior_visit_flag MRP VIRTUAL (REF='0') BROAD &hsda_vars &DNBTIPPE_vars;
  model Days_Supply_Dispensed=VIRTUAL Sex prior_rx_flag prior_visit_flag prior_rx_count MRP DOBYYYY wgtccup &hsda_vars prop_virtual / solution;
  weight ps_weight_adj;_nitro
  lsmeans VIRTUAL / pdiff=all cl;
run;

/* 26. Visualize the distribution of the adjusted inverse propensity score */
title 'Propensity Score Distribution of Inverse PS Weighted Data for Individuals Prescribed an Nitrofurantoin';
  proc sgplot data=ps_weight_adj_nitro;
	histogram ps_weight_adj_nitro / group=VIRTUAL transparency=0.5;
	density ps_weight_adj /group=VIRTUAL;
	xaxis label="propensity score";
	yaxis label="frequency";
run;
title;
