
/***************************************************************************************
        PURPOSE:    Populate the campaign and solicitation records
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        Campaign
		OutreachSourceCode

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: populate the campaign records 
--================================================================================================
drop table if exists Campaign_gifts;
select	ASLE_External_Id__c		= case when table_code = '' then 'default' else convert(varchar(10), c.table_code) end
		, Name					= case when table_code = '' then 'Default' else left(c.table_val, 80) end
		, Status				= case when table_actv='Y' then 'In Progress' else 'Completed' end
		, IsActive				= case when table_actv='Y' then 'true' else 'false' end
		, RecordTypeId			= rt.Id
        , ASLE_Annual_Fund__c	= case when table_code in ('AB','CR') then 'true' else 'false' end
        , CreatedDate           = table_date 
        , LastModifiedDate      = table_date
into    Campaign_gifts
from	MuhlMillProd..campaigns c
join	sf_recordtypes rt on rt.sObjectType = 'Campaign' and rt.Name = 'Fundraising Campaign';

-->> get records for loading
select  *
from    Campaign_gifts;

--================================================================================================
-- PART ONE: populate the outreach source codes
/*
MAIL     
VISIT 
OTHER 
Advanc
MF    
rmail 
IJCU  
PHONE 
HILLEL
AG    
ONLINE
PH1617
*/
--================================================================================================
drop table if exists OutreachSourceCode_load;

select	ASLE_External_ID__c				= trim(sol_code)
		, CampaignId					= coalesce(c.Id,d.Id)
		, SourceCode					= trim(sol_code)
		, Name							= trim(sol_val)
		, Status						= case when sol_active = 'Y' then 'Active' else 'Inactive' end
		, Description					= sol_type
		, ASLE_Campaign_Year__c			= a.sol_campyr
		,CreatedDate					= sol_date
		,LastModifiedDate				= sol_date
into	OutreachSourceCode_load
from	MuhlMillProd..solicitations a
left	join sf_campaigns c on a.sol_camp=c.asle_external_id_c COLLATE Latin1_General_BIN
left	join sf_campaigns d on d.asle_external_id_c='default' COLLATE Latin1_General_BIN
where	sol_code <> '';

-->> update one dupe source code
update OutreachSourceCode_load
set SourceCode='PAREN2'
where Name = 'PARENT - Spring Peer Parent';

-->> get records for loading
select * from OutreachSourceCode_load;