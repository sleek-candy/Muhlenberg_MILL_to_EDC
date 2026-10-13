
/***************************************************************************************
        PURPOSE:    Populate the commitments and schedules
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

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: stage pledge tables/validate/reconcile
--================================================================================================
-------------------------------------------------
-- All pledges on primary side - all allocations
-- CH: build staging table pledge_links
-------------------------------------------------
drop table if exists mu_pledge_links;
select		g.giftkey as pkey, s.giftkey as lnkkey, s.giftrest as desg, g.giftkey as orig_allkey, 'pe' as gtype
into		mu_pledge_links
from		MuhlMillProd..gifts g
join		MuhlMillProd..gifts s on s.giftallkey = g.giftkey and rtrim(s.gifttype) in ('p', 'e', 'mp')
where		rtrim(g.gifttype) in ('p', 'e', 'mp') and g.giftallkey = g.giftkey ;

create index idx_plinks on mu_pledge_links(pkey);

-- ********************************************************************************************************************************
-- Get the totals for each pledge
-- ********************************************************************************************************************************
drop table if exists mu_pledge_work;
with all_pledges as
(
	select		pkey as primary_key,
				a.giftamount, a.giftamtplg,
				isnull((select sum(case when gifttype = 'w' then abs(giftjntamt) else giftamount end) from MuhlMillProd..gifts where giftplgkey = lnkkey
					and gifttype not like '%v' and gifttype not like '%j'
					), 0) as payments
	from		MuhlMillProd..gifts p
	join		mu_pledge_links on pkey = giftkey
	join		MuhlMillProd..gifts a on a.giftkey = lnkkey
)
select		primary_key, sum(giftamount) as balance, sum(payments) as payments, sum(giftamtplg) as pledge_amount, 'pe' as gtype
into		mu_pledge_work
from		all_pledges
group		by primary_key;

create index idx_pledge_work on mu_pledge_work(primary_key);

-- one of these found in first run
update mu_pledge_work set balance = pledge_amount where balance > pledge_amount ;

-- ********************************************************************************************************************************
-- Get all allocations and distribution of each pledge
-- ********************************************************************************************************************************
drop table if exists mu_pledge_allocs;
select	primary_key as pkey, g.giftkey as desg_key, g.gifttype as ttype,
		giftamount as balance,
		isnull((select sum(case when gifttype = 'w' then abs(giftjntamt) else giftamount end) from MuhlMillProd..gifts where giftplgkey = g.giftkey
			and gifttype not like '%v' and gifttype not like '%j'), 0) as payments,
		convert(numeric(10, 5), 1.111) as pcent, giftamtplg,
		'pe' as gtype
into	mu_pledge_allocs
from	mu_pledge_work
join	MuhlMillProd..gifts g on giftallkey = primary_key and g.gifttype in ('p', 'e', 'mp');

--------------------------------------
-- Calculate percentage for each alloc
--------------------------------------

update mu_pledge_allocs set pcent = giftamtplg / (select pledge_amount from mu_Pledge_Work where pkey = primary_key)
where (select pledge_amount from mu_Pledge_Work where pkey = primary_key) > 0;

update mu_pledge_allocs set pcent = 1 where (select giftamtplg from mu_Pledge_Work where pkey = primary_key) < 0;

create index idx_pledge_allocs on mu_Pledge_Allocs(pkey);
create index idx_pledge_allocs2 on mu_Pledge_Allocs(desg_key);

--ASK RICK--
	-->> Should be none of these now	
	-->> what to do with these??
	select * from mu_Pledge_Allocs order by pcent desc;
--ASK RICK--

-- ********************************************************************************************************************************
-- Figure out pledge payment schedules first
-- ********************************************************************************************************************************
drop table if exists mu_pledge_schedule;
select	pkey, payduedate, sum(paydueamt) as dueamt, sum(paybalamt) as balamt, 'pe' as gtype
into	mu_pledge_schedule
from	mu_pledge_links 
join	MuhlMillProd..payments on paylinkfil ='05' and paylinkkey = lnkkey
group	by pkey, payduedate;

create index idx_sched on mu_pledge_schedule(pkey);

-----------------------------------------------------------------------------------
-- Add entries where there is no payment schedule (137 records first run)
-----------------------------------------------------------------------------------
insert	into mu_pledge_schedule
select	primary_key, giftprocdt, balance + payments, balance + payments, 'pe' as gtype
from	mu_Pledge_Work 
join	MuhlMillProd..gifts on giftkey = primary_key
where	not exists (select 1 from mu_Pledge_Schedule where pkey = primary_key);

-----------------------------------------------------------------------------------
-- update entries that are missing a payduedate
-----------------------------------------------------------------------------------
update	m
set		m.payduedate=g.giftprocdt
from	mu_pledge_schedule m
join	muhlmillprod..gifts g on m.pkey=g.giftkey 
where	m.payduedate is null;

-----------------------------------------------------------------------------------
-- Calculate the amount due each payment for each designation
-- Get rid of those with 0 due first + those where a single designation is 100%
-----------------------------------------------------------------------------------
drop table if exists mu_pledge_schedule_allocs;
select	a.pkey, a.desg_key, s.payduedate, s.dueamt, s.balamt, 'pe' as gtype
into	mu_pledge_schedule_allocs
from	mu_Pledge_Schedule s
join	mu_Pledge_Allocs a on s.pkey = a.pkey 
where	pcent = 1 or dueamt = 0 ;

update mu_pledge_schedule_allocs set balamt = 0;

create index idx_paysched_allocs on mu_pledge_schedule_allocs(pkey);
create index idx_paysched_allocs2 on mu_pledge_schedule_allocs(desg_key);

-- Multi-designation, 1 scheduled payment
insert	into mu_pledge_schedule_allocs 
select	primary_key, a.desg_key, s.payduedate, a.giftamtplg as dueamt, 0 as balamt, 'pe' as gtype
from	mu_Pledge_Work
join	mu_Pledge_Schedule s on s.pkey = primary_key
join	mu_Pledge_Allocs a on a.pkey = primary_key
where	primary_key not in (select pkey from mu_Pledge_Schedule_Allocs)
		and (select count(*) from mu_Pledge_Schedule where pkey = primary_key) = 1;

-- Only left with multi-designation with odd designation splits or multiple payments
drop table if exists #complicated_schedules;
select	primary_key, (select count(*) from mu_Pledge_Allocs where pkey = primary_key) as desg_count,
		(select count(*) from mu_Pledge_Schedule where pkey = primary_key) as sched_count
into	#complicated_schedules
from	mu_Pledge_Work 
where	primary_key not in (select pkey from mu_Pledge_Schedule_Allocs) ;

-- ASK RICK --
	-- (2) schedules to manually set up first run 
	select * from #complicated_schedules
-- ASK RICK --

-- ********************************************************************************************************************************
-- Create base table to be used for generating the pledge records
-- ********************************************************************************************************************************
drop table if exists  mu_pledge_base;	
select	pkey, desg_key, payduedate, dueamt, balamt,
		row_number() over (partition by pkey, desg_key order by payduedate) as p_order,
		'pe' as gtype
into	 mu_pledge_base
from	mu_Pledge_Schedule_Allocs

create index idx_pbase on  mu_pledge_base(pkey, desg_key);

-- For any schedules that did not work out
-- Adjust the last scheduled payment for each designation to be the correct amount
with bad_schedules as
(
	select	p.pkey as primary_key, 
			p.giftamtplg,
			p.desg_key as designation_key,
			(select sum(dueamt) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key) as scheduled_amount_tot,
			isnull((select sum(dueamt) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key
				and p_order <> (select max(p_order) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key)), 0) as schedule_to_last,
			(select max(p_order) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key) as last_due
	from	mu_Pledge_Allocs p 
	where	p.giftamtplg <> (select sum (dueamt) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key)
)
update	 mu_pledge_base
set		dueamt = (select giftamtplg - schedule_to_last from bad_schedules where pkey = primary_key and desg_key = designation_key and p_order = last_due)
where	exists (select 1 from bad_schedules where pkey = primary_key and desg_key = designation_key and p_order = last_due and giftamtplg > schedule_to_last);

-- Where there is only one payment, make the scheduled amount = payment amount
update	 mu_pledge_base
set		dueamt = (select pledge_amount from mu_Pledge_Work where pkey = primary_key and pledge_amount > dueamt)
where	pkey in (select	p.primary_key from mu_Pledge_Work p 
				 where	pledge_amount <> (select sum(dueamt) from  mu_pledge_base where pkey = p.primary_key)
						and (select count(*) from  mu_pledge_base where pkey = p.primary_key) = 1);

-- All records set correctly first run
select	p.pkey as primary_key, 
		p.giftamtplg,
		p.desg_key as designation_key,
		(select sum(dueamt) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key) as scheduled_amount_tot,
		isnull((select sum(dueamt) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key
			and p_order <> (select max(p_order) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key)), 0) as schedule_to_last,
		(select max(p_order) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key) as last_due
from	mu_Pledge_Allocs p 
where	p.giftamtplg <> (select sum (dueamt) from  mu_pledge_base where pkey = p.pkey and desg_key = p.desg_key);

------------------------------------------------------------------------------------------------------------------------------
-- Figure out balances
------------------------------------------------------------------------------------------------------------------------------
alter table mu_Pledge_Base add running_due_sum money;

update	a
set		a.running_due_sum = a.dueamt + isnull((select sum(dueamt) from mu_Pledge_Base where pkey = a.pkey and desg_key = a.desg_key and p_order < a.p_order), 0)
from	mu_Pledge_Base a ;

alter table mu_Pledge_Base add paid_amount money;

update  mu_Pledge_Base set paid_amount = (select sum(giftamtplg - giftamount) from MuhlMillProd..gifts where giftkey = desg_key);

update	mu_Pledge_Base set balamt = case when paid_amount >= running_due_sum then 0
									  when running_due_sum - paid_amount >= dueamt then dueamt
		                         else running_due_sum - paid_amount end;

alter table mu_Pledge_Base add billing varchar(1);

update  a
set		a.billing = 'Y' 
from	mu_Pledge_Base a
where	exists (select 1 from MuhlMillProd..payments where paylinkkey = pkey and payduedate = a.payduedate and paybilling = 'Y' and paylinkfil = '05');
update	mu_Pledge_Base set billing = 'N' where billing is null;

-- Fix any pledges with odd amounts
update mu_Pledge_Base set paid_amount = 0 where paid_amount < 0;

	---------------------------------------------------------------------------------------------------
	-- Identify any pledges with a giftamtplg + payments does not equal the balance from gifts
	-- giftnum 31352
	---------------------------------------------------------------------------------------------------
	with test as (
		select desg_key, sum(balamt) as amount from mu_Pledge_Base 
		where exists (select 1 from MuhlMillProd..gifts where giftkey = desg_key and gifttype in ('p', 'e', 'mp'))
		group by desg_key
	),
	gifts as (
		select	test.*, (select sum(giftamtplg) from MuhlMillProd..gifts where giftkey = desg_key) -
				(select sum(giftamtplg - giftamount) from MuhlMillProd..gifts where giftkey = desg_key) as mbal
		from	test
	)
	select	a.*, giftid, gifttrnum, gifteffdat from gifts a
	join	MuhlMillProd..gifts on giftkey = desg_key where amount <> mbal ;

---------------------------------------------------------------------------------------------------
-- Need to apply payments and establish remaining pledge schedules
---------------------------------------------------------------------------------------------------
drop table if exists mu_pledge_installment_payments;
create table mu_pledge_installment_payments (
	pkey numeric(13, 0),
	desg_key numeric(13, 0),
	installment_number numeric(13, 0),
	due_date date, 
	desg_code varchar(20),
	giftkey numeric(13, 0),
	gtype varchar(6),
	dueamt money,
	balamt money
);
create index idx_pi on mu_pledge_installment_payments(desg_key);
create index idx_giftkey on mu_pledge_installment_payments(giftkey);

insert	into mu_pledge_installment_payments(pkey, desg_key, desg_code, giftkey, gtype,	dueamt, balamt, due_date, installment_number)
select	t.* , row_number() over (partition by pkey, desg_key order by giftkey) as installment_number
from	(select	p.giftallkey as pkey, p.giftkey as desg_key, g.giftrest as desg_code, g.giftkey, trim(g.gifttype) as gtype, 
				case when g.gifttype = 'w' then abs(g.giftjntamt) else g.giftamount end as dueamt, 0 as balamt, g.gifteffdat
		from	MuhlMillProd..gifts g
		join	MuhlMillProd..gifts p on p.giftkey = g.giftplgkey
		where	g.giftplgkey in (select desg_key from mu_Pledge_Base) and trim(g.gifttype) not like '%v' and trim(g.gifttype) not like '%j') t;

begin
	declare @pkey numeric(13, 0)
	declare @desg_key numeric(13, 0)
	declare @payduedate date
	declare @dueamt money
	declare @balamt money
	declare @p_order integer
	declare @billing varchar(1)
	declare @counter numeric(13, 0)
	declare @running_due_sum money
	declare @giftrest varchar(20)

	declare p_cursor cursor for
	select	pkey, desg_key, payduedate, dueamt, balamt, p_order, billing, running_due_sum, giftrest
	from	mu_Pledge_Base pb
	join	MuhlMillProd..gifts g on g.giftkey = desg_key
	where	running_due_sum > isnull((select sum(dueamt) from mu_pledge_installment_payments where desg_key = pb.desg_key), 0)
	order	by pkey, desg_key, p_order

	set nocount on
	select @counter = 0
	open p_cursor
	fetch next from p_cursor into @pkey, @desg_key, @payduedate, @dueamt, @balamt, @p_order, @billing, @running_due_sum, @giftrest

	while (@@fetch_status <> -1)
	begin
		if (@@fetch_status <> -2)
		begin
			select @counter = @counter + 1

			select @balamt = isnull((select sum(dueamt) from mu_pledge_installment_payments where desg_key = @desg_key), 0)
			insert	into mu_pledge_installment_payments(pkey, desg_key, desg_code, giftkey, gtype,	dueamt, balamt, due_date, installment_number)
			values (@pkey, @desg_key, @giftrest, 0, '', @running_due_sum - @balamt, @running_due_sum - @balamt,  @payduedate, @p_order)

			if @counter % 100 = 0 
				print convert(varchar(50), @counter);

			-- Get next record
			fetch next from p_cursor into @pkey, @desg_key, @payduedate, @dueamt, @balamt, @p_order, @billing, @running_due_sum, @giftrest
		end 
	end
end
close p_cursor
deallocate p_cursor
set nocount off

-------------------------------------------------------------------------------------------------
-->> Validation - - - - - - - - - - - - -  - - - - - - - - - - - - -  - - - - - - - - - - - - - 
-------------------------------------------------------------------------------------------------
-->> there are three pledge transactions with bad giftamount (balance) fields
/*	pkey	due			pkey		due
	47200	412034.32	47200		434168.64
	365459	12.50		365459		12.49
	389030	15.00		389030		30.00
*/
with pins as (
	select pkey, sum(dueamt) as due from mu_pledge_installment_payments group by pkey
),
pb as (
	select primary_key as pkey, sum(payments+balance) as due from mu_Pledge_Work group by primary_key
)
select * from pins left join pb on pb.pkey = pins.pkey 
where isnull(pb.due, 0) <> isnull(pins.due, 0);  
-------------------------------------------------------------------------------------------------
select * from mu_pledge_installment_payments where dueamt < 0 and balamt <> 0;
-------------------------------------------------------------------------------------------------
select * from mu_pledge_installment_payments where dueamt < 0;
-------------------------------------------------------------------------------------------------

