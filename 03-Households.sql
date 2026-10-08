
/***************************************************************************************
        PURPOSE:    Populate the Accounts object with households (duals and singles)
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     create household accounts - REMINDER - TURN OFF FLOW THAT AUTO-CREATES HOUSEHOLDS

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  08-25-2026:  Original version

                    household relationship codes: 
                    where relationship.table_code in ('ssp','sp','lp','dsp')
                                                
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: create load table for households
--================================================================================================

-->> find and localize the most recent spouse record based on create date
	drop table if exists mu_current_spouses;
	with spouse_list as (
		select	r.*, row_number() over (partition by relid order by reldate desc,relkey desc) as sps_seq		
		from	muhlmillprod..relation r
		where	r.relisa in ('ssp','sp','lp','dsp')
		and		r.relid is not null
	)
	select	s1.*
	into	mu_current_spouses
	from	(select distinct relid from muhlmillprod..relation where relisa in ('ssp','sp','lp','dsp')) r
	join	spouse_list s1 on r.relid=s1.relid and s1.sps_seq=1;

-->> create household temp table and identify primary vs. secondary spouse
-->> this group handles spouse groups where both spouses have an id
	drop table if exists #hhlist;
	select	relkey,relisa,relid,nametitle,namefirst,namemiddle,namelast,namesuffix,
			relgender,relctype,reldc,relgifts,
			case	when relisa='ssp' and relwhose='dsp' then 'P'
					when relisa='dsp' and relwhose='ssp' then 'S'
					when reldc ='Y' and relrelatdc='N' then 'S'
					when reldc ='N' and relrelatdc='Y' then 'P'
					when relctype='Alumni' and relrelatctype<>'Alumni' then 'P'
					when relctype<>'Alumni' and relrelatctype='Alumni' then 'S'
					when relctype='Friend' and relrelatctype<>'Friend' then 'S'
					when relctype<>'Friend' and relrelatctype='Friend' then 'P'
					when relgifts>relrelatgifts then 'P'
					when relgifts<relrelatgifts then 'S'
					when relgender='M' then 'P'
					when relrelatgender='M' then 'S'
					when relid<relrelatid then 'P'
					when relid>relrelatid then 'S' end as relstatus,
			relrevkey,relwhose,relrelatid,reltitle,relfirst,relmiddle,rellast,relsuffix,
			relrelatgender,relrelatctype,relrelatdc,relrelatgifts,
			case	when relisa='ssp' and relwhose='dsp' then 'S'
					when relisa='dsp' and relwhose='ssp' then 'P'
					when reldc ='Y' and relrelatdc='N' then 'P'
					when reldc ='N' and relrelatdc='Y' then 'S'
					when relctype='Alumni' and relrelatctype<>'Alumni' then 'S'
					when relctype<>'Alumni' and relrelatctype='Alumni' then 'P'
					when relctype='Friend' and relrelatctype<>'Friend' then 'P'
					when relctype<>'Friend' and relrelatctype='Friend' then 'S'
					when relgifts>relrelatgifts then 'S'
					when relgifts<relrelatgifts then 'P'
					when relgender='M' then 'S'
					when relrelatgender='M' then 'P'
					when relid<relrelatid then 'S'
					when relid>relrelatid then 'P' end as relrelatstatus
	into	#hhlist
	from (	select	r.relkey, r.relisa, r.relid, n1.nametitle,n1.namefirst,n1.namemiddle,n1.namelast,n1.namesuffix, 
					c1.coresex as relgender, t1.table_val as relctype,
					case when d1.deathid is not null then 'Y' else 'N' end as reldc,
					isnull((select sum(giftamount) from MuhlMillProd..gifts where giftid = r.relid and gifttype in ('g', 'y')), 0) as relgifts,
					r.relrevkey, r.relwhose, r.relrelatid, n2.nametitle as reltitle, n2.namefirst as relfirst, 
					n2.namemiddle as relmiddle, n2.namemiddle as rellast, n2.namesuffix as relsuffix, 
					c2.coresex as relrelatgender, 
					t2.table_val as relrelatctype,
					case when d2.deathid is not null then 'Y' else 'N' end as relrelatdc,
					isnull((select sum(giftamount) from MuhlMillProd..gifts where giftid = r.relrelatid and gifttype in ('g', 'y')), 0) as relrelatgifts		
			from	mu_current_spouses r
			join	MuhlMillProd..name n1 on r.relid=n1.nameid and n1.nametype='a'
			left	join MuhlMillProd..death d1 on d1.deathid = r.relid
			join	MuhlMillProd..corebio c1 on c1.coreid = r.relid
			join	MuhlMillProd..constituent_types t1 on t1.table_code = c1.coreconst
			join	MuhlMillProd..name n2 on r.relrelatid=n2.nameid and n2.nametype='a'
			left	join MuhlMillProd..death d2 on d2.deathid = r.relrelatid
			join	MuhlMillProd..corebio c2 on c2.coreid = r.relrelatid
			join	MuhlMillProd..constituent_types t2 on t2.table_code = c2.coreconst
			where	r.relrelatid is not null
		)x;

-->> append to the temp table the combined spouses so that we can create an account for the second spouse
-->> secondary spouse does not have a coreid
	insert	into #hhlist
	select	relkey,relisa,relid,nametitle,namefirst,namemiddle,namelast,namesuffix,
			relgender,relctype,reldc,relgifts,'P' as relstatus,
			relrevkey,relwhose,relrelatid,reltitle,relfirst,relmiddle,rellast,relsuffix,
			relrelatgender,relrelatctype,relrelatdc,relrelatgifts,'S' as relrelatstatus	
	from (	select	r.relkey, r.relisa, r.relid, n1.nametitle,n1.namefirst,n1.namemiddle,n1.namelast,n1.namesuffix, 
					c1.coresex as relgender, t1.table_val as relctype,
					case when d1.deathid is not null then 'Y' else 'N' end as reldc,
					isnull((select sum(giftamount) from MuhlMillProd..gifts where giftid = r.relid and gifttype in ('g', 'y')), 0) as relgifts,
					r.relrevkey, r.relwhose, r.relrelatid, r.reltitle, r.relfirst, r.relmiddle, r.rellast, r.relsuffix, 
					r.relsex as relrelatgender, 
					case when t1.table_val='Alumni' then 'Friend' else t1.table_val end as relrelatctype,
					case when r.relwhose='dsp' then 'Y' else 'N' end as relrelatdc, 0 as relrelatgifts	
			from	mu_current_spouses r
			join	MuhlMillProd..name n1 on r.relid=n1.nameid and n1.nametype='a'
			left	join MuhlMillProd..death d1 on d1.deathid = r.relid
			join	MuhlMillProd..corebio c1 on c1.coreid = r.relid
			join	MuhlMillProd..constituent_types t1 on t1.table_code = c1.coreconst
			where	r.relrelatid is null
		)x order by relid;

-->> create the household table with all entities from temp table
	drop table if exists mu_household_account_list;
	select	case when relstatus='P' then a1.id else a2.id end as psfid,
			case when relstatus='P' then cast(relkey as varchar(15))+'-'+cast(relrevkey as varchar(15)) 
				 else cast(relrevkey as varchar(15))+'-'+cast(relkey as varchar(15)) end as pkey,
			case when relstatus='P' then relisa else relwhose end as ptype,
			case when relstatus='P' then relid else relrelatid end as pid,
			case when relstatus='p' then nametitle else reltitle end as pnametitle,
			case when relstatus='p' then namefirst else relfirst end as pnamefirst,
			case when relstatus='p' then namemiddle else relmiddle end as pnamemiddle,
			case when relstatus='p' then namelast else rellast end as pnamelast,
			case when relstatus='p' then namesuffix else relsuffix end as pnamesuffix,
			case when relstatus='P' then reldc else relrelatdc end as pdc,
			case when relstatus='P' then relctype else relrelatctype end as pctype,
			case when relstatus='P' then relgifts else relrelatgifts end as pgifts,
			case when relstatus='P' then relgender else relrelatgender end as pgender,
			case when relstatus='S' then a1.id else a2.id end as ssfid,
			case when relstatus='S' then cast(relkey as varchar(15))+'-'+cast(relrevkey as varchar(15)) 
				 else cast(relrevkey as varchar(15))+'-'+cast(relkey as varchar(15)) end as skey,
			case when relstatus='S' then relisa else relwhose end as stype,
			isnull(case when relstatus='S' then relid else relrelatid end,'S') as sid,
			case when relstatus='S' then nametitle else reltitle end as snametitle,
			case when relstatus='S' then namefirst else relfirst end as snamefirst,
			case when relstatus='S' then namemiddle else relmiddle end as snamemiddle,
			case when relstatus='S' then namelast else rellast end as snamelast,
			case when relstatus='S' then namesuffix else relsuffix end as snamesuffix,
			case when relstatus='S' then reldc else relrelatdc end as sdc,
			case when relstatus='S' then relctype else relrelatctype end as sctype,
			case when relstatus='S' then relgifts else relrelatgifts end as sgifts,
			case when relstatus='S' then relgender else relrelatgender end as sgender	
	into	mu_household_account_list
	from	#hhlist h
	left	join sf_account_person a1 on h.relid=a1.ASLE_External_ID_c
	left	join sf_account_person a2 on h.relrelatid=a2.ASLE_External_ID_c
	union -->> the single member households
	select	a.Id, '0-0' as pkey, 'na' as ptype, c.coreid as pid,
			n.nametitle,n.namefirst,n.namemiddle,n.namelast,n.namesuffix,
			case when d.deathid is not null then 'Y' else 'N' end as pdc, t.table_val as pctype, 
			isnull((select sum(giftamount) from MuhlMillProd..gifts where giftid = c.coreid and gifttype in ('g', 'y')), 0) as pgifts,
			c.coresex as pgender,null,null,null,null,null,null,null,null,null,null,null,null,null
	from	MuhlMillProd..corebio c
	join	MuhlMillProd..name n on c.coreid=n.nameid and n.nametype='a'
	left	join MuhlMillProd..death d on c.coreid=d.deathid
	join	MuhlMillProd..constituent_types t on t.table_code = c.coreconst
	left	join sf_account_person a on c.coreid=a.ASLE_External_ID_c
	where	(c.coretbltyp='INDIV' or (trim(c.coretbltyp)='' and c.coresex='M'))
	and		not exists (select 1 from #hhlist h where h.relid=c.coreid or h.relrelatid=c.coreid);

-->> drop temp
	drop table if exists #hhlist;

	select count(*) from mu_household_account_list;

	select * from mu_household_account_list where sid = 'S' order by pid;

--================================================================================================
-- PART TWO: create person accounts for the missing secondary spouses
--================================================================================================
	drop table if exists Account_person_ssp_load;
	select	ASLE_External_ID__c					= trim(h.pid+h.sid)
			, ASLE_External_ID__pc				= trim(h.pid+h.sid)
			, PersonBirthdate					= cast(r.relbirthdt as date)
			, ASLE_Deceased__pc					= case when r.relwhose='dsp' then 1 else 0 end
			, PersonGenderIdentity				= case when r.relsex = 'M' then 'Male'
													   when r.relsex = 'F' then 'Female' end
			, Description						= trim(r.relcomm)
			, ASLE_Primary_Constituent_Role__c  = trim(h.sctype)
			, ASLE_VSE_Donor_Category__c		= 'B. Nonalumni Individuals'

			--names
			, LastName							= case when trim(h.snamelast)='' then trim(h.pnamelast) else trim(h.snamelast) end 
			, FirstName							= trim(h.snamefirst)
			, MiddleName						= trim(h.snamemiddle)
			, Salutation						= trim(h.snametitle)
			, Suffix							= trim(h.snamesuffix)

			--audit
			, RecordTypeId						= rt.Id
			, CreatedDate						= r.relcrdate
			, LastModifiedDate					= r.reldate
	into	Account_person_ssp_load		
	from	mu_household_account_list h
	join	MuhlMillProd..relation r on replace(pkey,'-0','')=r.relkey
	join	sf_recordtypes rt on rt.SObjectType = 'Account' and rt.Name = 'Person Account'
	where	h.sid like 'S%';

	select * from Account_person_ssp_load;

-->> load with DL.
-->> pull results back into sf_account_person_ssp;
-->> update household table with new IDs

	ALTER TABLE sf_account_person_ssp ALTER COLUMN ASLE_External_ID_c VARCHAR(50) COLLATE Latin1_General_BIN;

	update h
	set	h.ssfid=x.id
	from	mu_household_account_list h
	join	sf_account_person_ssp x on h.pid+'S'=x.asle_external_id_c;

-->> use data loader and bring back all accounts
-->> we need to remove the auto-generated household accounts
	
	drop table if exists Account_hh_auto_delete;
	select	a.Id
	into	Account_hh_auto_delete
	from	sf_accounts a
	join	sf_recordtypes r on a.recordtypeid=r.id and r.name='Household';

	select * from Account_hh_auto_delete;

--================================================================================================
-- PART THREE: create the household accounts from the household account list
-- 85,651 households  (less 7 dupes for review) = 85,644
--================================================================================================	
	drop table if exists Account_hh_load;
	select distinct	ASLE_External_ID__c						= trim(h.pid)+'H'
			,Name											= trim(n1.nameformn)+' Household'
			,ASLE_Primary_Household_Contact__c				= h.psfid
			,ASLE_Secondary_Household_Contact__c			= h.ssfid
			,ASLE_Household_Formal_Name__c					= trim(n1.nameplural)
			,ASLE_Household_Formal_Name_Override__c			= case when trim(n1.nameplural)<>'' then 1 else 0 end
			,ASLE_Household_Formal_Salutations__c			= trim(n1.namecsalut)
			,ASLE_Household_Form_Salutations_Override__c	= case when trim(n1.namecsalut)<>'' then 1 else 0 end
			,RecordTypeId									= (select Id from sf_recordtypes where name='Household' and SobjectType='Account')
	into	Account_hh_load
	from	mu_household_account_list h
	left	join muhlmillprod..name n1 on h.pid=n1.nameid and n1.nametype='a'
	order by 1;

	select	* from Account_hh_load;

-->> use data loader and bring back all accounts and load to table sf_accounts
/*	Select  Id, ASLE_External_ID__c, PersonContactId, Name, Salutation, FirstName, MiddleName, LastName, Suffix, 
			ASLE_Primary_Household_Contact__c, ASLE_Secondary_Household_Contact__c, RecordTypeId
			from Account
*/
	drop table if exists sf_accounts;
	-- import new csv file

	ALTER TABLE mu_household_account_list ADD hhsfid nchar(18);
	ALTER TABLE sf_accounts ALTER COLUMN ASLE_External_ID_c VARCHAR(50) COLLATE Latin1_General_BIN;

