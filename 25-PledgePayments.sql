
/***************************************************************************************
        PURPOSE:    Populate the pledge payment transactions
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
		GiftSoftCredit

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version
/*
	pull back gift transactions after loading:
	select Id, ASLE_External_ID__c, Name, DonorId, GiftCommitmentId, GiftCommitmentScheduleId, 
	TransactionDate, OriginalAmount, CurrentAmount, GiftType, Status, PaymentMethod 
	from GiftTransaction
*/
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: load payment transactions on closed pledges
--================================================================================================
-----------------------------------------------------
-->> load payments to gift transaction
-->> again, link directly to pledge, bypass schedule
-----------------------------------------------------
drop table if exists GiftTransaction_pmt_load;
select	ASLE_External_ID__c				= cast(pmt_xid as varchar(10))
		,GiftCommitmentId				= c.Id
		,DonorId						= a.Id
		,OutreachSourceCodeId			= s.Id
		,CampaignId						= case when s.Id is null and g.Id is null then d.Id
											   when s.Id is null then g.Id 
											   else null end
		, Name							= c.name +  + ' Payment'
		, GiftType						= case when a.PersonContactId is null then 'Organizational' else 'Individual' end
		, OriginalAmount				= pmt_amount
		, Status						= case when pmt_gifttype='w' then 'Written-Off' else 'Unpaid' end
		, TransactionDate				= pmt_gifteffdat
		, TransactionDueDate			= pmt_gifteffdat
		, ASLE_Anonymous__c				= case when giftanon='N' then 0 else 1 end
		, ASLE_Batch__c					= trim(giftbatch)
		, PaymentMethod					= case when tenderdesc='' then 'Check' else tenderdesc end
		, ASLE_Gift_Received_Date__c	= pmt_createdate
		, CreatedDate					= pmt_createdate
		, LastModifiedDate				= pmt_modifydate

		--> custom fields
		, ASLE_TransactionClass1__c		= transclass1
		, ASLE_TransactionClass2__c		= transclass2
		, ASLE_Check_Number__c			= checkno
		, ASLE_Source__c				= gift_src
		, ASLE_Processed_Date__c		= pmt_giftprocdt
		, ASLE_Comments__c				= comment
into	GiftTransaction_pmt_load
from (	select	plg_xid, pmt_xid, trim(t.table_val) as tenderdesc, pmt_gifttype, 
				g.giftcamp, g.giftsolic, g.giftanon, trim(g.giftbatch) giftbatch, trim(tc1.table_val) as transclass1,
				trim(tc2.table_val) as transclass2, trim(src.table_val) as gift_src, trim(g.giftchckno) as checkno,
				trim(g.giftcomm) as comment,
				sum(pmt_giftamount+pmt_giftwriteoff) as pmt_amount,
				min(case when pmt_giftjntkey in (1,0) then pmt_giftid else 'z' end) as pmt_giftid,
				max(pmt_giftprocdt) as pmt_giftprocdt,
				max(pmt_gifteffdat) as pmt_gifteffdat,
				max(pmt_giftcreatedate) as pmt_createdate,
				max(pmt_giftmodifydate) as pmt_modifydate
		from	mu_payment_list y
		left join muhlmillprod..tender t on y.pmt_gifttender=t.table_code
		left join muhlmillprod..gifts g on y.pmt_xid=g.giftkey
		left	join MuhlMillProd..transaction_class tc1 on tc1.table_code = g.giftclass1
		left	join MuhlMillProd..transaction_class2 tc2 on tc2.table_code = g.giftclass2
		left	join MuhlMillProd..source_types src on src.table_code = g.giftsource
		where	exists (select 1 from mu_pledge_list p where y.plg_xid=p.plg_xid group by plg_xid having sum(plg_balance)=0)
		group by plg_xid, pmt_xid,pmt_gifttype,trim(t.table_val),g.giftcamp,g.giftsolic, 
				g.giftanon,trim(g.giftbatch),trim(tc1.table_val),trim(tc2.table_val),trim(src.table_val),trim(g.giftchckno),trim(g.giftcomm)
	 )y
