
/***************************************************************************************
        PURPOSE:    Populate the Accounts object
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     localizes a list of entities for loading as person accounts and organizations.
     creates load tables to be used for importing into SFEC.
	 - REMINDER - TURN OFF FLOW THAT AUTO-CREATES HOUSEHOLDS

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  08-25-2026:  Original version

                    household relationship codes: 
                    where relationship.table_code in ('ssp','sp','lp','dsp')

                    core table types:
                    9	      	                    (2 persons and 7 aff orgn)                                             
                    100246	INDIV 	Individuals     (persons)                                                   
                    506	    SF    	Special Funds   (affiliations?)                                                 
                    5912	C     	Corporation     (nonperson)                                                
                    19	    AL    	Alumni          (alumni classes - aff orgn)                                                       
                    10	    DV    	Development     (prizes/awards - aff orgn)                                                        
                    1530	F     	Foundation      (nonperson)                                                 
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: extract all record types from org using soql and save to a table sf_recordtypes
/*
    select Id, Name, SobjectType from RecordType
*/
--================================================================================================

--================================================================================================
-- PART TWO: build load table for persons
-- make sure picklists contain proper values or are marked unrestricted
-- 100,248 individuals
--================================================================================================
drop table if exists Account_person_load;
with nicknames as (
	select	nameid, trim(namefirst) as namefirst, row_number() over (partition by nameid order by namekey desc) as rnum
	from	MuhlMillProd..name x
	where	nametype = 'n' and namefirst <> ''
),
prefname as (
	select	nameid, trim(namefirst) as namefirst,trim(namemiddle) as namemiddle, trim(namelast) as namelast, 
			trim(nametitle) as nametitle, trim(namesuffix) as namesuffix, trim(nameformn) as nameformal,
			trim(nameplural) as namehhformal, trim(namesalut) as nameformalsalut, trim(namecsalut) as namehhformalsalut,
			row_number() over (partition by nameid order by namekey desc) as rnum
	from	MuhlMillProd..name x
	where	nametype = 'a'
),
pressalu as (
	select	nameid, trim(namefirst) as namefirst,trim(namemiddle) as namemiddle, trim(namelast) as namelast, 
			trim(nametitle) as nametitle, trim(namesuffix) as namesuffix, trim(nameformn) as nameformal,
			trim(nameplural) as namehhformal, trim(namesalut) as nameformalsalut, trim(namecsalut) as namehhformalsalut,
			row_number() over (partition by nameid order by namekey desc) as rnum
	from	MuhlMillProd..name x
	where	nametype = 'ps'
)
select	ASLE_External_ID__c					= c.coreid
		, ASLE_External_ID__pc				= c.coreid
		, PersonBirthdate					= cast(corebirthd as date)
		, ASLE_Deceased__pc					= case when deathid is not null then 1 else 0 end
		, ASLE_Date_of_Death__pc			= cast(deathdecdt as date)
		, PersonDeceasedDate				= cast(deathdecdt as date)
		, PersonGenderIdentity				= case when coresex = 'M' then 'Male'
												   when coresex = 'F' then 'Female'
												   when coresex = 'C' then 'Combined' end
		, PersonMaritalStatus				= case when trim(m.table_val) <> '' then trim(m.table_val) end
		, ASLE_Ethnicity__pc				= case when trim(e.table_val) like '%Non%Hispanic%' then 'Not Hispanic/Latino'
												   when trim(e.table_val) = 'Hispanic' then 'Hispanic/Latino'
												   when trim(e.table_val) in ('N/A','Unknown') then 'Unknown' end
		, ASLE_Race__pc						= case when trim(e.table_val) in ('N/A','Unknown') then 'Unknown'
												   when trim(e.table_val)='Native American or Alaskan' then 'Native American/Alaska Native'
												   when trim(e.table_val) in ('Asian','Native Hawaiian Pacific') then 'Asian/Pacific Islander' 
												   when trim(e.table_val) like 'White%' then 'Caucasian/White'
												   when trim(e.table_val) like 'Black%' then 'African American/Black' end
		, ASLE_Citizenship_Status__pc		= case when trim(e.table_val) ='International Student (Non-Resident Alien)' then trim(e.table_val) end
		, Description						= case when trim(isnull(corecomm, '')) <> '' then trim(corecomm) end
		, ASLE_Primary_Constituent_Role__c  = case when trim(isnull(t.table_val, '')) <> '' then trim(t.table_val) end
		, ASLE_VSE_Donor_Category__c		= case when trim(t.table_val)  = 'Alumni' then 'A. Alumni' else 'B. Nonalumni Individuals' end
		, AccountSource						= case when trim(isnull(s.table_val, '')) <> '' then trim(s.table_val) end
		, Industry							= trim(i.table_val)

		--names
		, LastName							= n.namelast
		, FirstName							= n.namefirst
		, MiddleName						= n.namemiddle
		, Salutation						= n.nametitle	
		, Suffix							= n.namesuffix
		, ASLE_Nickname__c					= nick.namefirst
		, ASLE_Nickname_Override__c			= case when isnull(nick.nameid,'')<>'' then 1 else 0 end
		, ASLE_Formal_Salutation__c			= n.nameformalsalut
		, ASLE_Formal_Salutation_Override__c = case when isnull(n.nameformalsalut,'')<>'' then 1 else 0 end
		, ASLE_Formal_Name__c				= n.nameformal
		, ASLE_Formal_Name_Override__c		= case when isnull(n.nameformal,'')<>'' then 1 else 0 end
		, ASLE_President_s_Salutation__c	= p.nameformal
		, ASLE_President_s_Salutation_Override__c = case when isnull(p.nameformal,'')<>'' then 1 else 0 end
		
		--custom
		, ASLE_Years__c						= case when trim(isnull(coretext, '')) <> '' then trim(coretext) end
		, ASLE_Preferred_Year__pc			= case when trim(isnull(coreprefyr, '')) <> '' then trim(coreprefyr) end
		, ASLE_AlternateId__c				= case when trim(isnull(corealtid, '')) <> '' then trim(corealtid) end
		, ASLE_TitleBar__c					= case when trim(isnull(corettlbar, '')) <> '' then trim(corettlbar) end
		, ASLE_DeathComment__pc				= case when trim(isnull(deathcomm, '')) <> '' then trim(deathcomm) end
		, ASLE_DeathCause__pc				= case when trim(isnull(deathcause, '')) <> '' then trim(deathcause) end
		, ASLE_DeathLocation__pc			= case when isnull(deathcity, '') <> '' or isnull(deathplace, '') <> '' or isnull(ct.table_val, '') <> '' then
												case when isnull(deathcity, '') <> '' then trim(deathcity) else '' end +
													case when isnull(deathplace, '') <> '' then 
														case when isnull(deathcity, '') <> '' then ', ' else '' end + trim(deathplace) end +
												case when isnull(ct.table_val, '') <> '' then ' ' +  trim(ct.table_val) else '' end end 
		, ASLE_DeathCorroboration__pc		= case when isnull(deathnotif, '') <> '' then trim(deathnotif) else '' end +
												case when isnull(deathcorr, '') <> '' then 
													case when isnull(deathnotif, '') <> '' then '; ' else '' end + trim(deathcorr) end

		--audit
		, RecordTypeId						= rt.Id
		, CreatedDate						= corecrdate
		, LastModifiedDate					= coredate
