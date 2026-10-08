
/***************************************************************************************
        PURPOSE:    Populate the areas of studies and attach majors minors conc to degree records
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        Area of Study
        Majors, Minors, Concentrations

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: populate area of studies
--================================================================================================
select * from MuhlMillProd..fieldlst where table_name = 'school';

-->> create mapping table to collapse the dupes
drop table if exists mu_concentrations_mapping;
select	trim(table_code) conc_code, trim(table_val) conc_name,
		row_number() over (partition by trim(table_val) order by trim(table_code)) as dupeseq
into	mu_concentrations_mapping
from	MuhlMillProd..concentrations
where	trim(table_code) <> '' and (table_actv = 'Y' or exists 
		(select 1 from MuhlMillProd..school where schlcon1 = table_code) or exists 
		(select 1 from MuhlMillProd..school where schlcon2 = table_code) or exists 
		(select 1 from MuhlMillProd..school where schlcon3 = table_code) or exists 
		(select 1 from MuhlMillProd..school where schlcon4 = table_code));
	
drop table if exists ASLE_Area_of_Study__c_load;
select	distinct Name						= conc_name
		,ASLE_Area_of_Study_External_ID__c	= conc_code
into    ASLE_Area_of_Study__c_load
from	mu_concentrations_mapping
where	dupeseq=1;

-->> get rows for loading
select * from ASLE_Area_of_Study__c_load;

-->> pull back success file to get id numbers and name it sf_areaofstudy
-->> pull back all personacademiccredentials into table sf_personacademiccredentials
ALTER TABLE sf_areaofstudy ALTER COLUMN Name VARCHAR(50) COLLATE Latin1_General_BIN;
ALTER TABLE sf_personacademiccredential ALTER COLUMN ASLE_External_ID_c VARCHAR(50) COLLATE Latin1_General_BIN;


--================================================================================================
-- PART ONE: populate majors minors concentrations
--================================================================================================

drop table if exists ASLE_Majors_Minors_Concentrations__c_load;

select	ASLE_External_ID_Majors__c				= 'con1_' + convert(varchar(10), m.schlkey)
		, ASLE_Type__c							= 'Major'
		, ASLE_Area_of_Study__c					= a.Id
		, ASLE_Person_Academic_Credential__c	= c.Id
into	ASLE_Majors_Minors_Concentrations__c_load
from	MuhlMillProd..school m
join	mu_concentrations_mapping p on m.schlcon1=p.conc_code
join	sf_areaofstudy a on a.Name =  p.conc_name and p.dupeseq=1 
join	sf_personacademiccredential c on c.ASLE_External_ID_c = convert(varchar(10), m.schlkey)
where	trim(schlcon1) <> ''
union
select	ASLE_External_ID_Majors__c				= 'con2_' + convert(varchar(10), m.schlkey)
		, ASLE_Type__c							= 'Minor'
		, ASLE_Area_of_Study__c					= a.Id
		, ASLE_Person_Academic_Credential__c	= c.Id

from	MuhlMillProd..school m
join	mu_concentrations_mapping p on m.schlcon2=p.conc_code
join	sf_areaofstudy a on a.Name =  p.conc_name and p.dupeseq=1 
join	sf_personacademiccredential c on c.ASLE_External_ID_c = convert(varchar(10), m.schlkey)
where	trim(schlcon2) <> ''
union
select	ASLE_External_ID_Majors__c				= 'con3_' + convert(varchar(10), m.schlkey)
		, ASLE_Type__c							= 'Major'
		, ASLE_Area_of_Study__c					= a.Id
		, ASLE_Person_Academic_Credential__c	= c.Id

from	MuhlMillProd..school m
join	mu_concentrations_mapping p on m.schlcon3=p.conc_code
join	sf_areaofstudy a on a.Name =  p.conc_name and p.dupeseq=1 
join	sf_personacademiccredential c on c.ASLE_External_ID_c = convert(varchar(10), m.schlkey)
where	trim(schlcon3) <> ''
union
select	ASLE_External_ID_Majors__c				= 'con4_' + convert(varchar(10), m.schlkey)
		, ASLE_Type__c							= 'Minor'
		, ASLE_Area_of_Study__c					= a.Id
		, ASLE_Person_Academic_Credential__c	= c.Id

from	MuhlMillProd..school m
join	mu_concentrations_mapping p on m.schlcon4=p.conc_code
join	sf_areaofstudy a on a.Name =  p.conc_name and p.dupeseq=1 
join	sf_personacademiccredential c on c.ASLE_External_ID_c = convert(varchar(10), m.schlkey)
where	trim(schlcon4) <> ''
;

--> get records for loading
select * from ASLE_Majors_Minors_Concentrations__c_load;