join	sf_giftcommitments c on y.plg_xid=c.ASLE_External_ID_c
join	sf_accounts a on y.pmt_giftid=a.ASLE_External_ID_c
left	join sf_solicitations s on y.giftsolic=s.ASLE_External_ID_c COLLATE Latin1_General_BIN
left	join sf_campaigns g on y.giftcamp =g.ASLE_External_ID_c COLLATE Latin1_General_BIN 
left	join sf_campaigns d on 'default' =d.ASLE_External_ID_c COLLATE Latin1_General_BIN ;

-->> check for dupes
select	count(*), ASLE_External_ID__c
from	GiftTransaction_pmt_load
group by ASLE_External_ID__c
having count(*)>1;

-->> mismatched dates?
update	GiftTransaction_pmt_load
set		CreatedDate=LastModifiedDate, LastModifiedDate=CreatedDate
where	CreatedDate>LastModifiedDate;

-->> get records for loading
select	* from GiftTransaction_pmt_load;

--================================================================================================
-- PART TWO: load payment transaction designations on closed pledges
-- get fresh extract of gift transactions first
--================================================================================================

drop table if exists GiftTransactionDesignation_pmt_load;
select	ASLE_External_ID__c				= convert(varchar(30),g.pmt_xid)+'-'+case when trim(g.pmt_giftrest) ='' then 'default' else trim(g.pmt_giftrest) end
		, Amount						= sum(g.pmt_giftamount+pmt_giftwriteoff)
		, [Percent]						= (sum(g.pmt_giftamount+pmt_giftwriteoff)/t.OriginalAmount)*100
		, GiftDesignationId				= d.Id
		, GiftTransactionId				= t.Id
		, CreatedDate					= max(cast(g.pmt_giftcreatedate as date))
		, LastModifiedDate				= max(cast(g.pmt_giftmodifydate as date))
into	GiftTransactionDesignation_pmt_load
from	mu_payment_list g
join	sf_gifttransactions t on g.pmt_xid=t.ASLE_External_ID_c COLLATE Latin1_General_BIN 
join	sf_designations d on case when trim(g.pmt_giftrest)='' then 'default' else trim(g.pmt_giftrest) end =d.ASLE_External_ID_c COLLATE Latin1_General_BIN 
where	t.OriginalAmount<>0
group by g.pmt_xid,g.pmt_giftrest,d.id,t.id,t.OriginalAmount
order by 1;

update GiftTransactionDesignation_pmt_load
set	[Percent]=100.00 
where	[Percent]>100;

update GiftTransactionDesignation_pmt_load
set CreatedDate=LastModifiedDate, LastModifiedDate=CreatedDate 
where CreatedDate>LastModifiedDate;

-->> check for dupes (none)
select	count(*), ASLE_External_ID__c 
from	GiftTransactionDesignation_pmt_load
group by ASLE_External_ID__c
having count(*)>1;

-->> get records for loading
select * from GiftTransactionDesignation_pmt_load;

--================================================================================================
-- PART THREE: distribute the credit at 100%
--================================================================================================
drop table if exists GiftSoftCredit_pmt_load;
select	ASLE_External_ID__c			= cast(g.pmt_xid as varchar(50))
		, GiftTransactionId			= t.Id
		, Role						= 'Soft Credit'
		, RecipientId				= a.Id
		, SoftCreditAmount			= t.OriginalAmount
into	GiftSoftCredit_pmt_load
from	(select distinct pmt_xid,pmt_giftid from mu_payment_list where pmt_giftjntkey>5000) g 
join	sf_gifttransactions t on g.pmt_xid=t.ASLE_External_ID_c
join	sf_accounts a on g.pmt_giftid=a.ASLE_External_ID_c
where	t.Donorid<>a.Id;

-->> check for dupes
select	count(*), ASLE_External_ID__c
from	GiftSoftCredit_pmt_load
group by ASLE_External_ID__c
having count(*)>1;

-->> get values
select	* from GiftSoftCredit_pmt_load;