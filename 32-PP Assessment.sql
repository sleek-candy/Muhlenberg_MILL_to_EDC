/***************************************************************************************
        PURPOSE: Populate the PP Ocurrence object
         CLIENT: Muhlenburg
         AUTHOR: John Barone
        CREATED: 10-16-2026
  LAST MODIFIED: 10-16-2026

   SCRIPT NOTES:
     1. The following Millennium tables are processed in this script
        - demograph
        - rating

     2. See script 30 for full prospect analysis mappings.
   
 SCRIPT HISTORY:
     10-16-2026: Original version
     
*** CONFIDENTIAL - ALL SOURCE CODE, SCRIPTS, PROGRAMS AND RELATED ARTIFACTS CONTAINED
    HEREIN IS THE PROPERTY OF SLEEK CONSULTING UNLESS OTHERWISE NOTED ***
****************************************************************************************/

---------------------------------------------------------------------------------
-- Millennium demograph table
---------------------------------------------------------------------------------
drop table if exists PartyPhilanthropicAssessment_load_demogrph;

--429,663
SELECT CAST(NULL AS NCHAR(18)) AS Id
     , CAST(NULL AS VARCHAR(4000)) AS Error
     , 'dp_' + CAST(t.demokey AS VARCHAR(50)) AS ASLE_External_Id__c
     , trim(t.demovalue) AS ShortSummary
     , t.demordate AS [Date]
     , t.democomm AS ExtendedSummary
     , a.Id                                      AS AccountId
     , rp.Id                                                AS PartyPhilanthropicRsrchPrflId
    , IIF(t.demoactive = 'Y', 'true', 'false') AS ASLE_Active__c
    , 'Demographic Profile' AS AssessmentType
    , trim(dt.table_val) AS ASLE_Assessment_Subtype__c
    , trim(rc.table_val)   AS ASLE_Rating_Company__c
    , trim(s.table_val) AS ASLE_Source__c
     , t.democrdate                               AS LastModifiedById
     , t.demodate                                                   AS LastModifiedDate
INTO PartyPhilanthropicAssessment_load_demogrph
FROM   mill_demogrph t
join PartyPhilanthropicRsrchPrfl_load rp
  ON rp.acct_xid = t.demoid
LEFT JOIN   mill_source_types s
  ON  s.table_code = t.demosource
LEFT JOIN mill_demographic_type AS dt
  ON dt.table_code = t.demotype
left join sf_accounts a
  ON a.ASLE_External_ID_c = t.demoid
left join mill_rating_companies rc
  ON rc.table_code = t.demortngco;

-- Pull out records without an account for further review
BEGIN TRANSACTION;
DROP TABLE IF EXISTS err_demogrph_no_acct

SELECT *
INTO   err_demogrph_no_acct
FROM   PartyPhilanthropicAssessment_load_demogrph
WHERE  AccountId IS NULL;

DELETE FROM PartyPhilanthropicAssessment_load_demogrph WHERE AccountId IS NULL;

COMMIT TRANSACTION;

-- create primary key
ALTER TABLE PartyPhilanthropicAssessment_load_demogrph ALTER COLUMN ASLE_External_Id__c VARCHAR(50) NOT NULL;
GO

ALTER TABLE PartyPhilanthropicAssessment_load_demogrph
ADD CONSTRAINT pk_PartyPhilanthropicAssessment_load_demogrph PRIMARY KEY(ASLE_External_Id__c);
GO

/*****
Upload using Python utility
Command: sfobjectload PartyPhilanthropicAssessment PartyPhilanthropicAssessment_load_demogrph externalIdField=ASLE_External_Id__c srcLogField=Error
*****/

SELECT *
FROM   PartyPhilanthropicAssessment_load_demogrph
WHERE  Id IS NULL
ORDER BY Error;


---------------------------------------------------------------------------------
-- Millennium rating table
---------------------------------------------------------------------------------
DROP TABLE IF EXISTS PartyPhilanthropicAssessment_load_rating;

SELECT CAST(NULL AS NCHAR(18)) AS Id
     , CAST(NULL AS VARCHAR(4000)) AS Error
     , 'rtng_' + CAST(t.ratekey AS VARCHAR(50)) AS ASLE_External_Id__c
    , t.ratebegin AS ResearchStartDate
    , t.ratebegin AS ResearchEndDate
     , t.ratedate1 AS [Date]
     , TRIM(t.ratecomm) AS ExtendedSummary
     , a.Id                                      AS AccountId
     , rp.Id                                                AS PartyPhilanthropicRsrchPrflId
    , IIF(t.rateflag = 'Y', 'true', 'false') AS ASLE_Active__c
    , 'Rating' AS AssessmentType
    , trim(s.table_val) AS ASLE_Source__c
    , c.Id AS ASLE_Campaign__c
    , TRIM(t.ratecampyr) AS ASLE_Campaign_Year__c
    , trim(rs.table_code)   AS ASLE_Inclination_to_Give
    , t.rateaskamt AS ASLE_Ask_Amount__c
    , trim(dr.table_val) AS ASLE_Ask_Rating__c
    , trim(cl.table_val) AS ASLE_Cultivation_Level__c
    , trim(rs.table_val) AS ASLE_Rating_Status__c
    , trim(l2.table_val) AS ASLE_Planned_Giving_Rating__c
    , trim(l1.table_val) AS ASLE_Custom_Lookup_1__c
     , t.ratecrdate                               AS LastModifiedById
     , t.ratedate                                                   AS LastModifiedDate
INTO PartyPhilanthropicAssessment_load_rating
FROM   mill_rating t
join PartyPhilanthropicRsrchPrfl_load rp
  ON rp.acct_xid = t.rateid
left join sf_campaigns c
  ON c.ASLE_External_Id_c = t.ratecamp COLLATE LATIN1_GENERAL_BIN
left join mill_rating_status rs
  ON rs.table_code = t.ratestatus
left join mill_donor_rating dr
  ON dr.table_code = t.rateaskrat
left join mill_cultivation cl
  ON cl.table_code = t.ratecultiv
LEFT JOIN   mill_source_types s
  ON  s.table_code = t.ratesource
left join mill_rating_lookup1 l1
  ON l1.table_code = t.ratelook1
left join mill_rating_lookup2 l2
  ON l2.table_code = t.ratelook2
left join sf_accounts a
  ON a.ASLE_External_ID_c = t.rateid;

-- Pull out records without an account for further review
BEGIN TRANSACTION;
DROP TABLE IF EXISTS err_rating_no_acct

SELECT *
INTO   err_rating_no_acct
FROM   PartyPhilanthropicAssessment_load_rating
WHERE  AccountId IS NULL;

DELETE FROM PartyPhilanthropicAssessment_load_rating WHERE AccountId IS NULL;

COMMIT TRANSACTION;

-- create primary key
ALTER TABLE PartyPhilanthropicAssessment_load_rating ALTER COLUMN ASLE_External_Id__c VARCHAR(50) NOT NULL;
GO

ALTER TABLE PartyPhilanthropicAssessment_load_rating
ADD CONSTRAINT pk_PartyPhilanthropicAssessment_load_rating PRIMARY KEY(ASLE_External_Id__c);
GO

/*****
Upload using Python utility
Command: sfobjectload PartyPhilanthropicAssessment PartyPhilanthropicAssessment_load_rating externalIdField=ASLE_External_Id__c srcLogField=Error
*****/

SELECT *
FROM   PartyPhilanthropicAssessment_load_rating
WHERE  Id IS NULL
ORDER BY Error;







