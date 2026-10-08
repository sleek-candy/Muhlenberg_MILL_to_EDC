
/***************************************************************************************
        PURPOSE:    Populate the education/academic objects
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        Academic Credential
        Area of Study
        Person Academic Credential
        Person Education
        Majors, Minors, Concentrations

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: populate academic credential (degrees lookup)
--================================================================================================
drop table if exists AcademicCredential_load;
select	ASLE_External_ID__c						= trim(s.table_code)
		,Name									= trim(s.table_val)
		,Type									= case when s.table_val like '%Bachelor%' or trim(table_type) ='u' then 'Bachelor''s Degree'
													   when s.table_code like '%JD%' then 'Doctoral Degree'
													   when isnull(s.table_val , '') like '%Master%' then 'Master''s Degree'
													   when isnull(s.table_val , '') like '%Doctor%' then 'Doctoral Degree'
													   when isnull(s.table_val , '') like '%Certif%' then 'Certificate'
                                                       when isnull(s.table_val,'') like '%Associate%' then 'Associate Degree'
												  else 'Other' end
		,CreatedDate							= table_date
		,LastModifiedDate						= table_date
		,ASLE_Comment__c						= case when isnull(trim(table_comm), '') <> '' then trim(table_comm) end
into    AcademicCredential_load
from	MuhlMillProd..degrees s
where	table_code <> '';

-->> get records for loading
select * from AcademicCredential_load;

-->> import the success file to sf_academic_credential;

--================================================================================================
-- PART TWO: populate person academic credential (40,255)
--================================================================================================
-->> get picklists and codes
select * from MuhlMillProd..table_groups where table_code = 'u'
select * from MuhlMillProd..fieldlst where table_name = 'school'
select * from MuhlMillProd..school --where schlcampus <> ''
select * from MuhlMillProd..attribute where attrlnkfil = '07'


drop table if exists PersonAcademicCredential_load;
select	ASLE_External_ID__c						= convert(varchar(30), r.schlkey)
		,Name									= convert(varchar(30), r.schlkey)
		,LearnerContactId						= a.PersonContactId
		,AcademicCredentialId					= d.Id
		,CredentialType							= isnull(d.Type,'Unknown')
		,CredentialName							= isnull(d.Name,'Unknown')
		,IssuerName								= trim(i.table_val)
		,AchievedDate							= case when trim(isnull(r.schldegyr, '')) <> '' and trim(isnull(r.schldegmn, '')) <> '' then
													 case when  trim(isnull(r.schldegdy, '')) <> '' then convert(date, concat(trim(r.schldegmn), '/', trim(r.schldegdy), '/', trim(r.schldegyr)))
													  else convert(date, concat(trim(r.schldegmn), '/01/', trim(r.schldegyr))) end
													end
		,ASLE_Academic_Credential_Comments__c	= case when trim(r.schlcomm) <> '' then trim(r.schlcomm)  end
		,ASLE_Academic_Credential_Status__c		= case when trim(scl.table_val) <> 'Law-No Degree' then 'Conferred Degree' end
		,ASLE_Academic_Credential_Year__c		= case when trim(isnull(r.schldegyr, '')) <> '' then  r.schldegyr end
		,ASLE_Graduation_Date__c				= case when trim(isnull(r.schldegyr, '')) <> '' and trim(isnull(r.schldegmn, '')) <> '' then
												 case when  trim(isnull(r.schldegdy, '')) <> '' then  convert(date, concat(trim(r.schldegmn), '/', trim(r.schldegdy), '/', trim(r.schldegyr)))
													  else  convert(date, concat(trim(r.schldegmn), '/01/', trim(r.schldegyr)))
														end end
		,ASLE_Preferred_Year__c					= case when trim(isnull(r.schlprefyr, '')) <> '' then  trim(isnull(r.schlprefyr, '')) 
														when trim(isnull(r.schldegyr, '')) <> '' then trim(isnull(r.schldegyr, '')) end
		,ASLE_Primary_Academic_Credential__c	= case when trim(i.table_val)='Muhlenberg College' then 'true' else 'false' end
		,CreatedDate							= r.schlcrdate
		,LastModifiedDate						= r.schldate
		,ASLE_Source__c							= case when trim(src.table_val) <> '' then trim(src.table_val)  end
		,ASLE_School__c							= case when trim(scl.table_val) <> '' then trim(scl.table_val)  end
		,ASLE_Campus__c							= case when trim(scc.table_val) <> '' then trim(scc.table_val)  end
		,row_number() over (partition by r.schlid order by case when trim(i.table_val)='Muhlenberg College' then 1 else 2 end,r.schldegyr) as primaryseq
into	PersonAcademicCredential_load
from	MuhlMillProd..school r
join	MuhlMillProd..institutions i on i.table_code = r.schlinstit
left	join MuhlMillProd..source_types src on src.table_code = r.schlsource
left	join MuhlMillProd..school_names scl on scl.table_code = r.schlschool
left	join MuhlMillProd..campuses scc on scc.table_code = r.schlcampus
left	join sf_academic_credential d on upper(r.schldegree)=upper(d.ASLE_External_id_c) collate Latin1_General_BIN
join	sf_accounts a on r.schlid=a.ASLE_External_ID_c and a.PersonContactId is not null
left	join MuhlMillProd..school_names s on s.table_code = r.schlschool
where	trim(i.table_val)='Muhlenberg College';

-->> update primary indicator
update PersonAcademicCredential_load set ASLE_Primary_Academic_Credential__c = 'false'
where ASLE_Primary_Academic_Credential__c='true' and primaryseq>1;

-->> cleanup
update	PersonAcademicCredential_load set LastModifiedDAte=CreatedDAte, CreatedDAte=LastModifiedDate where LastModifiedDate<CreatedDAte;
update	PersonAcademicCredential_load set CreatedDAte='1975-01-01' where year(CreatedDate)='1900';
update	PersonAcademicCredential_load set AchievedDAte='1975-01-01' where year(AchievedDate)='1900';

-->> achieved date is required.  fill blanks with create date
update	PersonAcademicCredential_load 
set		AchievedDate = case when ASLE_Academic_Credential_Year__c is not null then datefromparts(ASLE_Academic_Credential_Year__c,'05','01') else cast(CreatedDAte as date) end ,
		ASLE_Academic_Credential_Comments__c=trim(isnull(ASLE_Academic_Credential_Comments__c,'') + ' (Achieved Date is required. Placeholder added)')
where	AchievedDate is null;

-->> add custom field to PersonAcademicCredential add ASLE_Source__c varchar(255);
select distinct ASLE_Source__c from PersonAcademicCredential_load;
-->> add custom field to PersonAcademicCredential add ASLE_School__c varchar(255);
select distinct ASLE_School__c from PersonAcademicCredential_load;
-->> add custom field to PersonAcademicCredential add ASLE_Small_Section__c varchar(255);
select distinct ASLE_Campus__c from PersonAcademicCredential_load;

-->> get list for loading
select * from PersonAcademicCredential_load;

--================================================================================================
-- PART THREE: populate institutions
--================================================================================================
-- CREATE THE MAPPING TABLE
drop table if exists mu_institutions_map;
select	distinct a.Id, a.ASLE_External_ID_c,i.table_val,i.table_code,
		row_number() over (partition by i.table_val order by table_code) as dupeseq
into	mu_institutions_map
from	MuhlMillProd..institutions i
left	join sf_accounts a on i.table_val=a.name Collate Latin1_General_BIN 
where	i.table_val<>i.table_code
and		exists (select 1 from MuhlMillProd..school x where x.schlinstit=i.table_code);

drop table if exists Account_inst_load;
select	ASLE_External_ID__c						= 'inst_' + trim(i.table_code)
		, Name									= trim(i.table_val)
		, RecordTypeId							= rt.Id
		, Type									= 'Educational Institution'
		, Industry								= 'Education'
into	Account_inst_load
from	mu_institutions_map i 
join	sf_recordtypes rt on rt.SObjectType = 'Account' and rt.Name = 'Educational Institution' 
where	i.ASLE_External_ID_c is null
and		i.dupeseq=1;

-->> get records for loading
select	* from Account_inst_load;

-->> import success results and incorporate into the mu_institution_mapping table
update	x
set		x.Id=t.Id, x.ASLE_External_ID_c=t.ASLE_External_ID_c
from	mu_institutions_map x
join	inst_success_temp t on x.table_val=t.name Collate Latin1_General_BIN ;

--================================================================================================
-- PART FOUR: insert Person Education records
--================================================================================================
drop table if exists PersonEducation_load;
select	ASLE_External_ID__c				= convert(varchar(30), r.schlkey)
		, Name							= case when trim(d.table_val) <> '' then trim(d.table_val) else 'Unknown Degree' end
		, ContactId						= a.PersonContactId
		, ASLE_Notes__c					= trim(schlcomm)
		, GraduationDate				= case when trim(isnull(r.schldegyr, '')) <> '' and trim(isnull(r.schldegmn, '')) <> '' then
											 case when  trim(isnull(r.schldegdy, '')) <> '' then 
												convert(date, concat(trim(r.schldegmn), '/', trim(r.schldegdy), '/', trim(r.schldegyr)))
											  else 
												convert(date, concat(trim(r.schldegmn), '/01/', trim(r.schldegyr)))
											end
										  end
		, InstitutionAccountId			= s.id
		, IsActive						= 0
		, CreatedDate					= r.schlcrdate
		, LastModifiedDate				= r.schldate
		, ASLE_ClassYear__c				= case when trim(isnull(r.schlprefyr, '')) <> '' then  trim(isnull(r.schlprefyr, '')) 
											   when trim(isnull(r.schldegyr, '')) <> '' then trim(isnull(r.schldegyr, '')) end
		, ASLE_Source__c				= case when trim(src.table_val) <> '' then trim(src.table_val) end
		, ASLE_School__c				= case when trim(scl.table_val) <> '' then trim(scl.table_val) end
into	PersonEducation_load
from	MuhlMillProd..school r
join	sf_accounts a on a.ASLE_External_ID_c = r.schlid and a.PersonContactId is not null
left	join MuhlMillProd..degrees d on d.table_code = r.schldegree
left	join mu_institutions_map s on s.table_code = trim(r.schlinstit) 
left	join MuhlMillProd..source_types src on src.table_code = r.schlsource
left	join MuhlMillProd..school_names scl on scl.table_code = r.schlschool
where	trim(s.table_val)<>'Muhlenberg College';

-->> get records for loading
select * from PersonEducation_load;