-->> a few rows don't have the account id in psfid
	update	h
	set		h.psfid=a.Id 
	from	mu_household_account_list h
	join	sf_accounts a on h.pid=a.asle_external_id_c
	where	h.psfid is null;

	update	a
	set		a.ASLE_Primary_Household_Contact_c = h.psfid
	from	sf_accounts a
	join	(select distinct psfid, pid from mu_household_account_list) h on a.asle_external_id_c=h.pid+'H'
	where	a.ASLE_Primary_Household_Contact_c is null;

--================================================================================================
-- PART FOUR: add the household relationships to account contact relations
--================================================================================================	
	drop table if exists AccountContactRelation_hh_load;
	select	a.Id						as AccountId,
			pc.PersonContactId			as ContactId,
			a.asle_external_id_c+'p'	as ASLE_External_ID__c,
			1							as IsActive,
			'Primary Household Contact'	as Roles
	into	AccountContactRelation_hh_load
	from	sf_accounts a
	join	sf_accounts pc on a.asle_primary_household_contact_c=pc.Id
	join	sf_recordtypes r on r.name='Household' and a.recordtypeid=r.id
	where	pc.PersonContactId is not null
	union
	select	a.Id							as AccountId,
			sc.PersonContactId				as ContactId,
			a.asle_external_id_c+'s'		as ASLE_External_ID__c,
			1								as IsActive,
			'Secondary Household Contact'	as Roles
	from	sf_accounts a
	join	sf_accounts sc on a.asle_secondary_household_contact_c=sc.Id
	join	sf_recordtypes r on r.name='Household' and a.recordtypeid=r.id
	where	sc.PersonContactId is not null;

	-- use dataloader to load these relationships
	select	* from AccountContactRelation_hh_load;


-->> find the ones where the "spouse" is not a person and post for review
select	a.Id as HouseholdID,a.Name as HouseholdName, p.Id as AccountID, p.asle_external_id_c as COREID, 
		p.Name as AccountName, (select r.name from sf_recordtypes r where p.recordtypeid=r.id) as RecordType,
		r.relkey, r.relisa
from	sf_accounts a
join	sf_accounts p on a.asle_primary_household_contact_c=p.Id
join	MuhlMillProd..relation r on p.asle_external_id_c=r.relid and r.relisa in ('ssp','dsp','sp','lp')
where	p.PersonContactId is null;