into	Account_person_load		
from	MuhlMillProd..corebio	c
left	join MuhlMillProd..death on deathid = coreid
left	join MuhlMillProd..countries ct on ct.table_code = deathcntry
left	join MuhlMillProd..marital_status m on m.table_code = coremaritl
left	join MuhlMillProd..constituent_types t on t.table_code = coreconst
left	join nicknames nick on nick.nameid = coreid and nick.rnum = 1
left	join prefname n on n.nameid = coreid and n.rnum = 1
left	join pressalu p on p.nameid = coreid and p.rnum = 1
left	join MuhlMillProd..ethnic_groups e on e.table_code = coreethnic
left	join MuhlMillProd..source_types s on s.table_code = coresource
left	join MuhlMillProd..industries i on c.coreindust=i.table_code
join	sf_recordtypes rt on rt.SObjectType = 'Account' and rt.Name = 'Person Account'
where	c.coretbltyp='INDIV'
or		(trim(c.coretbltyp)='' and trim(coresex)='M');

-- get picklists and setup custom fields!!
select distinct PersonMaritalStatus from Account_person_load;
select distinct ASLE_Ethnicity__pc from Account_person_load;
select max(len(ASLE_DeathCause__pc)) from Account_person_load;
select max(len(ASLE_DeathComment__pc)) from Account_person_load;
select max(len(ASLE_DeathLocation__pc)) from Account_person_load;
select max(len(ASLE_DeathCorroboration__pc)) from Account_person_load;
select max(len(ASLE_Years__c)) from Account_person_load;
select max(len(ASLE_TitleBar__c)) from Account_person_load;
select max(len(ASLE_AlternateId__c)) from Account_person_load;
select max(len(ASLE_Preferred_Year__pc)) from Account_person_load;

