/***************************************************************************************
        PURPOSE: Populate the PP Ocurrence object
         CLIENT: Muhlenburg
         AUTHOR: John Barone
        CREATED: 10-16-2026
  LAST MODIFIED: 10-16-2026

   SCRIPT NOTES:
     1. The following Millennium tables are processed in this script
        - finance
        - custom prospect
     2. See script 30 for full prospect analysis mappings.
   
 SCRIPT HISTORY:
     10-16-2026: Original version
     
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
ALTER TABLE PartyPhilanthropicOccurrence_load_finance ALTER COLUMN ASLE_External_Id__c VARCHAR(50) NOT NULL;
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
SOURCE TYPES: map to OtherSource field
cprscomm: Custom Prospect Comment
cprstext1: Custom Prospect Text 1
cprstext2: Custom Prospect Text 2
cprstext3: Custom Prospect Text 3
No text field filled: Custom Propect Details


MAPS:
cprsdate1: Change date (custom field)
cprsdate2: Custom Date 2 (custom field)
cprsdate3: Custom Date 3 (custom field)
cprslook1: Occurrence Type
cprslook2: Custom Lookup 2  (custom field)
cprslook3: Custom Lookup 3  (custom field)
cprslook4: Confirmed?  (custom field - 1 = true, 2 = false)
cprsmoney1: Custom Amount 1 (custom field)
cprsmoney2: Custom Amount 2 (custom field)
cprsmoney3: Custom Amount 3 (custom field)
cprssource: Source Type (add values to picklist under "Note" record type)

*/

SELECT CAST(NULL AS NCHAR(18))                                AS Id
     , CAST(NULL AS VARCHAR(4000))                            AS Error
     , 'NOTE_C_' + CAST(t.cprskey AS VARCHAR(25))             AS ASLE_External_Id__c
     , a.Id                                                   AS AccountId
     , t.cprsdate1                                            AS ASLE_Change_Date__c
     , t.cprsdate2                                            AS ASLE_Custom_Date_2__c
     , t.cprsdate3                                            AS ASLE_Custom_Date_3__c
     , TRIM(l2.table_val)                                     AS ASLE_Custom_Lookup_2__c
     , TRIM(l3.table_val)                                     AS ASLE_Custom_Lookup_3__c
     , IIF(t.cprslook4 = '1', 'true', 'false')                AS ASLE_Confirmed__c
     , t.cprsmoney1                                           AS ASLE_Custom_Amount__1
     , t.cprsmoney2                                           AS ASLE_Custom_Amount__2
     , t.cprsmoney3                                           AS ASLE_Custom_Amount__3
     , TRIM(l1.table_val)                                     AS OccurrenceType
     , 'Custom Prospect Comment'                              AS OtherSource
     , TRIM(st.table_val)                                     AS SourceType
     , rp.Id                                                  AS PartyPhilanthropicRsrchPrflId
     , rt.Id                                                  AS RecordTypeId
     , TRIM(t.cprscomm)                                       AS Summary
     , t.cprscrdate                                           AS CreatedDate
     , t.cprsdate                                             AS LastModifiedDate
     , 'customprospect table'                                 AS ASLE_Millennium_Source__c
     , t.cprsid                                               AS coreid
--INTO   PartyPhilanthropicOccurrence_load_customprospect
FROM   mill_customprospect t
JOIN   PartyPhilanthropicRsrchPrfl_load rp
  ON   rp.acct_xid = t.cprsid COLLATE Latin1_General_BIN
JOIN   sf_recordtypes rt
  ON   rt.SObjectType = 'PartyPhilanthropicOccurrence'
 AND   rt.Name = 'Philanthropic Notes'
JOIN   mill_source_types st
  ON   st.table_code = t.cprssource
LEFT JOIN mill_customprospect_lookup1 l1
  ON   l1.table_code = t.cprslook1
LEFT JOIN mill_customprospect_lookup2 l2
  ON   l2.table_code = t.cprslook2
LEFT JOIN mill_customprospect_lookup3 l3
  ON   l3.table_code = t.cprslook3
