
/***************************************************************************************
        PURPOSE:    Populate the pledge commitments and schedules
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        GiftCommitment
		GiftCommitmentSchedule

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version
                    (thanks to joint gifts, code is an overhaul of standard MILL scripting)
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: stage pledge tables/validate/reconcile
--================================================================================================
--------------------------------------------------------------
-->> build pledge list with all the xids associated
--------------------------------------------------------------
drop table if exists mu_pledge_list;
select	x.xid,x.giftkey,x.giftallkey,x.giftmtchky,x.giftcrdkey,x.giftjntkey,
		sum(x.giftamount) as balance, sum(x.giftamtplg) as pledge_amount,
		isnull((select sum(case when gifttype = 'w' then abs(giftjntamt) else giftamount end) from MuhlMillProd..gifts where giftplgkey = x.giftkey
					and gifttype not like '%v' and gifttype not like '%j'), 0) as payments
into	mu_pledge_list
from (	select	giftallkey as xid,
				giftkey, giftallkey, giftplgkey, giftmtchky, giftcrdkey,giftjntkey,
				giftamount, giftamtplg
		from	MuhlMillProd..gifts g
		where	gifttype in ('p','e','mp')
		and		giftjntkey in (1,0)
		union
		select	o.giftallkey as xid, 
				g.giftkey, g.giftallkey, g.giftplgkey, g.giftmtchky, g.giftcrdkey,g.giftjntkey,
				g.giftamount, g.giftamtplg
		from	MuhlMillProd..gifts g
		join	MuhlMillProd..gifts o on g.giftjntkey=o.giftkey
		where	g.gifttype in ('p','e','mp')
		and		g.giftjntkey >5000
	 )x
group by x.xid,x.giftkey,x.giftallkey,x.giftmtchky,x.giftcrdkey,x.giftjntkey;

-->> samples
select	* from mu_pledge_list where xid=365823;
select * from mu_pledge_list where giftjntkey<5000;

--================================================================================================
-- PART TWO: build GiftCommitment load table
--================================================================================================
drop table if exists GiftCommitment_load;
select	ASLE_External_ID__c				= convert(varchar(30), p.xid)
		,gifttype						= trim(g.gifttype)
		,giftid							= g.giftid
		,Name							= concat(ac.name, ' - ', CONVERT(VARCHAR(10), g.gifteffdat, 101), case when g.gifttype = 'p' then ' - Pledge' when g.gifttype = 'e' then ' - Expectancy' else ' - Match Pledge' end)
		,DonorId						= ac.Id
		,Contact						= ac.PersonContactId
		,ExpectedTotalCmtAmount			= p.pledge_amount
		,EffectiveStartDate				= coalesce(y.start_date, gifteffdat)
		,ExpectedEndDate				= coalesce(y.end_date, gifteffdat)
		,ScheduleType					= 'Custom'
		,Status							= case when pledge_balance = 0 then 'Closed'
										  else 'Active' end
		,CampaignId						= cg.Id
		,FulfillmentType				= case when g.giftrevoke = 'Y' then 'Conditional' else 'Unconditional' end
		,CreatedDate					= g.giftcrdate
		,LastModifiedDate				= g.giftdate		
		,GiftVehicle					= trim(gt.table_val)

		-- custom fields
		,ASLE_Processed_Date__c			= g.giftprocdt
		,ASLE_Effective_Date__c			= g.gifteffdat
		,ASLE_Comments__c				= trim(isnull(g.giftcomm, ''))
into	GiftCommitment_load
from (	select	xid, sum(balance) as pledge_balance, sum(payments) as pledge_payments, sum(pledge_amount) as pledge_amount
		from	mu_pledge_list group by xid) p
left	join (select paylinkkey, min(payduedate) as start_date, max(payduedate) as end_date 
			  from MuhlMillProd..payments group by paylinkkey) y on p.xid=y.paylinkkey
join	MuhlMillProd..gifts g on p.xid=g.giftallkey and p.xid=giftkey
join	sf_accounts ac on g.giftid=ac.ASLE_External_ID_c
left	join MuhlMillProd..tender gt on gt.table_code = g.gifttender
left	join sf_campaigns cg on cg.ASLE_External_ID_c = case when g.giftcamp = '' then 'default' else trim(g.giftcamp) end collate Latin1_General_BIN ;

-->> check for dupes
select	count(*),ASLE_External_ID__c
from	GiftCommitment_load
group by ASLE_External_ID__c 
having count(*)>1;

select * from GiftCommitment_load where ASLE_External_ID__c=365823;

-->> get records for loading
select	* from GiftCommitment_load;

--================================================================================================
-- PART THREE: build Gift Schedules
--================================================================================================