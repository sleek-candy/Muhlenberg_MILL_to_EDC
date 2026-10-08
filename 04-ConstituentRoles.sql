
/***************************************************************************************
        PURPOSE:    Populate the Constituent Roles object
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     to add constituent roles (constituent types) to accounts

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version
                    remember to check picklists and turn off the flow that runs after save                            
*************************************************************************************************/
Use SleekConversion;

drop table if exists ConstituentRole_load;
select  PersonId                            = a.Id
        , ASLE_External_ID__c               = c.coreid+'ct'
        , ASLE_Primary__c                   = 1
        , RoleType                          = case when trim(t.table_val)='' then 'Friend' 
                                                   when trim(t.table_val) like 'Former%' then 'Parent' 
                                                   else trim(t.table_val) end
        , Status                            = case when trim(t.table_val) like 'Former%' then 'Former' else 'Active' end
        , CreatedDate						= corecrdate
		, LastModifiedDate					= coredate
into    ConstituentRole_load
from    MuhlMillProd..corebio c
join    MuhlMillProd..constituent_types t on c.coreconst=t.table_code
join    sf_accounts a on c.coreid=a.ASLE_External_ID_c
where   a.PersonContactId is not null;

select  * from ConstituentRole_load;

select distinct RoleType from ConstituentRole_load;