LEFT JOIN sf_accounts a
  ON   a.ASLE_External_ID_c = t.cprsid
WHERE  LEN(t.cprscomm) > 0

INSERT INTO PartyPhilanthropicOccurrence_load_customprospect
SELECT CAST(NULL AS NCHAR(18))                                AS Id
     , CAST(NULL AS VARCHAR(4000))                            AS Error
     , 'NOTE_1_' + CAST(t.cprskey AS VARCHAR(25))             AS ASLE_External_Id__c
     , a.Id                                                   AS AccountId
     , t.cprsdate1                                            AS ASLE_Change_Date__c
     , t.cprsdate2                                            AS ASLE_Custom_Date_2__c
     , t.cprsdate3                                            AS ASLE_Custom_Date_3__c
     , TRIM(l2.table_val)                                     AS ASLE_Custom_Lookup_2__c
     , TRIM(l3.table_val)                                     AS ASLE_Custom_Lookup_3__c
     , IIF(t.cprslook4 = '1', 'true', 'false')                AS ASLE_Confirmed__c
     , t.cprsmoney1                                           AS ASLE_Custom_Amount__1
     , t.cprsmoney2                                           AS ASLE_Custom_Amount__2
     , t.cprsmoney3                                           AS ASLE_Custom_Amount__3
     , TRIM(l1.table_val)                                     AS OccurrenceType
     , 'Custom Prospect Text 1'                               AS OtherSource
     , TRIM(st.table_val)                                     AS SourceType
     , rp.Id                                                  AS PartyPhilanthropicRsrchPrflId
     , rt.Id                                                  AS RecordTypeId
     , TRIM(t.cprstext1)                                      AS Summary
     , t.cprscrdate                                           AS CreatedDate
     , t.cprsdate                                             AS LastModifiedDate
     , 'customprospect table'                                 AS ASLE_Millennium_Source__c
     , t.cprsid                                               AS coreid
FROM   mill_customprospect t
JOIN   PartyPhilanthropicRsrchPrfl_load rp
  ON   rp.acct_xid = t.cprsid COLLATE Latin1_General_BIN
JOIN   sf_recordtypes rt
  ON   rt.SObjectType = 'PartyPhilanthropicOccurrence'
 AND   rt.Name = 'Philanthropic Notes'
JOIN   mill_source_types st
  ON   st.table_code = t.cprssource
LEFT JOIN mill_customprospect_lookup1 l1
  ON   l1.table_code = t.cprslook1
LEFT JOIN mill_customprospect_lookup2 l2
  ON   l2.table_code = t.cprslook2
LEFT JOIN mill_customprospect_lookup3 l3
  ON   l3.table_code = t.cprslook3
LEFT JOIN sf_accounts a
  ON   a.ASLE_External_ID_c = t.cprsid
WHERE  LEN(t.cprstext1) > 0

INSERT INTO PartyPhilanthropicOccurrence_load_customprospect
SELECT CAST(NULL AS NCHAR(18))                                AS Id
     , CAST(NULL AS VARCHAR(4000))                            AS Error
     , 'NOTE_2_' + CAST(t.cprskey AS VARCHAR(25))             AS ASLE_External_Id__c
     , a.Id                                                   AS AccountId
     , t.cprsdate1                                            AS ASLE_Change_Date__c
     , t.cprsdate2                                            AS ASLE_Custom_Date_2__c
     , t.cprsdate3                                            AS ASLE_Custom_Date_3__c
     , TRIM(l2.table_val)                                     AS ASLE_Custom_Lookup_2__c
     , TRIM(l3.table_val)                                     AS ASLE_Custom_Lookup_3__c
     , IIF(t.cprslook4 = '1', 'true', 'false')                AS ASLE_Confirmed__c
     , t.cprsmoney1                                           AS ASLE_Custom_Amount__1
     , t.cprsmoney2                                           AS ASLE_Custom_Amount__2
     , t.cprsmoney3                                           AS ASLE_Custom_Amount__3
     , TRIM(l1.table_val)                                     AS OccurrenceType
     , 'Custom Prospect Text 2'                               AS OtherSource
     , TRIM(st.table_val)                                     AS SourceType
     , rp.Id                                                  AS PartyPhilanthropicRsrchPrflId
     , rt.Id                                                  AS RecordTypeId
     , TRIM(t.cprstext2)                                      AS Summary
     , t.cprscrdate                                           AS CreatedDate
     , t.cprsdate                                             AS LastModifiedDate
     , 'customprospect table'                                 AS ASLE_Millennium_Source__c
     , t.cprsid                                               AS coreid