--================================================================================================
-- PART THREE: export table result to csv and load via DL.
-- import results back into sql server to include the new ID to table sf_account_person
--================================================================================================
select * from Account_person_load;

--================================================================================================
-- PART FOUR: create load table for nonpersons
-- update picklists and add custom columns if needed
-- Muhlenberg College id = '0000023240'
-- count: 7461
--================================================================================================
drop table if exists Account_nonperson_load;
with nicknames as (
	select	nameid, trim(namefirst) as namefirst, row_number() over (partition by nameid order by namekey desc) as rnum
	from	MuhlMillProd..name x
	where	nametype = 'n' and namefirst <> ''
),
prefname as (
	select	nameid, trim(namefirst) as namefirst,trim(namemiddle) as namemiddle, trim(namelast) as namelast, 
			trim(nametitle) as nametitle, trim(namesuffix) as namesuffix, trim(nameformn) as nameformal,
			trim(nameplural) as namehhformal, trim(namesalut) as nameformalsalut, trim(namecsalut) as namehhformalsalut,
			row_number() over (partition by nameid order by namekey desc) as rnum
	from	MuhlMillProd..name x
	where	nametype = 'a'
),
pressalu as (
	select	nameid, trim(namefirst) as namefirst,trim(namemiddle) as namemiddle, trim(namelast) as namelast, 
			trim(nametitle) as nametitle, trim(namesuffix) as namesuffix, trim(nameformn) as nameformal,
			trim(nameplural) as namehhformal, trim(namesalut) as nameformalsalut, trim(namecsalut) as namehhformalsalut,
			row_number() over (partition by nameid order by namekey desc) as rnum
	from	MuhlMillProd..name x
	where	nametype = 'ps'
)
select	ASLE_External_ID__c					= c.coreid
		, Description						= trim(corecomm)
		, ASLE_Primary_Constituent_Role__c  = trim(t.table_val)
		, ASLE_VSE_Donor_Category__c		= case when c.coreconst='G' then ''
												   when c.coreconst in ('C','CF') then 'D. Corporations'
												   when c.coreconst in ('F','FF') then 'C. Foundations'
												   else 'F. Other Organizations' end
		, AccountSource						= case when trim(isnull(s.table_val, '')) <> '' then trim(s.table_val) end
		, Industry							= trim(i.table_val)
		, Type								= trim(t.table_val)
		, Website							= trim(w.intaddress)

		--names
		, Name								= trim(n.namelast + 
											  case when trim(isnull(n.namesuffix,''))<>'' then ' '+trim(n.namesuffix) else '' end +
											  case when trim(isnull(n.nametitle,''))<>'' or trim(isnull(n.namefirst,''))<>'' then ', ' else '' end +
											  case when trim(isnull(n.nametitle,''))<>'' then trim(n.nametitle) + ' ' else '' end +
											  case when trim(isnull(n.namefirst,''))<>'' then trim(n.namefirst) + ' ' else '' end +
											  case when trim(isnull(n.namemiddle,''))<>'' then trim(n.namemiddle) else '' end)
		, n.nametitle, n.namefirst, n.namemiddle, n.namelast, n.namesuffix
		, ASLE_Nickname__c					= nick.namefirst
		, ASLE_Nickname_Override__c			= case when isnull(nick.nameid,'')<>'' then 1 else 0 end
		, ASLE_Formal_Salutation__c			= n.nameformalsalut
		, ASLE_Formal_Salutation_Override__c = case when isnull(n.nameformalsalut,'')<>'' then 1 else 0 end
		, ASLE_Formal_Name__c				= n.nameformal
		, ASLE_Formal_Name_Override__c		= case when isnull(n.nameformal,'')<>'' then 1 else 0 end
		, ASLE_President_s_Salutation__c	= p.nameformal
		, ASLE_President_s_Salutation_Override__c = case when isnull(p.nameformal,'')<>'' then 1 else 0 end
		
		--custom
		, ASLE_TitleBar__c					= case when trim(isnull(corettlbar, '')) <> '' then trim(corettlbar) end

		--audit
		, RecordTypeId						= case when trim(coreconst)='IN' then re.Id
												   when trim(coreconst)='G' then ro.Id
												   when trim(coretbltyp)='C' then rc.Id
												   when trim(coretbltyp)='F' then rf.Id
												   else ra.Id end
		, CreatedDate						= corecrdate
		, LastModifiedDate					= coredate
