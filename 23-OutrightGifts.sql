
/***************************************************************************************
        PURPOSE:    Populate the outright gifts
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        GiftTransaction
		GiftTransactionDesignation

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: localize outright gifts
--================================================================================================

-->> create localized outright gifts table
drop table if exists mu_outrightgifts;
select	giftallkey as xid, 
		giftkey, giftallkey, giftplgkey, giftjntkey,
		giftmtchky, giftcrdkey, giftsumkey, giftlnkkey,
		gifthnrkey, gifthnrmkr,
		giftamount, giftjntamt, gifttotal, gifttpledg,
		giftid, giftprocdt,gifttender,giftcamp,giftrest
into	mu_outrightgifts
from	MuhlMillProd..gifts g
where	not exists (select 1 from MuhlMillProd..gifts x where x.gifthnrkey=g.giftkey and x.giftplgkey>5000)
and		gifttype='g'
and		giftjntkey in (1,0)
union
select	o.giftallkey as xid, 
		g.giftkey, g.giftallkey, g.giftplgkey, g.giftjntkey,
		g.giftmtchky, g.giftcrdkey, g.giftsumkey, g.giftlnkkey,
		g.gifthnrkey, g.gifthnrmkr,
		g.giftamount, g.giftjntamt, g.gifttotal, g.gifttpledg,
		g.giftid, g.giftprocdt,g.gifttender,g.giftcamp,g.giftrest
from	MuhlMillProd..gifts g
join	MuhlMillProd..gifts o on g.giftjntkey=o.giftkey
where	not exists (select 1 from MuhlMillProd..gifts x where x.gifthnrkey=g.giftkey and x.giftplgkey>5000)
and		g.gifttype='g'
and		g.giftjntkey >5000;

select	* from mu_outrightgifts where xid=549599;

-----------------------------------------------------------------------
-- get some stats/do some reconciliation
-----------------------------------------------------------------------
select	count(*) from mu_outrightgifts;
select	count(*) from mu_outrightgifts where xid=giftkey and giftkey=giftallkey;

-->> these two should equal but they don't
--select	sum(gifttotal) from mu_outrightgifts where xid=giftkey and giftkey=giftallkey; not reliable as a total comparison
select	sum(giftamount) from mu_outrightgifts ;

-->> investigating outright gift totals...
select	sum(g.giftamount) as giftamt, g.xid, gt.gifttotal, gt.gifttotal-sum(g.giftamount) as diff
from	mu_outrightgifts g
left	join (select distinct xid, gifttotal from mu_outrightgifts) gt on gt.xid=g.xid
group by g.xid, gt.gifttotal
order by diff desc
-----------------------------------------------------------------------
-- get some stats/do some reconciliation
-----------------------------------------------------------------------

--================================================================================================
-- PART TWO: populate the Transaction records
--================================================================================================
drop table if exists GiftTransaction_og_load;
select	ASLE_External_ID__c				= convert(varchar(30),g.xid)
		, Name							= a.name + ' ' +format(ga.gifteffdat,'MM/dd/yy') + ' Outright Gift'
		, DonorId						= a.Id
		, CampaignId					= case when s.id is null then c.Id else s.campaignid end 
		, GiftType						= case when a.PersonContactId is null then 'Organizational' else 'Individual' end
		, OriginalAmount				= sum(g.giftamount)
		, Status						= 'Unpaid'
		, TransactionDate				= ga.gifteffdat
		, OutreachSourceCodeId			= s.Id
		, ASLE_Anonymous__c				= case when ga.giftanon='N' then 0 else 1 end
		, ASLE_Batch__c					= trim(ga.giftbatch)
		, PaymentMethod					= case when trim(gt.table_val)='' or gt.table_val is null then 'Check' else trim(gt.table_val) end
		, ASLE_Gift_Received_Date__c	= ga.giftcrdate
		, CreatedDate					= ga.giftcrdate
		, LastModifiedDate				= ga.giftdate

		--> custom fields
		, ASLE_TransactionClass1__c	= trim(tc1.table_val)
		, ASLE_TransactionClass2__c	= trim(tc2.table_val)
		, ASLE_Check_Number__c			= trim(ga.giftchckno)
		, ASLE_Source__c				= trim(src.table_val)
		, ASLE_Processed_Date__c		= g.giftprocdt
		, ASLE_Comments__c				= trim(ga.giftcomm)
into	GiftTransaction_og_load
from	mu_outrightgifts g
join	(select xid, giftid from mu_outrightgifts where giftjntkey in (1,0)) d on g.xid=d.xid
join	sf_accounts a on d.giftid=a.ASLE_External_ID_c
join	(select * from muhlmillprod..gifts where giftkey=giftallkey)ga on g.xid=ga.giftallkey
left	join MuhlMillProd..tender gt on gt.table_code = g.gifttender
left	join sf_solicitations s on ga.giftsolic=s.asle_external_id_c COLLATE Latin1_General_BIN 
left	join sf_campaigns c on ga.giftcamp=c.asle_external_id_c COLLATE Latin1_General_BIN 
left	join MuhlMillProd..transaction_class tc1 on tc1.table_code = ga.giftclass1
left	join MuhlMillProd..transaction_class2 tc2 on tc2.table_code = ga.giftclass2
left	join MuhlMillProd..source_types src on src.table_code = ga.giftsource
group by g.xid, a.name, a.id, s.id, c.id, s.campaignid, a.PersonContactId, ga.gifteffdat,
		ga.giftbatch, gt.table_val, ga.giftcrdate, ga.giftdate,trim(tc1.table_val),trim(tc2.table_val),
		trim(ga.giftchckno),g.giftprocdt,trim(src.table_val),trim(ga.giftcomm),ga.giftanon;


-->> look for dupes
select	count(*), asle_external_ID__c 
from	GiftTransaction_og_load
group by ASLE_External_ID__c
having count(*)>1;

--> due diligence
select * from GiftTransaction_og_load where ASLE_External_ID__c='599659'
select * from mu_outrightgifts where xid=599659
select max(len(asle_comment__c)) from GiftTransaction_og_load;
select distinct asle_source__c from GiftTransaction_og_load;
select distinct ASLE_TransactionClass2__c from GiftTransaction_og_load;

-->> get records for loading
select	* from GiftTransaction_og_load;

-->> pull back all transactions and append to sf_gifttransactions;

--================================================================================================
-- PART THREE: populate the Transaction Designation records
--================================================================================================

drop table if exists GiftTransactionDesignation_og_load;
select	ASLE_External_ID__c				= convert(varchar(30),g.xid)+'-'+case when trim(g.giftrest) ='' then 'default' else trim(g.giftrest) end
		, Amount						= sum(g.giftamount)
		, [Percent]						= (sum(g.giftamount)/t.OriginalAmount)*100
		, GiftDesignationId				= d.Id
		, GiftTransactionId				= t.Id
		, CreatedDate					= cast(t.createddate as date)
		, LastModifiedDate				= cast(t.LastModifiedDate as date)
into	GiftTransactionDesignation_og_load
from	mu_outrightgifts g
join	sf_gifttransactions t on g.xid=t.ASLE_External_ID_c COLLATE Latin1_General_BIN 
join	sf_designations d on case when trim(g.giftrest)='' then 'default' else trim(g.giftrest) end =d.ASLE_External_ID_c COLLATE Latin1_General_BIN 
where	t.OriginalAmount<>0
group by g.xid,g.giftrest,d.id,t.id,t.createddate,t.lastmodifieddate,t.OriginalAmount
order by 1;

select	*
from	GiftTransactionDesignation_og_load
where	[Percent]<1;

-->> check for dupes (none)
select	count(*), ASLE_External_ID__c 
from	GiftTransactionDesignation_og_load
group by ASLE_External_ID__c
having count(*)>1;

-->> get records for loading
select * from GiftTransactionDesignation_og_load;

--================================================================================================
-- PART FOUR: distribute the credit at 100%
--================================================================================================
drop table if exists GiftSoftCredit_og_load;
select	ASLE_External_ID__c			= cast(g.xid as varchar(50))
		, GiftTransactionId			= t.Id
		, Role						= 'Soft Credit'
		, RecipientId				= a.Id
		, SoftCreditAmount			= t.OriginalAmount
into	GiftSoftCredit_og_load
from	(select distinct xid,giftid from mu_outrightgifts where giftjntkey>5000) g 
join	sf_gifttransactions t on g.xid=t.ASLE_External_ID_c
join	sf_accounts a on g.giftid=a.ASLE_External_ID_c
where	t.Donorid<>a.Id;

-->> check for dupes
select	count(*), ASLE_External_ID__c
from	GiftSoftCredit_og_load
group by ASLE_External_ID__c
having count(*)>1;

-->> get values
select	* from GiftSoftCredit_og_load;