FROM   mill_customprospect t
JOIN   PartyPhilanthropicRsrchPrfl_load rp
  ON   rp.acct_xid = t.cprsid COLLATE Latin1_General_BIN
JOIN   sf_recordtypes rt
  ON   rt.SObjectType = 'PartyPhilanthropicOccurrence'
 AND   rt.Name = 'Philanthropic Notes'
JOIN   mill_source_types st
  ON   st.table_code = t.cprssource
LEFT JOIN mill_customprospect_lookup1 l1
  ON   l1.table_code = t.cprslook1
LEFT JOIN mill_customprospect_lookup2 l2
  ON   l2.table_code = t.cprslook2
LEFT JOIN mill_customprospect_lookup3 l3
  ON   l3.table_code = t.cprslook3
LEFT JOIN sf_accounts a
  ON   a.ASLE_External_ID_c = t.cprsid
WHERE  LEN(t.cprstext2) > 0

INSERT INTO PartyPhilanthropicOccurrence_load_customprospect
SELECT CAST(NULL AS NCHAR(18))                                AS Id
     , CAST(NULL AS VARCHAR(4000))                            AS Error
     , 'NOTE_3_' + CAST(t.cprskey AS VARCHAR(25))             AS ASLE_External_Id__c
     , a.Id                                                   AS AccountId
     , t.cprsdate1                                            AS ASLE_Change_Date__c
     , t.cprsdate2                                            AS ASLE_Custom_Date_2__c
     , t.cprsdate3                                            AS ASLE_Custom_Date_3__c
     , TRIM(l2.table_val)                                     AS ASLE_Custom_Lookup_2__c
     , TRIM(l3.table_val)                                     AS ASLE_Custom_Lookup_3__c
     , IIF(t.cprslook4 = '1', 'true', 'false')                AS ASLE_Confirmed__c
     , t.cprsmoney1                                           AS ASLE_Custom_Amount__1
     , t.cprsmoney2                                           AS ASLE_Custom_Amount__2
     , t.cprsmoney3                                           AS ASLE_Custom_Amount__3
     , TRIM(l1.table_val)                                     AS OccurrenceType
     , 'Custom Prospect Text 3'                               AS OtherSource
     , TRIM(st.table_val)                                     AS SourceType
     , rp.Id                                                  AS PartyPhilanthropicRsrchPrflId
     , rt.Id                                                  AS RecordTypeId
     , TRIM(t.cprstext3)                                      AS Summary
     , t.cprscrdate                                           AS CreatedDate
     , t.cprsdate                                             AS LastModifiedDate
     , 'customprospect table'                                 AS ASLE_Millennium_Source__c
     , t.cprsid                                               AS coreid
FROM   mill_customprospect t
JOIN   PartyPhilanthropicRsrchPrfl_load rp
  ON   rp.acct_xid = t.cprsid COLLATE Latin1_General_BIN
JOIN   sf_recordtypes rt
  ON   rt.SObjectType = 'PartyPhilanthropicOccurrence'
 AND   rt.Name = 'Philanthropic Notes'
JOIN   mill_source_types st
  ON   st.table_code = t.cprssource
LEFT JOIN mill_customprospect_lookup1 l1
  ON   l1.table_code = t.cprslook1
LEFT JOIN mill_customprospect_lookup2 l2
  ON   l2.table_code = t.cprslook2
LEFT JOIN mill_customprospect_lookup3 l3
  ON   l3.table_code = t.cprslook3
