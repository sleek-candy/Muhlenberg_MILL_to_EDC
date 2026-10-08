
/***************************************************************************************
        PURPOSE:    Populate the gift designation records
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        GiftDesignation

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: populate the designation records
--================================================================================================
drop table if  exists GiftDesignation_load;

select	ASLE_External_Id__c			= case when trim(chart_code) = '' then 'default'else trim(chart_code) end
		, Name						= case when trim(chart_code) = '' then 'Default'else trim(chart_val) end
		, ASLE_Short_Name__c		= case when trim(chart_code) = '' then 'Default'else trim(chart_val) end
		, Description				= trim(chart_sort)
		, IsActive					= case when chart_actv = 'Y' then 'true' else 'false' end
		, ASLE_VSE_Category__c		= case when trim(ac.table_val) = 'Current Operations - Financial Aid' then 'Student Financial Aid' 
											 when ac.table_val = 'Capital Purpose - Endow, Faculty and Staff' then 'Fac-Staff Compensations-Endowment'
											 when ac.table_val = 'Current Operations - Library' then 'Library'
											 when ac.table_val = 'Capital Purpose - Endow, Public Service' then 'Endowment - Restricted'
											 when ac.table_val = 'Capital Purpose - Endow, Library' then 'Endowment - Restricted'
											 when ac.table_val = 'Capital Purpose - Endow, Unrestricted' then 'Endowment - Unrestricted'
											 when ac.table_val = 'Current Operations - Unrestricted' then 'Unrestricted'
											 when ac.table_val = 'Capital Purpose - Endow, Research' then 'Research-Endowment'
											 when ac.table_val = 'Capital Purpose - Endow, Academic Divisions' then 'Academic Support-Endowment'
											 when ac.table_val = 'Current Operations - Faculty Compensation' then 'Faculty & Staff Compensation'
											 when ac.table_val = 'Capital Purpose - Endow, Other' then 'Other Endowed Purposes'
											 when ac.table_val = 'Current Operations - Extramural Athletics' then 'Athletics'
											 when ac.table_val = 'Current Operations - Operation of Plant' then 'Operation & Maint. of Plant'
											 when ac.table_val = 'Current Operations - Research' then 'Research'
											 when ac.table_val = 'Deferred Gifts - Endow, Restricted' then 'Endowment - Restricted'
											 when ac.table_val = 'Current Operations - Athletics' then 'Athletics'
											 when ac.table_val = 'Capital Purpose - Endow, Student Aid' then 'Student Financial Aid-Endowment'
											 when ac.table_val = 'Capital Purpose - Loan Funds' then 'Loan Funds'
											 when ac.table_val = 'Current Operations - Other Restricted' then 'Other Restricted'
											 when ac.table_val = 'Capital Purpose - Property, Buildings' then 'Prop., Build. & Equipment'
											 when ac.table_val = 'Current Operations - Public Service' then 'Public Service & Extension'
											 when ac.table_val = 'Current Operations - Academic Divisions' then 'Restricted Academic Divs.' 
											 else 'Other Purposes'
											end 
		, ASLE_Credit_Ledger_Code_1__c = case when trim(isnull(chart_cred, '')) <> '' then left(chart_cred, 5) 
										when len(trim(chart_acct)) = 12 then left(chart_acct, 5)
									end
		, ASLE_Credit_Ledger_Code_2__c = case when trim(isnull(chart_cred, '')) <> '' then substring(chart_cred, 7, 6) 
										when len(trim(chart_acct)) = 12 then substring(chart_acct, 7, 6) 
									end
		, ASLE_Designation_Comments__c = case when trim(chart_comm) <> '' then trim(chart_comm) end 
		--, ASLE_Campaign_Pillar__c	= cg.Id
		
		--, OwnerId					= coalesce(cb.Id, u.Id)
		, CreatedDate				= chart_date
		--, CreatedById				= coalesce(cb.Id, u.Id)
		, LastModifiedDate			= chart_date
		--, LastModifiedById			= coalesce(cb.Id, u.Id)
		, ASLE_Millennium_Acct_No__c = case when trim(chart_acct) <> '' then trim(chart_acct) end 
		, ASLE_Start_Date__c		= chart_strt
		, ASLE_Stop_Date__c			= chart_stop
		, ASLE_Goal__c				= case when trim(g.table_val) <> '' then trim(g.table_val) end 
into	GiftDesignation_load
from	MuhlMillProd..chart_of_accounts c
left	join MuhlMillProd..account_cae ac on ac.table_code = chart_cfae
join	MuhlMillProd..campaign_goals g  on g.table_code = chart_goal;

-->> update any mismatched dates
update GiftDesignation_load 
set CreatedDate=LastModifiedDate, LastModifiedDate=CreatedDate 
where	LastModifiedDate<CreatedDate;

-->> check for dupes
select	count(*), ASLE_External_Id__c
from	GiftDesignation_load
group by ASLE_External_Id__c
having count(*)>1;

-->> get records for loading
select	* from GiftDesignation_load;