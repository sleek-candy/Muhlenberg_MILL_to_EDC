
/***************************************************************************************
        PURPOSE:    Populate the relationship objects
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     AccountAccountRelation
     AccountContactRelation
     ContactContactRelation
     PartyRoleRelation

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: create a local mu_relation_mapping table to identify legit relationships
-- starting with (f) families; and we only want the pair listed once
--================================================================================================
drop table if exists mu_relation_mapping;
select distinct  
        trim(t1.table_val) as relation1, trim(t2.table_val) as relation2, 0 as IsError
into    mu_relation_mapping
from    muhlmillprod..relation r
join    MuhlMillProd..relationships t1 on r.relisa=t1.table_code 
join    MuhlMillProd..relationships t2 on r.relwhose=t2.table_code
join    sf_accounts a1 on r.relid=a1.ASLE_External_ID_c and a1.PersonContactId is not null
join    sf_accounts a2 on r.relrelatid=a2.ASLE_External_ID_c and a2.PersonContactId is not null
where   r.relisagrp='f' and r.relwhogrp='f' and r.relisa>r.relwhose
order by 1,2;

-- set error flags on impossible relation types
-- any records with these combos will be returned to MU for cleanup
update mu_relation_mapping set IsError=1 where relation1='Child' and relation2='Ex-Wife';
update mu_relation_mapping set IsError=1 where relation1='Daughter' and relation2='Grandmother';
update mu_relation_mapping set IsError=1 where relation1='Father' and relation2='Niece';
update mu_relation_mapping set IsError=1 where relation1='Parent' and relation2='Brother';
update mu_relation_mapping set IsError=1 where relation1='Parent' and relation2='Niece';
update mu_relation_mapping set IsError=1 where relation1='Sister' and relation2='Father';
update mu_relation_mapping set IsError=1 where relation1='Son' and relation2='Brother';
update mu_relation_mapping set IsError=1 where relation1='Uncle' and relation2='Aunt';

-- NEXT, using our trusty mapping table we can create Party Roles for CCR
drop table if exists PartyRoleRelation_CCR_load;
select	Name						= relation1 + '-' + relation2 + '_CCR'
		,RoleName					= relation1 
		,RelatedRoleName			= relation2
		,RelationshipObjectName		= 'Contact_Contact_Relationship'
		,ShouldCreaInversRoleAuto	= IIF(relation1 != relation2, 'true', 'false')
into    PartyRoleRelation_CCR_load
from    mu_relation_mapping 
where   IsError=0;

-->> export rows for loading
select * from PartyRoleRelation_CCR_load;

-->> import the party role relations back into the db
-->> I called it sf_partyroles and it only needs the one-sided relationship

ALTER TABLE sf_partyroles ALTER COLUMN RoleName VARCHAR(50) COLLATE Latin1_General_BIN;
ALTER TABLE sf_partyroles ALTER COLUMN RelatedRoleName VARCHAR(50) COLLATE Latin1_General_BIN;

--================================================================================================
-- PART TWO: load CONTACT CONTACT RELATIONSHIPS for constituents
--================================================================================================
drop table if exists ContactContactRelation_family_load;
select  a1.PersonContactId                      as ContactId,
        a2.PersonContactId                      as RelatedContactId,
        1                                       as ASLE_Autocreate_Reciprocal_Relationship__c,
        -->> note: update after gifts are loaded... auto soft crediting options
        cast(r.relkey as varchar(10))+'-'+cast(r.relrevkey as varchar(10))  as ASLE_External_ID__c,
        case when r.relstrtdat is null and r.relstopdat is not null then r.relstopdat 
             else r.relstrtdat end              as StartDate,
        r.relstopdat                            as EndDate,
        p.Id                                    as PartyRoleRelationId,
        least(r.relcrdate,r.reldate)            as CreatedDate,
        greatest(r.reldate,r.relcrdate)         as LastModifiedDate
into    ContactContactRelation_family_load
from    muhlmillprod..relation r
join    MuhlMillProd..relationships t1 on r.relisa=t1.table_code 
join    MuhlMillProd..relationships t2 on r.relwhose=t2.table_code
join    sf_accounts a1 on r.relid=a1.ASLE_External_ID_c and a1.PersonContactId is not null
join    sf_accounts a2 on r.relrelatid=a2.ASLE_External_ID_c and a2.PersonContactId is not null  
join    sf_partyroles p on t1.table_val=p.RoleName and t2.table_val=p.RelatedRoleName
where   a1.Id<>a2.Id;

-->> export rows for loading
select * from ContactContactRelation_family_load;

-->> bring back all of contactcontactrelation so the auto-created ones can be updaated (sf_contactcontactrelation)
/* SELECT ASLE_External_ID__c, ASLE_Autocreate_Reciprocal_Relationship__c, ContactId, ASLE_Party_Relation_Role_Name__c, Id, IsActive, PartyRoleRelationId, RelatedContactId, RelatedInverseRecordId 
FROM ContactContactRelation 
*/
-->> update the blank xids by flip-flopping the original load xids

drop table if exists ContactContactRelation_family_updxid;
select  r1.Id,
        substring(r2.ASLE_External_ID_c,charindex('-',r2.ASLE_External_ID_c)+1,8)+'-'+substring(r2.ASLE_External_ID_c,1,charindex('-',r2.ASLE_External_ID_c)-1) as ASLE_External_ID__c,
        r2.ASLE_External_ID_c
into    ContactContactRelation_family_updxid
from    sf_contactcontactrelation r1
join    sf_contactcontactrelation r2 on r1.RelatedInverseRecordId=r2.Id
where   r1.ASLE_External_ID_c is null;

-->> export rows for loading
select * from ContactContactRelation_family_updxid;

--================================================================================================
-- PART TWO: load CONTACT CONTACT RELATIONSHIPS for non-constituents
--================================================================================================