LEFT JOIN sf_accounts a
  ON   a.ASLE_External_ID_c = t.cprsid
WHERE  LEN(t.cprstext3) > 0

INSERT INTO PartyPhilanthropicOccurrence_load_customprospect
SELECT CAST(NULL AS NCHAR(18))                                AS Id
     , CAST(NULL AS VARCHAR(4000))                            AS Error
     , 'NOTE_0_' + CAST(t.cprskey AS VARCHAR(25))             AS ASLE_External_Id__c
     , a.Id                                                   AS AccountId
     , t.cprsdate1                                            AS ASLE_Change_Date__c
     , t.cprsdate2                                            AS ASLE_Custom_Date_2__c
     , t.cprsdate3                                            AS ASLE_Custom_Date_3__c
     , TRIM(l2.table_val)                                     AS ASLE_Custom_Lookup_2__c
     , TRIM(l3.table_val)                                     AS ASLE_Custom_Lookup_3__c
     , IIF(t.cprslook4 = '1', 'true', 'false')                AS ASLE_Confirmed__c
     , t.cprsmoney1                                           AS ASLE_Custom_Amount__1
     , t.cprsmoney2                                           AS ASLE_Custom_Amount__2
     , t.cprsmoney3                                           AS ASLE_Custom_Amount__3
     , TRIM(l1.table_val)                                     AS OccurrenceType
     , 'Custom Propect Details'                               AS OtherSource
     , TRIM(st.table_val)                                     AS SourceType
     , rp.Id                                                  AS PartyPhilanthropicRsrchPrflId
     , rt.Id                                                  AS RecordTypeId
     , t.cprscrdate                                           AS CreatedDate
     , t.cprsdate                                             AS LastModifiedDate
     , 'customprospect table'                                 AS ASLE_Millennium_Source__c
     , t.cprsid                                               AS coreid
     , t.cprscomm, t.cprstext1, t.cprstext2, t.cprstext3
FROM   mill_customprospect t
JOIN   PartyPhilanthropicRsrchPrfl_load rp
  ON   rp.acct_xid = t.cprsid COLLATE Latin1_General_BIN
JOIN   sf_recordtypes rt
  ON   rt.SObjectType = 'PartyPhilanthropicOccurrence'
 AND   rt.Name = 'Philanthropic Notes'
JOIN   mill_source_types st
  ON   st.table_code = t.cprssource
LEFT JOIN mill_customprospect_lookup1 l1
  ON   l1.table_code = t.cprslook1
LEFT JOIN mill_customprospect_lookup2 l2
  ON   l2.table_code = t.cprslook2
LEFT JOIN mill_customprospect_lookup3 l3
  ON   l3.table_code = t.cprslook3
LEFT JOIN sf_accounts a
  ON   a.ASLE_External_ID_c = t.cprsid
WHERE  LEN(ISNULL(TRIM(t.cprscomm), '')) = 0
  AND  LEN(ISNULL(TRIM(t.cprstext1), '')) = 0
  AND  LEN(ISNULL(TRIM(t.cprstext2), '')) = 0
  AND  LEN(ISNULL(TRIM(t.cprstext3), '')) = 0

-- Pull out records without an account for further review
BEGIN TRANSACTION;
DROP TABLE IF EXISTS err_customprospect_no_acct

SELECT *
INTO   err_customprospect_no_acct
FROM   PartyPhilanthropicOccurrence_load_customprospect
WHERE  AccountId IS NULL;

DELETE FROM PartyPhilanthropicOccurrence_load_customprospect WHERE AccountId IS NULL;

COMMIT TRANSACTION;

-- create primary key
ALTER TABLE PartyPhilanthropicOccurrence_load_customprospect ALTER COLUMN ASLE_External_Id__c VARCHAR(50) NOT NULL;
GO

ALTER TABLE PartyPhilanthropicOccurrence_load_finance
ADD CONSTRAINT pk_PartyPhilanthropicOccurrence_load_customprospect PRIMARY KEY(ASLE_External_Id__c);
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
-- Millennium attribute (prospect-related)
---------------------------------------------------------------------------------



