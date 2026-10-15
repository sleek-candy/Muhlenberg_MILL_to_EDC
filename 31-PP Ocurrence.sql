/***************************************************************************************
        PURPOSE: Populate the PP Ocurrence object
         CLIENT: Muhlenburg
         AUTHOR: John Barone
        CREATED: 10-15-2026
  LAST MODIFIED: 10-15-2026

   SCRIPT NOTES:
     See script 30 for full prospect analysis mappings.
     

 SCRIPT HISTORY:
     10-15-2026: Original version
     
*** CONFIDENTIAL - ALL SOURCE CODE, SCRIPTS, PROGRAMS AND RELATED ARTIFACTS CONTAINED
    HEREIN IS THE PROPERTY OF SLEEK CONSULTING UNLESS OTHERWISE NOTED ***
****************************************************************************************/

/*
     - PP Occurence
         - finance
         - customprospect
         - attribute

       -- SI
         - notes
         - other philanthropic_affinity
         - philanthropic_interest
         - wealth_assets
*/

/* 
METADATA CHANGES
  CUSTOM FIELDS
    1. ASLE_Millennium_Source__c: Millennium location (typically table)
        store the source of the data to inform workshop mapping.
    2. ASLE_Description__c
    3. ASLE_Active__c
    4. ASLE_Confirmed__c
  
  PICKLISTS
    1. OccurrenceType: Add values in financial_types which are in the finance table
    2. SourceType: Add values from source_types which are in the finance table
*/

---------------------------------------------------------------------------------
-- Millennium finance table
---------------------------------------------------------------------------------
DROP TABLE IF EXISTS PartyPhilanthropicOccurrence_load_finance;

-- 22,104
SELECT CAST(NULL AS NCHAR(18))     AS Id
     , CAST(NULL AS VARCHAR(4000)) AS Error
     , 'FINC_' + CAST(t.finkey AS VARCHAR(25))            AS ASLE_External_Id__c
     , a.Id                                                AS AccountId
     , t.finevaldt                                                          AS DateCollected
     , t.finamount                                               AS EstimatedValue
     , ft.table_val                                                           AS OccurrenceType
     , IIF(t.finratcomp = 'we', 'Wealth Engine', NULL) AS OtherSource
     , st.table_val                                              AS SourceType
     , rp.Id                                                          AS PartyPhilanthropicRsrchPrflId
     , rt.Id                                                          AS RecordTypeId
     , 'Wealth' AS ResearchType
     , t.fincomm                                                     AS Summary
     , t.fincrdate                                                             AS CreatedDate
     , t.findate                                                              AS LastModifiedDate
    , t.findescr AS ASLE_Description__c
    , t.finacqdt AS ASLE_Acquired_Date__c
    , IIF(t.finactive = 'Y', 'true', 'false') AS ASLE_Active__c
    , IIF(t.finlook1 = '1', 'true', 'false') AS ASLE_Confirmed__c
    ,  'finance table' AS ASLE_Millennium_Source__c
    , t.finid as coreid
INTO   PartyPhilanthropicOccurrence_load_finance
FROM   mill_finance t
JOIN   PartyPhilanthropicRsrchPrfl_load rp
  ON   rp.acct_xid = t.finid COLLATE Latin1_General_BIN
JOIN   mill_financial_types ft
  ON   ft.table_code = t.fintype
JOIN   sf_recordtypes rt
  ON   rt.SObjectType = 'PartyPhilanthropicOccurrence'
 AND   rt.Name = 'Wealth'
JOIN   mill_source_types st
  ON   st.table_code = t.finsource
LEFT JOIN   sf_accounts a
  ON   a.ASLE_External_ID_c = t.finid;
GO

-- Pull out records without an account for further review
BEGIN TRANSACTION;
DROP TABLE IF EXISTS err_finance_no_acct

SELECT *
INTO   err_finance_no_acct
FROM   PartyPhilanthropicOccurrence_load_finance
WHERE  AccountId IS NULL;

DELETE FROM PartyPhilanthropicOccurrence_load_finance WHERE AccountId IS NULL;

COMMIT TRANSACTION;

-- create primary key
ALTER TABLE PartyPhilanthropicOccurrence_load_finance ALTER COLUMN ASLE_External_Id__c VARCHAR(25) NOT NULL;
GO

ALTER TABLE PartyPhilanthropicOccurrence_load_finance
ADD CONSTRAINT pk_PartyPhilanthropicOccurrence_load_finance PRIMARY KEY(ASLE_External_Id__c);
GO