into	Account_nonperson_load		
from	MuhlMillProd..corebio	c
left	join MuhlMillProd..constituent_types t on t.table_code = coreconst
left	join nicknames nick on nick.nameid = coreid and nick.rnum = 1
left	join prefname n on n.nameid = coreid and n.rnum = 1
left	join pressalu p on p.nameid = coreid and p.rnum = 1
left	join MuhlMillProd..source_types s on s.table_code = coresource
left	join MuhlMillProd..industries i on c.coreindust=i.table_code
left	join (select intid, intaddress from MuhlMillProd..internetaddress where intaddress like '%www%') w on c.coreid=w.intid
join	sf_recordtypes rc on rc.SObjectType = 'Account' and rc.Name = 'Corporation'
join	sf_recordtypes rf on rf.SObjectType = 'Account' and rf.Name = 'Foundation'
join	sf_recordtypes ra on ra.SObjectType = 'Account' and ra.Name = 'Affiliated Organization'
join	sf_recordtypes ro on ro.SObjectType = 'Account' and ro.Name = 'Other'
join	sf_recordtypes re on re.sobjecttype = 'Account' and re.Name = 'Educational Institution'
where	trim(c.coretbltyp) in ('C','F','AL');


-->> quick fix to blank name:
update Account_nonperson_load set Name='(No Name)' where Name='';

--================================================================================================
-- PART FIVE: export table result to csv and load via DL.
-- reimport the successful records to get the id number
--================================================================================================
select * from Account_nonperson_load;

--================================================================================================
-- PART SIX: run update to Parent ID on alumni classes
--================================================================================================
drop table if exists Account_update_pid;
select	Id,
		(select Id from sf_account_nonperson where Name='Muhlenberg College') as ParentId
into	Account_update_pid
from	sf_account_nonperson a
where	a.Type='Alumni Organization';

select	* from Account_update_pid;


