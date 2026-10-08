
/***************************************************************************************
        PURPOSE:    Populate the contact point phone records
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     ContactPointPhone

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-21-2026:  Original version (total table count 104,394)
   phone type codes:
        30079	adlh  	Additional Phone – Land Line                                     
        27246	cell  	Cell Phone                                                       
        16528	adlm  	Additional Phone – Cell                                          
        13619	a     	Home                                                             
        12985	fp    	Former Phone                                                     
        2578	b     	Business                                                         
        478	    APTU  	Additional Phone ( Type Unknown )                                
        173	    emailf	Former E-Mail                                                    
        150	    AddP  	Additional Phone                                                 
        138	    alt   	Alternate Home                                                   
        134	    (n/a)   (n/a)  	                                                                 
        99	    adlv  	Additional Phone – VoIP                                          
        98	    af    	Former Home                                                      
        45	    alb   	Alternate Business                                               
        19	    bf    	Former Business                                                  
        7	    ASOP  	Assistant's Office Phone                                         
        6	    wwwf  	Former Internet                                                  
        4	    email 	E-Mail (HOME or BUSINESS)                                        
        2	    altf  	Former Alternate Home                                            
        2	    www   	Internet                                                         
        1	    reshid	Research Identified                                              
        1	    s     	Summer                                                           
        1	    ASCP  	Assistant's Cell Phone                                           
        1	    voip  	VoIP   
        
addresses with phones:
        98429	a     	Home                                                             
        81071	af    	Former Home                                                      
        28833	b     	Business                                                         
        20885	bf    	Former Business                                                  
        425	    alt   	Alternate Home                                                   
        83	    alb   	Alternate Business                                               
        63	    s     	Summer                                                           
        58	    w     	Winter                                                           
        50	    altf  	Former Alternate Home                                            
        20	      	                                                                 
        8	    email 	E-Mail (HOME or BUSINESS)                                        
        2	    emailf	Former E-Mail                                                    
        2	    www   	Internet                                                         
        1	    pf    	Former Phone                                                     
        1	    emab  	E-Mail: Business                                                 
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: create local table for phones
--================================================================================================
drop table if exists mu_all_phones;

with all_phone as (
	select	convert(varchar(30), phnkey) as phnkey, phnid, trim(phnnumber) as phnnumber, trim(pt.table_val)as phntype, trim(r.table_val) as restriction,
			phntxt4, phnchk1, phnsource, phndate1, phncrdate, phndate, phnuserid
	from	MuhlMillProd..phone p
	left	join MuhlMillProd..phone_type pt on pt.table_code = phntype
	left	join MuhlMillProd..phone_restrictions r on r.table_code = phnrest
	where	trim(isnull(phnnumber, '')) <> '' and pt.table_val not like '%E-Mail%' and pt.table_val not like '%Internet%'
),
address_phones as (
	select	'addr_1_' + convert(varchar(30), addrkey) as addrkey, addrid, trim(addrphone) as addrphone, case when table_code in ('a','af','s','w','altf','','email','emailf','www','pf') then 'Home'
			when table_code in ('bf','b','alb','emab') then 'Business'
			else trim(table_val) end as phntype, addrph1rst, addrcrdate, addrdate, addruserid
	from	MuhlMillProd..address
	join	MuhlMillProd..address_types t on t.table_code = addrtype
	where	isnull(addrphone, '')  <> '' 
	union	
	select	'addr_2_' + convert(varchar(30), addrkey) as addrkey, addrid, trim(addraltph), case when table_code in ('a','af','s','w','altf','','email','emailf','www','pf') then 'Home'
			when table_code in ('bf','b','alb','emab') then 'Business'
			else trim(table_val) end, addrph2rst, addrcrdate, addrdate, addruserid
	from	MuhlMillProd..address
	join	MuhlMillProd..address_types t on t.table_code = addrtype
	where	isnull(addraltph, '')  <> '' 
	union	
	select	'addr_3_' + convert(varchar(30), addrkey) as addrkey, addrid, trim(addrfaxph), case when table_code in ('bf', 'af') then 'Former Fax' else 'Direct Fax' end, addrph3rst, addrcrdate, addrdate, addruserid
	from	MuhlMillProd..address
	join	MuhlMillProd..address_types t on t.table_code = addrtype
	where	isnull(addrfaxph, '')  <> '' 
)
select	* into mu_all_phones 
from     all_phone
union
select	addrkey, addrid, addrphone, phntype, table_val, null, 'N', null, null, addrcrdate, addrdate, addruserid
from	address_phones
left	join MuhlMillProd..phone_restrictions r on r.table_code = addrph1rst
where	not exists (select 1 from all_phone where phnid = addrid and phnnumber = trim(addrphone));

--================================================================================================
-- PART ONE: create contact point for phones (210,481)
--================================================================================================
drop table if exists ContactPointPhone_load;
select	ASLE_Contact_Point_Phone_External_Id__c		= phnkey
		,ParentId									= a.Id
		,ActiveToDate								= case when phntype like 'Former%' then getdate() - 1 end
		,UsageType									= trim(phntype)
		,PhoneType									= case when trim(phntype) in ('Home', 'Former Home') then 'Home' 
														   when trim(phntype) in ('Cell Phone') then 'Mobile'
													  end
		,IsPrimary									= 'false'
		,IsFaxCapable								= case when trim(phntype) in ('Direct Fax', 'Former Fax') then 'true' else 'false' end
		,TelephoneNumber							= phnnumber
		,ExtensionNumber							= null
		,IsBusinessPhone							= case when trim(phntype) like '%Business%' then 'true' else 'false' end
		,IsPersonalPhone							= case when trim(phntype) not like '%Business%' then 'true' else 'false' end
		--,ASLE_Do_Not_Call__c						= case when do_not_call = -1 then 'true' else 'false' end
		,FormattedInternationalPhoneNumber			= case when len(replace(replace(replace(replace(replace(phnnumber, '(', ''), ')', ''), ' ', ''), '-', ''), '.', '')) > 10 then p.phnnumber end
		--,OwnerId									= u.Id
		,CreatedDate								= phncrdate
		--,CreatedById								= u.Id
		,LastModifiedDate							= phndate
		--,LastModifiedById							= u.Id
		,ASLE_Comments__c							= case when trim(isnull(phntxt4, '')) <> '' then trim(isnull(phntxt4, '')) end
		,IsSmsCapable								= case when phnchk1 = 'Y' then 'true' else 'false' end
		,ASLE_Do_Not_Text__c						= case when trim(isnull(restriction, '')) = 'Do Not Text' then 'true' else 'false' end
		,ASLE_Alumni_Verified_Pref__c				= phndate1
		,ASLE_Source__c								= case when trim(isnull(s.table_val, '')) <> '' then trim(isnull(s.table_val, '')) end
		,ASLE_Restriction__c						= case when trim(isnull(restriction, '')) not in ('', 'Do Not Text') then trim(isnull(restriction, '')) end
into	ContactPointPhone_load
from	mu_all_phones p
left	join MuhlMillProd..source_types s on s.table_code = phnsource
join	sf_accounts a on a.ASLE_External_ID_c = p.phnid;

update ContactPointPhone_load set TelephoneNumber = left(TelephoneNumber, 40) where len(TelephoneNumber) > 40;

select distinct UsageType from ContactPointPhone_load
select distinct ASLE_Source__c from ContactPointPhone_load
select distinct ASLE_Restriction__c from ContactPointPhone_load

-->> cleanup

update	ContactPointPhone_load
set		LastModifiedDate=CreatedDate, CreatedDate=LastModifiedDate
where	LastModifiedDate<CreatedDate;

-->> get records for loading
select * from ContactPointPhone_load;

