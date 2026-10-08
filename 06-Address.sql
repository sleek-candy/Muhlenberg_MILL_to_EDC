
/***************************************************************************************
        PURPOSE:    Populate the contact point address records
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     ContactPointEmail
     ContactPointPhone
     ContactPointAddress

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-21-2026:  Original version
   codes:
        1	    emab  	E-Mail: Business                                                 
        81071	af    	Former Home                                                      
        50	    altf  	Former Alternate Home                                            
        8	    email 	E-Mail (HOME or BUSINESS)                                        
        20	    (na)    (na)  	                                                                 
        98429	a     	Home                                                             
        28833	b     	Business                                                         
        20885	bf    	Former Business                                                  
        2	    emailf	Former E-Mail                                                    
        63	    s     	Summer                                                           
        83	    alb   	Alternate Business                                               
        425	    alt   	Alternate Home                                                   
        1	    pf    	Former Phone                                                     
        58	    w     	Winter                                                           
        2	    www   	Internet                                                         
*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: create contact points for address (228,931)
-- AddressType is restricted so I'm putting the Mill values in UsageType
--================================================================================================
drop table if exists ContactPointAddress_load;
with pref_addr as (
	select	addrkey as akey, addrid as idnum, row_number() over (partition by addrid order by case when addrlocatr = 'g' then 'a' else 'b' end, 
				case when month(getdate()) = 1 and addrjan = 'Y' then 'a'
					 when month(getdate()) = 2 and addrfeb = 'Y' then 'a'
					 when month(getdate()) = 3 and addrmar = 'Y' then 'a'
					 when month(getdate()) = 4 and addrapr = 'Y' then 'a'
					 when month(getdate()) = 5 and addrmay = 'Y' then 'a'
					 when month(getdate()) = 6 and addrjun = 'Y' then 'a'
					 when month(getdate()) = 7 and addrjul = 'Y' then 'a'
					 when month(getdate()) = 8 and addraug = 'Y' then 'a'
					 when month(getdate()) = 9 and addrsep = 'Y' then 'a'
					 when month(getdate()) = 10 and addroct = 'Y' then 'a'
					 when month(getdate()) = 11 and addrnov = 'Y' then 'a'
					 when month(getdate()) = 12 and addrdec = 'Y' then 'a'
				else 'b' end,					
				addrdate desc) as rnum
	from	MuhlMillProd..address a
	join	MuhlMillProd..address_types t on a.addrtype=t.table_code
	where	addrmc1 = 'Y'
	and		t.table_val not like 'Former%'
),
seasonal as (
	select	addrkey as skey,
			case when addrjan = 'Y' and addrdec = 'N' then '01'
				 when addrfeb = 'Y' and addrjan = 'N' then '02'
				 when addrmar = 'Y' and addrfeb = 'N' then '03'
				 when addrapr = 'Y' and addrmar = 'N' then '04'
				 when addrmay = 'Y' and addrapr = 'N' then '05'
				 when addrjun = 'Y' and addrmay = 'N' then '06'
				 when addrjul = 'Y' and addrjun = 'N' then '07'
				 when addraug = 'Y' and addrjul = 'N' then '08'
				 when addrsep = 'Y' and addraug = 'N' then '09'
				 when addroct = 'Y' and addrsep = 'N' then '10'
				 when addrnov = 'Y' and addroct = 'N' then '11'
				 when addrdec = 'Y' and addrnov = 'N' then '12'
			end as startm,
			case when addrjan = 'N' and addrdec = 'Y' then '12'
				 when addrfeb = 'N' and addrjan = 'Y' then '01'
				 when addrmar = 'N' and addrfeb = 'Y' then '02'
				 when addrapr = 'N' and addrmar = 'Y' then '03'
				 when addrmay = 'N' and addrapr = 'Y' then '04'
				 when addrjun = 'N' and addrmay = 'Y' then '05'
				 when addrjul = 'N' and addrjun = 'Y' then '06'
				 when addraug = 'N' and addrjul = 'Y' then '07'
				 when addrsep = 'N' and addraug = 'Y' then '08'
				 when addroct = 'N' and addrsep = 'Y' then '09'
				 when addrnov = 'N' and addroct = 'Y' then '10'
				 when addrdec = 'N' and addrnov = 'Y' then '11'
			end as endm
	from	MuhlMillProd..address 
	where	addrjan + addrfeb + addrmar + addrapr + addrmay + addrjun + addrjul + addraug + addrsep + addroct + addrnov + addrdec <> 'YYYYYYYYYYYY'
			and addrjan + addrfeb + addrmar + addrapr + addrmay + addrjun + addrjul + addraug + addrsep + addroct + addrnov + addrdec <> 'NNNNNNNNNNNN'
)

select distinct	ASLE_External_ID__c						= convert(varchar(100), addrkey)
		, [Name]										= convert(varchar(100), addrkey)
		, idnum											= addrid
		, ParentId										= ac.Id
		, ActiveFromDate								= addrstart
		, ActiveToDate									= addrstop		
		--, IsPrimary										= case when p.akey is not null then 'true' else 'false' end
		, IsPrimary										= case when p.rnum=1 then 'true' else 'false' end
		, AddressType									= case when trim(t.table_val) not in ('Home','Other','Mailing','Billing','Shipping') then 'Other' 
															   when trim(t.table_val)='' then 'Other'
															   else trim(t.table_val) end
		, UsageType										= trim(t.table_val)
		, Street										= case when trim(isnull(addrline1, '')) + trim(isnull(addrline2, '')) + trim(isnull(addrline3, '')) = '' then 
																null
														  else
																trim(isnull(addrline1, ''))  
																+ case when trim(isnull(addrline1, '')) <> '' and trim(isnull(addrline2, '')) + trim(isnull(addrline3, '')) <> '' then char(10) else '' end
																+ case when trim(isnull(addrline2, '')) <> '' then 
																	trim(isnull(addrline2, '')) 
																	  + case when trim(isnull(addrline3, '')) <> '' then char(10) + trim(isnull(addrline3, '')) else '' end
																  else 
																	trim(isnull(addrline3, ''))
																  end
														  end
		, City											= trim(addrcity)
		, State											= case when isnull(trim(st.table_val), '') <> '' then trim(st.table_val) end
		, PostalCode									= trim(addrzipcod)
		, Country										= case when isnull(trim(c.table_val), '') <> '' then trim(c.table_val) end
		, IsDefault										= 'false'
		--, ASLE_Copy_to_Account_Mailing_Address_on__c	= case when p.akey is not null then 'true' else 'false' end
		, ASLE_Copy_to_Account_Mailing_Address_on__c	= case when p.rnum=1 then 'true' else 'false' end
		, ASLE_Seasonal_Start_Month__c					= startm
		, ASLE_Seasonal_Start_Day__c					= '01'
		, ASLE_Seasonal_End_Month__c					= endm
		, ASLE_Seasonal_End_Day__c						= case when endm in ('01', '03', '05', '07', '08', '10', '12') then '31'
															   when endm = '02' then '28'
														       when endm is not null then '30' 
														  end
		, ASLE_Data_Source__c							= case when isnull(trim(src.table_val), '') <> '' then trim(src.table_val) end
		--, OwnerId										= coalesce(mb.Id, u.Id)
		, CreatedDate									= addrcrdate
		--, CreatedById									= coalesce(mb.Id, u.Id)
		, LastModifiedDate								= addrdate
		--, LastModifiedById								= coalesce(mb.Id, u.Id)	
		--, ASLEUVL_Archive_Original_Country__c			= case when isnull(trim(c.table_val), '') <> '' then trim(c.table_val) end
		--, ASLEUVL_Archive_Original_State__c				= case when isnull(trim(st.table_val), '') <> '' then trim(st.table_val) end
		--, ASLE_Region__c								= case when isnull(trim(r.table_comm), '') <> '' then trim(r.table_comm) end
		, ASLE_County__c								= addrcounty
		, ASLE_Locator__c								= case when isnull(trim(l.table_val), '') <> '' then trim(l.table_val) end
		,p.rnum, p.akey
into	ContactPointAddress_load
from	MuhlMillProd..address a
join	sf_accounts ac on a.addrid=ac.ASLE_External_id_c
left	join pref_addr p on p.akey=a.addrkey and p.idnum = addrid and p.rnum = 1
join	MuhlMillProd..address_types t on t.table_code = addrtype
left	join MuhlMillProd..places st on st.table_code = addrplace
left	join MuhlMillProd..countries c on c.table_code = addrcntry
left	join MuhlMillProd..source_types src on src.table_code = addrsource
left	join MuhlMillProd..regions r on r.table_code = addrregion
left	join MuhlMillProd..locators l on l.table_code = addrlocatr
left	join seasonal sa on sa.skey = addrkey
where	(trim(isnull(addrline1, '')) <> '' or trim(isnull(addrline2, '')) <> '' or trim(isnull(addrline3, '')) <> '' or
				trim(isnull(addrcity, '')) <> '' or trim(isnull(addrplace, '')) <> '' or trim(isnull(addrzipcod, '')) <> '' or trim(isnull(addrcntry, '')) <> '' )
and		t.table_val not like '%E-Mail%'
and		t.table_val not like '%Internet%'
and		t.table_val not like '%Phone%';

-->> check for double primaries
select	count(*) as numrows, ParentId
from	ContactPointAddress_load c
where	IsPrimary='true'
group by ParentId
having count(*)>1;

-->> check for dupes
select	count(*), ASLE_External_ID__c 
from	ContactPointAddress_load
group by ASLE_External_ID__c
having count(*)>1;

select * from ContactPointAddress_load where ParentId='001hR00000EXf2QQAT' and IsPrimary='true';

-->> get picklist values for custom fields (too many values, needs text field)
select distinct ASLE_County__c
from	ContactPointAddress_load;

select distinct ASLE_Locator__c
from	ContactPointAddress_load;

-->> some cleanup
update ContactPointAddress_load set CreatedDate = LastModifiedDate, LastModifiedDate = CreatedDate where LastModifiedDate < CreatedDate;
update ContactPointAddress_load set Country = 'United Kingdom' where Country = 'ENGLAND';
update ContactPointAddress_load set Country = 'Trinidad and Tobago' where Country = 'ARIMA';
update ContactPointAddress_load set Country = 'Kazakhstan' where Country = 'KAZAKSTAN';
update ContactPointAddress_load set Country = 'Korea, Republic of' where Country = 'KOREA'; 
update ContactPointAddress_load set Country = 'Philippines' where Country = 'PHILIPPINE ISLANDS';
update ContactPointAddress_load set Country = 'Panama' where Country = 'REPUBLICA DE PANAMA';
update ContactPointAddress_load set Country = 'Russian Federation' where Country = 'RUSSIA';
update ContactPointAddress_load set Country = 'Korea, Republic of' where Country = 'SOUTH KOREA';
update ContactPointAddress_load set Country = 'Eswatini' where Country = 'SWAZILAND';
update ContactPointAddress_load set Country = 'Bahamas' where Country = 'THE BAHAMAS';
update ContactPointAddress_load set Country = 'Netherlands' where Country = 'THE NETHERLANDS';
update ContactPointAddress_load set Country = 'Türkiye' where Country = 'TURKEY';
update ContactPointAddress_load set State = 'Federated Micronesia' where State = 'Federated States of Micronesia';


update ContactPointAddress_load set State = 'Armed Forces Americas' where State = 'Armed Forces California';
update ContactPointAddress_load set State = 'Armed Forces Americas' where State = 'Armed Forces Florida';
update ContactPointAddress_load set State = 'Armed Forces Americas' where State = 'Armed Forces New York';
update ContactPointAddress_load set State = 'Shanxi' where State = 'Shaanx';
update ContactPointAddress_load set State = 'US Virgin Islands' where State = 'Virgin Islands';
update ContactPointAddress_load set State = 'Ontario' where State='Canada';
update ContactPointAddress_load set City='Toronto',State='Ontario',PostalCode='M5H 2M5' where City='Toronto, Ontario M5H 2M5';
update ContactPointAddress_load set Country = 'Czech Republic' where Country = 'Czechoslovakia';
update ContactPointAddress_load set Country = 'Korea, Republic of' where Country = 'Democratic Republic of Korea';
update ContactPointAddress_load set Country = 'United Kingdom' where Country = 'England';
update ContactPointAddress_load set Country = 'Ghana' where Country = 'Ghana, West Africa';
update ContactPointAddress_load set Country = 'United Kingdom' where Country = 'Great Britain';
update ContactPointAddress_load set Country = 'China' where Country = 'Hong Kong';
update ContactPointAddress_load set Country = 'Korea, Republic of' where Country = 'Korea  (SOUTH)';
update ContactPointAddress_load set Country = 'Korea, Republic of' where Country = 'Korea, South';
update ContactPointAddress_load set Country = 'Netherlands' where Country = 'Netherlands Antilles';
update ContactPointAddress_load set Country = 'China' where Country = 'Peoples Republic of China';
update ContactPointAddress_load set Country = '	Russian Federation' where Country = 'Russia';
update ContactPointAddress_load set Country = 'United Kingdom' where Country = 'Scotland';
update ContactPointAddress_load set Country = 'Slovakia' where Country = 'Slovak Republic';
update ContactPointAddress_load set Country = '' where Country = 'South-West Africa';
update ContactPointAddress_load set Country = '	Russian Federation' where Country = 'Soviet Union';
update ContactPointAddress_load set Country = 'Syrian Arab Republic' where Country = 'Syria';
update ContactPointAddress_load set Country = 'Chinese Taipei' where Country = 'Taiwan, Republic of China';
update ContactPointAddress_load set Country = 'Tanzania, United Republic of' where Country = 'Tanzania';
update ContactPointAddress_load set Country = 'Venezuela, Bolivarian Republic of' where Country = 'Venezuela';
update ContactPointAddress_load set Country = '	Viet Nam' where Country = 'Vietnam';
update ContactPointAddress_load set Country = 'Zambia' where Country = 'Zambia, Africa';
update ContactPointAddress_load set Country = 'United States' where State='New Jersey' and Country='Vietnam';
	
update ContactPointAddress_load set ActiveToDate = ActiveFromDate where ActiveToDate > '1/1/2500' and ActiveFromDate is not null;
update ContactPointAddress_load set ActiveFromDate = null where ActiveFromDate > '1/1/2500' ;
update ContactPointAddress_load set ActiveToDate=ActiveFromDate where ISDATE(ActiveToDate)=0 and ActiveToDate is not null;

update ContactPointAddress_load set Street = replace(Street, char(1), ' ') where Street like '%' + char(1) + '%';
update ContactPointAddress_load set Street = replace(Street, char(2), ' ') where Street like '%' + char(2) + '%';
update ContactPointAddress_load set Street = replace(Street, char(3), ' ') where Street like '%' + char(3) + '%';
update ContactPointAddress_load set Street = replace(Street, char(4), ' ') where Street like '%' + char(4) + '%';
update ContactPointAddress_load set Street = replace(Street, char(5), ' ') where Street like '%' + char(5) + '%';
update ContactPointAddress_load set Street = replace(Street, char(6), ' ') where Street like '%' + char(6) + '%';
update ContactPointAddress_load set Street = replace(Street, char(7), ' ') where Street like '%' + char(7) + '%';
update ContactPointAddress_load set Street = replace(Street, char(8), ' ') where Street like '%' + char(8) + '%';
update ContactPointAddress_load set Street = replace(Street, char(11), ' ') where Street like '%' + char(11) + '%';
update ContactPointAddress_load set Street = replace(Street, char(12), ' ') where Street like '%' + char(12) + '%';
update ContactPointAddress_load set Street = replace(Street, char(14), ' ') where Street like '%' + char(14) + '%';
update ContactPointAddress_load set Street = replace(Street, char(15), ' ') where Street like '%' + char(15) + '%';
update ContactPointAddress_load set Street = replace(Street, char(16), ' ') where Street like '%' + char(16) + '%';
update ContactPointAddress_load set Street = replace(Street, char(17), ' ') where Street like '%' + char(17) + '%';
update ContactPointAddress_load set Street = replace(Street, char(18), ' ') where Street like '%' + char(18) + '%';
update ContactPointAddress_load set Street = replace(Street, char(19), ' ') where Street like '%' + char(19) + '%';
update ContactPointAddress_load set Street = replace(Street, char(20), ' ') where Street like '%' + char(20) + '%';
update ContactPointAddress_load set Street = replace(Street, char(21), ' ') where Street like '%' + char(21) + '%';
update ContactPointAddress_load set Street = replace(Street, char(22), ' ') where Street like '%' + char(22) + '%';
update ContactPointAddress_load set Street = replace(Street, char(23), ' ') where Street like '%' + char(23) + '%';
update ContactPointAddress_load set Street = replace(Street, char(24), ' ') where Street like '%' + char(24) + '%';
update ContactPointAddress_load set Street = replace(Street, char(25), ' ') where Street like '%' + char(25) + '%';
update ContactPointAddress_load set Street = replace(Street, char(26), ' ') where Street like '%' + char(26) + '%';
update ContactPointAddress_load set Street = replace(Street, char(27), ' ') where Street like '%' + char(27) + '%';
update ContactPointAddress_load set Street = replace(Street, char(28), ' ') where Street like '%' + char(28) + '%';
update ContactPointAddress_load set Street = replace(Street, char(29), ' ') where Street like '%' + char(29) + '%';
update ContactPointAddress_load set Street = replace(Street, char(30), ' ') where Street like '%' + char(30) + '%';
update ContactPointAddress_load set Street = replace(Street, char(31), ' ') where Street like '%' + char(31) + '%';


-->> get records for loading
select * from ContactPointAddress_load;

--================================================================================================
-- PART TWO: handle errors
-- import error file to ContactPointAddress_errors
--================================================================================================
select distinct substring(ERROR,1,charindex(':',ERROR,1))from ContactPointAddress_errors;

-->> errors to handle...
--CANNOT_EXECUTE_FLOW_TRIGGER:
--FIELD_CUSTOM_VALIDATION_EXCEPTION:
--FIELD_INTEGRITY_EXCEPTION:

select distinct AddressType from ContactPointAddress_errors where ERROR like 'CANNOT_EXECUTE_FLOW_TRIGGER:%';

select distinct AddressType from ContactPointAddress_errors where ERROR like 'FIELD_CUSTOM_VALIDATION_EXCEPTION:%';

select distinct ERROR from ContactPointAddress_errors where ERROR like 'FIELD_INTEGRITY_EXCEPTION:%';

select distinct State from ContactPointAddress_errors where ERROR like '%There''s a problem with this state%';

select * from ContactPointAddress_errors where State='Canada'

select * from ContactPointAddress_errors where State='Shaanx'

select distinct State,Country from ContactPointAddress_errors where ERROR like '%There''s a problem with this country%';

select * from ContactPointAddress_errors where State='New Jersey' and Country='Vietnam';

select * from ContactPointAddress_errors where ERROR like '%There''s a problem%';

select * from ContactPointAddress_errors where ERROR like '%Please select a state%';

select ActiveToDate from ContactPointAddress_errors where ERROR like 'FIELD_INTEGRITY_EXCEPTION:Active to Date: invalid date:%';






