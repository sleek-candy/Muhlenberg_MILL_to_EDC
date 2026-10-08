
/***************************************************************************************
        PURPOSE:    Populate the employment records
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        Person Employment

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: populate person employment where all accounts exist
--================================================================================================
-- Work on jobs records with a constituent link first
drop table if exists PersonEmployment_cons_load;
with primary_e as (
	select jobsid, jobskey, row_number() over (partition by jobsid order by jobskey desc) as rnum
	from	MuhlMillProd..jobs
	where	jobsstatus = 'act'
)
select	ASLE_External_ID__c			= 'j_' + convert(varchar(10), r.jobskey)
		, Name						= trim(e.name)
		, RelatedPersonId			= a.PersonContactId
		, Position					= case when trim(isnull(r.jobstitle, '')) <> '' then left(trim(r.jobstitle), 255) end
		, EmploymentStatus			= case when jobsstatus in ('act', 'actS') then 'Active' 
		                                   when jobsstatus = '' and isnull(jobsstopdt, '1/1/2050') < getdate() then 'No Longer at this Position'
										   when jobsstatus <> '' then trim(s.table_val) 
									  end
		, AnnualIncome				= null
		, StartDate					= jobsstrtdt
		, EndDate					= jobsstopdt
		, AccountId					= e.id
		, ASLE_Primary_Employment__c = case when p.jobskey is not null then 'true' else 'false' end 
		, CreatedDate				= r.jobscrdate
		, LastModifiedDate			= r.jobsdate
		, Occupation				= case when trim(isnull(o.table_val, '')) <> '' then trim(isnull(o.table_val, '')) end
		, ASLE_Mill_Industry__c			= case when trim(isnull(i.table_val, '')) <> '' then trim(isnull(i.table_val, '')) end
		, ASLE_Mill_Division__c			= case when trim(isnull(r.jobscodiv, '')) <> '' then trim(isnull(r.jobscodiv, '')) end
		, ASLE_Comment__c			= case when trim(isnull(jobscomm, '')) <> '' then trim(isnull(jobscomm, '')) end
into	PersonEmployment_cons_load
from	MuhlMillProd..jobs r
join	sf_accounts a on a.ASLE_External_ID_c = r.jobsid and a.PersonContactId is not null
join	sf_accounts e on e.ASLE_External_ID_c = r.jobscpnyid and e.PersonContactId is null
join	MuhlMillProd..job_status s on s.table_code = jobsstatus
join	MuhlMillProd..occupations o on o.table_code = jobsoccup
join	MuhlMillProd..industries i on i.table_code = jobsindust
left	join primary_e p on p.jobskey = r.jobskey and p.rnum = 1
where	trim(isnull(r.jobscpnyid, '')) <> '';

-->> check values in custom fields
select	distinct ASLE_mill_Industry__c from PersonEmployment_cons_load;
select distinct asle_mill_division__c from PersonEmployment_cons_load;
select max(len(asle_comment__c)) from PersonEmployment_cons_load;

-->> get records for loading
select * from PersonEmployment_cons_load;

--================================================================================================
-- PART TWO: non-constituent employers
-- instead of creating 75k possible dupes, created "Legacy Employer Placeholder" account with id "001hR00000OGzjMQAT"
--================================================================================================
drop table if exists PersonEmployment_noncons_load;
-- Non- constituent jobs records
with all_records as (
	select	jobskey, case when isnull(jobsconame, '') = '' then 'Unknown' else trim(jobsconame) end as jobsname
	from	MuhlMillProd..jobs
	where	isnull(jobscpnyid, '') = '' 
) 
select	ASLE_External_ID__c			= 'j_' + convert(varchar(10), r.jobskey)
		, Name						= a.jobsname
		, RelatedPersonId			= c.PersonContactId
		, Position					= case when trim(isnull(r.jobstitle, '')) <> '' then left(trim(r.jobstitle), 255) end
		, EmploymentStatus			= case when jobsstatus in ('act', 'actS') then 'Active' 
		                                   when jobsstatus = '' and isnull(jobsstopdt, '1/1/2050') < getdate() then 'No Longer at this Position'
										   when jobsstatus <> '' then trim(s.table_val) 
									  end
		, StartDate					= jobsstrtdt
		, EndDate					= jobsstopdt
		, ASLE_Comment__c			= case when trim(isnull(jobscomm, '')) <> '' then trim(isnull(jobscomm, '')) end
		, AccountId					= '001hR00000OGzjMQAT'
		, CreatedDate				= r.jobscrdate
		, LastModifiedDate			= r.jobsdate
		, Occupation				= case when trim(isnull(o.table_val, '')) <> '' then trim(isnull(o.table_val, '')) end
		, ASLE_Mill_Industry__c		= case when trim(isnull(i.table_val, '')) <> '' then trim(isnull(i.table_val, '')) end
		, ASLE_Mill_Division__c		= case when trim(isnull(r.jobscodiv, '')) <> '' then trim(isnull(r.jobscodiv, '')) end
into	PersonEmployment_noncons_load
from	all_records a
join	MuhlMillProd..jobs r on r.jobskey = a.jobskey
join	sf_accounts c on c.ASLE_External_ID_c = r.jobsid and c.PersonContactId is not null
join	MuhlMillProd..job_status s on s.table_code = jobsstatus
join	MuhlMillProd..occupations o on o.table_code = jobsoccup
join	MuhlMillProd..industries i on i.table_code = jobsindust;

-->> fix mismatched dates
update PersonEmployment_noncons_load
set CreatedDate=LastModifiedDate, LastModifiedDate=CreatedDate 
where LastModifiedDate<CreatedDate;

update PersonEmployment_noncons_load
set CreatedDate=null, LastModifiedDate=null 
where year(createddate)<'1905';

-->> get records for loading
select	* from PersonEmployment_noncons_load;

