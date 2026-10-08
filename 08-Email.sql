
/***************************************************************************************
        PURPOSE:    Populate the contact point email records
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     ContactPointEmail

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-21-2026:  Original version (total table count 104,394)
   custom fields:
        ASLE_Restrictions__c varchar(255);
        ASLE_Source__c varchar(255);
		ASLE_Internet_Address__c varchar(255);
   email type codes:  
        59343	email 	E-Mail (HOME or BUSINESS)                                        
		25437	femail	Former E-Mail (HOME or BUSINESS)                                 
		14727	wwwli 	LinkedIn                                                         
		2193	www   	Internet                                                         
		1891	emailf	Former E-Mail                                                    
		796		addEM 	Additional EMAIL-Not preferred                                   
		504		frmrli	Former LinkedIn                                                  
		50		udreml	Donor Relations Use Only                                         
		9		EmailS	E-Mail: Student on Campus                                        
		7		ASEML 	Assistant's Email                                                
		2		residn	Research Identified                                              
		1		wwwpdc	Podcast                                                                                                   
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: create local table for emails
--================================================================================================
drop table if exists mu_emails;
select	row_number() over (partition by intid order by intpref desc, intrest, intpubfl desc, intstop, 
							case when inttype='email' then 1 when inttype='addEM' then 2 else 3 end, intstart asc, intcrdate desc) as prefseq,
		t.table_val,a.*
into	mu_emails		
from	MuhlMillProd..internetaddress_type t
join	MuhlMillProd..internetaddress a on a.inttype=t.table_code;

-->> get picklist values
select distinct e.intrest, t.table_val from mu_emails e join MuhlMillProd..phone_restrictions t on e.intrest=t.table_code;
select distinct table_val from mu_emails;
select distinct t.table_val from mu_emails e join muhlmillprod..source_types t on e.intsource=t.table_code;

--================================================================================================
-- PART TWO: create loading table for emails (104,930)
--================================================================================================
drop table if exists ContactPointEmail_load;
select 	ASLE_External_ID__c			= convert(varchar(30), e.intkey)
		, ParentId					= a.Id
		, ActiveFromDate			= case when e.intstop is not null and e.intstart is null then e.intcrdate else e.intstart end
		, ActiveToDate				= e.intstop
		, ASLE_Do_Not_Email__c		= case when e.inttype in ('DNU','UNLIST','nlv') then 1 else 0 end
		, ASLE_Do_Not_Solicit__c	= case when e.intrest='NOSOL' then 1 else 0 end
		, IsPrimary					= case when e.prefseq=1 then 1 else 0 end
		, EmailAddress				= case when e.intaddress like '%@%.%' then trim(lower(e.intaddress))+'.invalid'
										   else 'intaddr@x.com.invalid' end
		, UsageType					= trim(e.table_val)
		, CreatedDate				= e.intcrdate
		, LastModifiedDate			= e.intdate
		, ASLE_Internet_Address__c	= case when e.intaddress not like '%@%.%' then e.intaddress else '' end
		, ASLE_Comments__c			= rtrim(isnull(e.intcomm, ''))
		, ASLE_Restrictions__c		= rtrim(isnull(t.table_val, ''))
		, ASLE_Source__c			= rtrim(isnull(s.table_val, ''))
into	ContactPointEmail_load
FROM	mu_emails e
join	sf_accounts a on e.intid=a.ASLE_External_ID_c
left	join MuhlMillProd..phone_restrictions t on t.table_code = e.intrest
left	join MuhlMillProd..source_types s on s.table_code = e.intsource;

-->> cleanup
update ContactPointEmail_load set LastModifiedDate=CreatedDAte, CreatedDate=LastModifiedDate where LastModifiedDate<CreatedDate;

-->> get records for loading
select * from ContactPointEmail_load;