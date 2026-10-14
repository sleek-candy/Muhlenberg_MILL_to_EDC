

/***************************************************************************************
        PURPOSE:    Populate the gift designation related accounts/recipients
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        ASLE_Gift_Designation_Accounts__c

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: create or match the scholarship accounts to designations
--================================================================================================

SELECT t.coreid AS acct_xid
     , n.namefirst
     , n.namelast
FROM   dbo.pa_constit t
left JOIN   sf_accounts a
  ON   a.ASLE_External_ID_c = t.coreid
left join MuhlMillProd.dbo.name n
  ON  n.nameid = t.coreid
  and n.nametype = 'a'
WHERE a.Id is null