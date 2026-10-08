
/***************************************************************************************
        PURPOSE:    Populate the Other Names object
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     to add other names to accounts. even though pref names and nicknames were added to the account,
     I went ahead and put all names in this object because of the additional indicators that were
     tied to the names (such as publish indicator and end date, etc).

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version
                    need custom fields:
                    ASLE_Prefix__c  (picklist)
                    ASLE_LastName__c
                    ASLE_FirstName__c
                    ASLE_MiddleName__c
                    ASLE_Suffix__c  (picklist)
                    ASLE_PluralName__c
                    ASLE_Salutation__c
                    ASLE_CombinedSalutation__c
                    ASLE_OkayToPublish__c (checkbox - default=TRUE)
                    ASLE_Comment__c longtext
                    also, update other name field to 150 (100 is not long enough to hold nameformn)
                    also, add name types to picklist
*************************************************************************************************/
Use SleekConversion;

drop table if exists ASLE_Other_Names__c_load;

select distinct  
        a.Id                    as ASLE_Account__c,
        n.namekey               as ASLE_External_Id__c,
        trim(t.table_val)       as ASLE_Other_Name_Type__c,
        trim(n.nametitle)       as ASLE_Prefix__c,
        trim(n.namefirst)       as ASLE_FirstName__c,
        trim(n.namemiddle)      as ASLE_MiddleName__c,
        trim(n.namelast)        as ASLE_LastName__c,
        trim(n.namesuffix)      as ASLE_Suffix__c,
        trim(n.nameformn)       as ASLE_Other_Name__c,
        trim(n.nameplural)      as ASLE_PluralName__c,
        trim(n.namesalut)       as ASLE_Salutation__c,
        trim(n.namecsalut)      as ASLE_CombinedSalutation__c,
        trim(s.table_val)       as ASLE_Source__c,
        trim(n.namecomm)        as ASLE_Comment__c,
        case when n.namepubfl='Y' then 1 else 0 end as ASLE_OkayToPublish__c,
        case when n.namedflag='N' then null else cast(n.namedate as date) end as ASLE_End_Date__c,
        cast(n.namecrdate as date) as ASLE_Start_Date__c,
        n.namecrdate            as CreatedDate,
        n.namedate              as LastModifiedDate
into    ASLE_Other_Names__c_load
from    MuhlMillProd..name n
join    muhlmillprod..name_types t on n.nametype=t.table_code
join    sf_accounts a on n.nameid=a.ASLE_External_ID_c
left    join muhlmillprod..source_types s on n.namesource=s.table_code;
 
--check for dupes (none)
select  count(*),ASLE_External_Id__c
from    ASLE_Other_Names__c_load
group by ASLE_External_Id__c
having count(*)>1;

-- export list for loading
select  *
from    ASLE_Other_Names__c_load;