/*****
Upload using Python utility
Command: sfobjectload PartyPhilanthropicOccurrence PartyPhilanthropicOccurrence_load_finance externalIdField=ASLE_External_Id__c srcLogField=Error
*****/

SELECT *
FROM   PartyPhilanthropicOccurrence_load_finance
WHERE  Id IS NULL
ORDER BY Error


---------------------------------------------------------------------------------
-- Millennium customprospect table
---------------------------------------------------------------------------------
DROP TABLE IF EXISTS PartyPhilanthropicOccurrence_load_customprospect;




/*
TYPES:
cprscomm: Prospect Comment
cprstext1: Custom Text 1
cprstext2: Custom Text 2
cprstext3: Custom Text 3


MAPS
cprsdate1: Change date (custom field)
cprsdate2: Custom Date 2 (custom field)
cprsdate3: Custom Date 3 (custom field)
cprslook1: Occurrence Type
cprslook2: Area  (prob custom field)
cprslook3: Area Subtype  (prob custom field)
cprslook4: Confirmed?  (custom field - 1 = true, 2 = false)
cprsmoney1: Custom Amount 1 (custom field)
cprsmoney2: Custom Amount 2 (custom field)
cprsmoney3: Custom Amount 3 (custom field)
cprssource: Source Type (add values to picklist under "Note" record type)
*/



-- DEV IN PRGRESS: Do in separate tab
-- Putting here so that I don't lose it

/*
TYPES:
cprscomm: Prospect Comment
cprstext1: Custom Text 1
cprstext2: Custom Text 2
cprstext3: Custom Text 3
No text field filled: Custom Propect Details


MAPS:
cprsdate1: Change date (custom field)
cprsdate2: Custom Date 2 (custom field)
cprsdate3: Custom Date 3 (custom field)
cprslook1: Occurrence Type
cprslook2: Area  (prob custom field)
cprslook3: Area Subtype  (prob custom field)
cprslook4: Confirmed?  (custom field - 1 = true, 2 = false)
cprsmoney1: Custom Amount 1 (custom field)
cprsmoney2: Custom Amount 2 (custom field)
cprsmoney3: Custom Amount 3 (custom field)
cprssource: Source Type (add values to picklist under "Note" record type)

*/

-- 14,687
SELECT CAST(NULL AS NCHAR(18))     AS Id
     , CAST(NULL AS VARCHAR(4000)) AS Error
     , 'NOTE_1_' + CAST(t.finkey AS VARCHAR(25))            AS ASLE_External_Id__c
     , a.Id                                                AS AccountId
     , t.finevaldt                                                          AS DateCollected
     , t.finamount                                               AS EstimatedValue
     , ft.table_val                                                           AS OccurrenceType
     , IIF(t.finratcomp = 'we', 'Wealth Engine', NULL) AS OtherSource
     , st.table_val                                              AS SourceType
     , rp.Id                                                          AS PartyPhilanthropicRsrchPrflId
     , rt.Id                                                          AS RecordTypeId
     , 'Wealth' AS ResearchType
     , t.fincomm                                                     AS Summary
     , t.fincrdate                                                             AS CreatedDate
     , t.findate                                                              AS LastModifiedDate
    , t.findescr AS ASLE_Description__c
    , t.finacqdt AS ASLE_Acquired_Date__c
    , IIF(t.finactive = 'Y', 'true', 'false') AS ASLE_Active__c
    , IIF(t.finlook1 = '1', 'true', 'false') AS ASLE_Confirmed__c
    ,  'finance table' AS ASLE_Millennium_Source__c
    , t.finid as coreid
--INTO   PartyPhilanthropicOccurrence_load_customprospect

select count(*)
FROM   mill_customprospect t
JOIN   PartyPhilanthropicRsrchPrfl_load rp
  ON   rp.acct_xid = t.cprsid COLLATE Latin1_General_BIN


JOIN   sf_recordtypes rt
  ON   rt.SObjectType = 'PartyPhilanthropicOccurrence'
 AND   rt.Name = 'Wealth'
JOIN   mill_source_types st
  ON   st.table_code = t.finsource
LEFT JOIN   sf_accounts a
  ON   a.ASLE_External_ID_c = t.finid


-- Are there any records without notes?  - yes
select count(*) FROM mill_customprospect
select count(*) from mill_customprospect where len(cprstext1) > 0 or len(cprstext2) > 0 or len(cprstext3) > 0 or len(cprscomm) > 0