--================================================================================================
-- PART TWO: build GiftCommitment load table
--================================================================================================
drop table if exists GiftCommitment_load;
with all_pledges as (
	select	pkey, sum(dueamt) as pledge_total, min(due_date) as start_date, max(due_date) as end_date, sum(balamt) as balance
	from	mu_pledge_installment_payments 
	group	by pkey
),
write_off_sum as(
	select	a.pkey, sum(abs(w.giftjntamt)) as write_off_amount
	from	MuhlMillProd..gifts g
	join	all_pledges a on a.pkey = g.giftallkey
	join	MuhlMillProd..gifts w on w.giftplgkey = g.giftkey and w.gifttype = 'w'
	where	g.gifttype in ('p', 'e', 'mp') 
	group	by a.pkey
)

select	ASLE_External_ID__c				= convert(varchar(30), a.pkey)
		,gifttype						= trim(g.gifttype)
		,giftid							= giftid
		,Name							= concat(ac.name, ' - ', CONVERT(VARCHAR(10), g.gifteffdat, 101), case when g.gifttype = 'p' then ' - Pledge' when g.gifttype = 'e' then ' - Expectancy' else ' - Match Pledge' end)
		,DonorId						= ac.Id
		,Contact						= ac.PersonContactId
		,ExpectedTotalCmtAmount			= pledge_total
		,EffectiveStartDate				= coalesce(start_date, gifteffdat)
		,ExpectedEndDate				= coalesce(end_date, gifteffdat)
		,ScheduleType					= 'Custom'
		,Status							= case when balance = 0 then 'Closed'
										  else 'Active' end
		,CampaignId						= cg.Id
		,FulfillmentType				= case when giftrevoke = 'Y' then 'Conditional' else 'Unconditional' end
		,CreatedDate					= g.giftcrdate
		,LastModifiedDate				= g.giftdate
		,w.write_off_amount				
		,GiftVehicle					= case when trim(gt.table_val) <> '' then trim(gt.table_val) end 

		-- custom fields
		,ASLE_Processed_Date__c			= giftprocdt
		,ASLE_Effective_Date__c			= gifteffdat
		,ASLE_Comments__c				= trim(isnull(giftcomm, ''))
into	GiftCommitment_load
from	all_pledges a
join	MuhlMillProd..gifts g on g.giftkey = a.pkey
join	sf_accounts ac on g.giftid=ac.ASLE_External_ID_c
left	join MuhlMillProd..tender gt on gt.table_code = g.gifttender
left	join sf_campaigns cg on cg.ASLE_External_ID_c = case when giftcamp = '' then 'default' else trim(giftcamp) end collate Latin1_General_BIN 
left	join write_off_sum w on w.pkey = a.pkey;
