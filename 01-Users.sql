/***************************************************************************************
        PURPOSE:    Populate the User object with staff members and prospect managers
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     Gathers all metadata from the Muhlenberg Millennium backup database.  This includes, lookup
     values, usage counts (which shows us where the heaviest and most important kinds of data 
     live).  It also helps us to translate MILL lookup values to Salesforce picklists and processes.
     In addition, the BAER Reports are shared to our business analysts who are able to advise on 
     best practices moving forward based on past usage.

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  08-25-2026:  Original version
     
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: pull back list of users existing in SF via dataloader.
-- table name should be sf_users. it will be used in Part Two.
-- SOQL:
/*  
    select Id, Username, Alias, FirstName, LastName, IsActive, Email, EmailEncodingKey, LanguageLocaleKey, 
    LocaleSidKey, ProfileId, TimeZoneSidKey, UserType, ASLE_ExternalID__c, ASLE_ExternalUsername__c 
    from User
    where Email like '%muhlenberg.edu%'
*/
--================================================================================================
ALTER TABLE sf_users ALTER COLUMN LastName VARCHAR(50) COLLATE Latin1_General_BIN;
ALTER TABLE sf_users ALTER COLUMN FirstName VARCHAR(50) COLLATE Latin1_General_BIN;
ALTER TABLE sf_users ALTER COLUMN Email VARCHAR(50) COLLATE Latin1_General_BIN;
ALTER TABLE sf_users ALTER COLUMN Username VARCHAR(50) COLLATE Latin1_General_BIN;
ALTER TABLE sf_users ALTER COLUMN ProfileId VARCHAR(50) COLLATE Latin1_General_BIN;

--========================================================================
-- PART TWO: create an upsert table to add the new records and to update
-- external ids for existing users
--========================================================================

drop table if exists User_upsert;
with email as (
    select	intid, intaddress,
		    row_number() over (partition by intid order by intpref desc, case when intstop is null then 1 else 2 end, case when trim(inttype) = 'feml' then 2 else 1 end) as rnum
    from	MuhlMillProd..internetaddress
    join	MuhlMillProd..internetaddress_type t on t.table_code = inttype
    where	intaddress like '%muhlenberg.edu%'
)
select  isnull(x.Id,'')                                     as Id,
        trim(coalesce(x.FirstName,t.namefirst))             as FirstName,
        trim(coalesce(x.LastName,t.namelast))               as LastName,
        trim(coalesce(x.Email,e.intaddress+'.inactive'))    as Email,
        trim(coalesce(x.Username,e.intaddress))             as Username,
        trim(lower(coalesce(substring(x.FirstName,1,1)+substring(x.LastName,1,4),substring(t.namefirst,1,1)+substring(t.namelast,1,4)))) as Alias,
        coalesce(x.IsActive,0)                              as IsActive,
        trim(coalesce(x.ProfileId,'00ehk000000CGRwAAO'))    as ProfileId, -- minimum access if newly added
        'N'                                                 as DigestFrequency,
        'UTF-8'                                             as EmailEncodingKey,
        'en_US'                                             as LanguageLocaleKey,
        'en_US'                                             as LocaleSidKey,
        'America/New_York'                                  as TimeZoneSidKey,
        u.userid                                            as ASLE_ExternalID__c,
        trim(u.user_name)                                   as ASLE_ExternalUsername__c
into    User_upsert
from  ( select  x.relid as userid, u.user_name
        from    MuhlMillProd.dbo.relation x
        join    MuhlMillProd.dbo.userlist u on x.relid=u.user_id#
        join    MuhlMillProd.dbo.relationships r on x.relisa=r.table_code
        where   x.relisa in ('pm','pmasst','pmdir','pmres','pms','pmsrd','sm01','sd01','st01','sv01','gsol','fpm')
        union   
        select  x.gsolsolid, u.user_name
        from    MuhlMillProd.dbo.solicitor x
        join    MuhlMillProd.dbo.userlist u on x.gsolsolid=u.user_id#
        union
        select  x.taskid, u.user_name
        from    MuhlMillProd.dbo.tasks x
        join    MuhlMillProd.dbo.userlist u on x.taskid=u.user_id#
     )u
left	join (select nameid, namefirst, namelast, row_number() over (partition by nameid order by nametype) as rnum from MuhlMillProd.dbo.name) t on t.nameid = u.userid and t.rnum = 1
left    join email e on e.intid=u.userid and e.rnum=1
left    join sf_users x on t.namelast=x.lastname
where   u.user_name<>'report_admin';

--========================================================================
-- PART THREE: export User_upsert to csv file and import via DL
--========================================================================
select * from User_upsert;