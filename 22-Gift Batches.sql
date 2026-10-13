
/***************************************************************************************
        PURPOSE:    Populate the historical gift batches
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        GiftBatch

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: populate gift batches
--================================================================================================

drop table if exists GiftBatch_load;
select	ASLE_External_ID__c		= trim(table_user)+'-'+trim(table_val)
		,Description			= trim(table_comm)
		,OwnerId				= u.Id
		,TotalBatchAmount		= sum(table_amt2)
		,LastProcessedDateTime	= max(table_date)
		,CreatedDate			= max(table_date)
		,LastModifiedDate		= max(table_date)
into	GiftBatch_load
from	MuhlMillProd..gift_batch_number b
left	join sf_users u on b.table_user=u.ASLE_ExternalUsername_c COLLATE Latin1_General_BIN
group by trim(table_user)+'-'+trim(table_val),trim(table_comm), u.Id;

-->> check for dupes
select  count(*),ASLE_External_ID__c
from    GiftBatch_load
group by ASLE_External_ID__c
having count(*)>1;

-->> comments will fit? YES
select max(len(Description)) from GiftBatch_load;

-->> get results for loading
select * from    GiftBatch_load;