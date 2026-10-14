
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
select	x.xid as plg_xid,x.giftkey as plg_giftkey, x.giftallkey as plg_giftallkey, x.gifttype as plg_gifttype,
		x.giftmtchky as plg_giftmtchky, x.giftcrdkey as plg_giftcrdkey, x.giftjntkey as plg_giftjntkey,
		sum(x.giftamount) as plg_balance, sum(x.giftamtplg) as plg_amount,
		isnull((select sum(case when gifttype = 'w' then abs(giftjntamt) else giftamount end) from MuhlMillProd..gifts where giftplgkey = x.giftkey
					and gifttype not like '%v' and gifttype not like '%j'), 0) as plg_payments
into	mu_pledge_list
from (	select	giftallkey as xid,
				giftkey, giftallkey, giftplgkey, giftmtchky, giftcrdkey,giftjntkey,
				giftamount, giftamtplg, gifttype
		from	MuhlMillProd..gifts g
		where	exists (select 1 from muhlmillprod..gifts x where x.giftplgkey=g.giftkey)
		and		g.gifttype in ('p','e','mp')
		and		giftjntkey in (1,0)
		union
		select	o.giftallkey as xid, 
				g.giftkey, g.giftallkey, g.giftplgkey, g.giftmtchky, g.giftcrdkey,g.giftjntkey,
				g.giftamount, g.giftamtplg, g.gifttype
		from	MuhlMillProd..gifts g
		join	MuhlMillProd..gifts o on g.giftjntkey=o.giftkey
		where	exists (select 1 from muhlmillprod..gifts x where x.giftplgkey=g.giftkey)
		and		g.gifttype in ('p','e','mp')
		and		g.giftjntkey >5000
	 )x
group by x.xid,x.giftkey,x.giftallkey,x.giftmtchky,x.giftcrdkey,x.giftjntkey,x.gifttype;

-->> samples
select	* from mu_pledge_list where plg_xid=365823;
select * from mu_pledge_list where plg_giftjntkey<5000;

--================================================================================================
-- PART TWO: build GiftCommitment load table
--================================================================================================
drop table if exists GiftCommitment_load;
select	ASLE_External_ID__c				= convert(varchar(30), p.plg_xid)
		,gifttype						= trim(g.gifttype)
		,giftid							= g.giftid
		,Name							= concat(ac.name, ' - ', CONVERT(VARCHAR(10), g.gifteffdat, 101), case when g.gifttype = 'mp' then ' - Match Pledge' when g.gifttype = 'e' then ' - Expectancy' else ' - Pledge' end)
		,DonorId						= ac.Id
		,Contact						= ac.PersonContactId
		,ExpectedTotalCmtAmount			= p.plg_amount
		,EffectiveStartDate				= coalesce(y.start_date, gifteffdat)
		,ExpectedEndDate				= coalesce(y.end_date, gifteffdat)
		,ScheduleType					= 'Custom'
		,Status							= case when plg_balance = 0 then 'Closed'
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
from (	select	plg_xid, sum(plg_balance) as plg_balance, sum(plg_payments) as plg_payments, sum(plg_amount) as plg_amount
		from	mu_pledge_list group by plg_xid) p
left	join (select paylinkkey, min(payduedate) as start_date, max(payduedate) as end_date 
			  from MuhlMillProd..payments group by paylinkkey) y on p.plg_xid=y.paylinkkey
join	MuhlMillProd..gifts g on p.plg_xid=g.giftallkey and p.plg_xid=giftkey
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
-----------------------------------------------------
-->> create localized payments table
-->> that references the original pledge record
-----------------------------------------------------
drop table if exists mu_payment_list;
select	p.plg_xid, giftallkey as pmt_xid, 
		giftkey as pmt_giftkey, giftallkey as pmt_giftallkey, 
		giftplgkey as pmt_giftplgkey, giftjntkey as pmt_giftjntkey,
		giftmtchky as pmt_giftmtchky, giftcrdkey as pmt_giftcrdkey, 
		giftsumkey as pmt_giftsumkey, giftlnkkey as pmt_giftlnkkey,
		gifthnrkey as pmt_gifthrnkey, gifthnrmkr as pmt_gifthnrmkr,
		giftamount as pmt_giftamount, abs(giftjntamt) as pmt_giftjntamt, 
		gifttotal as pmt_gifttotal, gifttpledg as pmt_gifttpledg,
		giftid as pmt_giftid, giftprocdt as pmt_giftprocdt,
		gifteffdat as pmt_gifteffdat, gifttender as pmt_gifttender,
		gifttype as pmt_gifttype, giftcamp as pmt_giftcamp, giftrest as pmt_giftrest
into	mu_payment_list
from	MuhlMillProd..gifts g
join	mu_pledge_list p on p.plg_giftkey=g.giftplgkey
where	g.giftplgkey>5000
and		g.gifttype in ('y','b','w')
and		giftjntkey in (1,0)
union
select	p.plg_xid, o.giftallkey as pmt_xid, 
		g.giftkey, g.giftallkey, g.giftplgkey, g.giftjntkey,
		g.giftmtchky, g.giftcrdkey, g.giftsumkey, g.giftlnkkey,g.gifthnrkey, g.gifthnrmkr,
		g.giftamount, abs(g.giftjntamt), g.gifttotal, g.gifttpledg,
		g.giftid, g.giftprocdt,g.gifteffdat, g.gifttender,
		g.gifttype, g.giftcamp,g.giftrest
from	MuhlMillProd..gifts g
join	MuhlMillProd..gifts o on g.giftjntkey=o.giftkey
join	mu_pledge_list p on p.plg_giftkey=g.giftplgkey
where	g.giftplgkey>5000
and		g.gifttype in ('y','b','w')
and		g.giftjntkey >5000;


