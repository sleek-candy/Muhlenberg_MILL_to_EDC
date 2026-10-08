

/***************************************************************************************
        PURPOSE:    Map various codes (setup)
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
-- PART ONE: relationships mapping
--================================================================================================
drop table if exists mu_relationship_mapping;
select	count(*) as numrec, r1.table_code relisa_code, r1.table_val relisa, r2.table_code relwhose_code, r2.table_val relwhose,
        case when r1.table_val like '%Empl%' then 'PersonEmployment'
             when r2.table_val like '%Empl%' then 'PersonEmployment'
             else 'Unmapped Location' end as sf_object
into    mu_relationship_mapping
from	MuhlMillProd..relation r
join	MuhlMillProd..relationships r1 on r1.table_code = relisa
join	MuhlMillProd..relationships r2 on r2.table_code = relwhose
group	by r1.table_code, r1.table_val, r2.table_val, r2.table_code
order by 1 desc;

