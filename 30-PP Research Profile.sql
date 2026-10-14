/***************************************************************************************
        PURPOSE: Populate the PP Research Profile object
         CLIENT: Muhlenburg
         AUTHOR: John Barone
        CREATED: 10-14-2026
  LAST MODIFIED: 10-14-2026

   SCRIPT NOTES:
     This script generates one base Research Profile row per Account. Full info are in
     the PP Assessment or PP Occurence objects.
     
   Mill NOTES:
     - Additional info in discovery section
     - Pull info from the following tables
        - attribute  (group = 'pt')
        - customprospect
        - demogrph
        - donor
        - finance
        - media
        - rating
        - research_source
        - screener

     customprospect: Not sure how this will migrate until data review
     donor: This is supposed to be a glue table. It may not map anywhere in particular
     
   OVERALL TABLE MAPPING BREAKDOWN: (Leaving SI in place for now so I have a sense of where things go)
     - PP Assessment
         - demogrph
         - rating?
         - screenr
      
      -- SI
         - evaluation
     - PP Occurence
         - finance
         - media (if relevant)
         - attribute
         - customprospect(?)

       -- SI
         - notes
         - other philanthropic_affinity
         - philanthropic_interest
         - wealth_assets

 SCRIPT HISTORY:
     10-14-2026: Original version
     
*** CONFIDENTIAL - ALL SOURCE CODE, SCRIPTS, PROGRAMS AND RELATED ARTIFACTS CONTAINED
    HEREIN IS THE PROPERTY OF SLEEK CONSULTING UNLESS OTHERWISE NOTED ***
****************************************************************************************/

---------------------------------------------------------------------------------
-- prelim
---------------------------------------------------------------------------------

-- Create synonyms to make my life easier
CREATE SYNONYM mill_attribute FOR mill_attribute;
CREATE SYNONYM mill_attribute_type FOR mill_attribute_type;
CREATE SYNONYM mill_comment FOR mill_comment;
CREATE SYNONYM mill_comment_type FOR mill_comment_type;
CREATE SYNONYM mill_corebio FOR mill_corebio;
CREATE SYNONYM mill_ FOR mill_custombio;
CREATE SYNONYM mill_customprospect FOR mill_customprospect;
CREATE SYNONYM mill_demogrph FOR mill_demogrph;
CREATE SYNONYM mill_donor FOR mill_donor;
CREATE SYNONYM mill_fieldlst FOR fieldlst;
CREATE SYNONYM mill_finance FOR mill_finance;
CREATE SYNONYM mill_media FOR mill_media;
CREATE SYNONYM mill_rating FOR mill_rating;
CREATE SYNONYM mill_research_source FOR mill_research_source;
CREATE SYNONYM mill_screener FOR mill_screener;


---------------------------------------------------------------------------------
-- discovery
---------------------------------------------------------------------------------
-- Main PA tables (media is a maybe)
DECLARE @paDiscovery AS TABLE (
    tblName     SYSNAME  NOT NULL PRIMARY KEY
  , ct_all      INT      NULL
  , ct_constit  INT      NULL
);

INSERT INTO @paDiscovery
SELECT 'customprospect'       AS tblName
     , COUNT(*)               AS ct_all
     , COUNT(DISTINCT cprsid) AS ct_constit
FROM   mill_customprospect;

INSERT INTO @paDiscovery
SELECT 'demogrph'            AS tblName
     , COUNT(*)              AS ct_all
     , COUNT(DISTINCT demoid) AS ct_constit
FROM   mill_demogrph;

INSERT INTO @paDiscovery
SELECT 'donor'                AS tblName
     , COUNT(*)               AS ct_all
     , COUNT(DISTINCT donrid) AS ct_constit
FROM   mill_donor;

INSERT INTO @paDiscovery
SELECT 'finance'             AS tblName
     , COUNT(*)              AS ct_all
     , COUNT(DISTINCT finid) AS ct_constit
FROM   mill_finance;

INSERT INTO @paDiscovery
SELECT 'media'                AS tblName
     , COUNT(*)               AS ct_all
     , COUNT(DISTINCT mediaid) AS ct_constit
FROM   mill_media;

INSERT INTO @paDiscovery
SELECT 'rating'              AS tblName
     , COUNT(*)              AS ct_all
     , COUNT(DISTINCT rateid) AS ct_constit
FROM   mill_rating;

INSERT INTO @paDiscovery
SELECT 'research_source'     AS tblName
     , COUNT(*)              AS ct_all
     , COUNT(DISTINCT resid) AS ct_constit
FROM   mill_research_source;

INSERT INTO @paDiscovery
SELECT 'screener'             AS tblName
     , COUNT(*)               AS ct_all
     , COUNT(DISTINCT scrnid) AS ct_constit
FROM   mill_screener;

INSERT INTO @paDiscovery
SELECT 'attribute'           AS tblName
     , COUNT(*)              AS ct_all
     , COUNT(DISTINCT attrid) AS ct_constit
FROM   mill_attribute
WHERE  attrgroup = 'pt';

SELECT *
FROM   @paDiscovery;

-------------------------------------------------
-- tblName          ct_all  ct_constit
-- attribute          5317        2892
-- customprospect    14687        6396
-- demogrph         429663       49147
-- donor             28443       28443
-- finance           33433       16038
-- media              3044        1711
-- rating            79457       25809
-- research_source    2894        2493
-- screener          10504        3861
-------------------------------------------------

-- Get field list for core and custombio to see if there are any PA-related fields
-- Nothing useful for PA discovered in review
SELECT table_name
     , column_name
     , column_alias
     , datatype
FROM   mill_fieldlst t
WHERE  t.table_name IN ('corebio', 'custombio')
ORDER BY t.table_name
       , t.column_alias;

-- Review comment and attribute types
-- Look for attributes where the type = 'pt' ('Prospect Tracking')
SELECT t.table_code
     , t.table_val
     , t.table_type
     , g.table_val
FROM   mill_attribute_types t
LEFT JOIN mill_table_groups g
  ON   g.table_code = t.table_type
ORDER BY g.table_val
       , t.table_val;

-- Review comment types
-- No useful comment types identified
SELECT t.table_code
     , t.table_val
     , t.table_type
     , g.table_val
FROM   mill_comment_types t
LEFT JOIN mill_table_groups g
  ON   g.table_code = t.table_type
ORDER BY g.table_val
       , t.table_val;


---------------------------------------------------------------------------------
-- assemble constituents to migrate to PP Research Profile
---------------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.pa_constit;

CREATE TABLE dbo.pa_constit (
    coreid   CHAR(10) COLLATE Latin1_General_BIN  NOT NULL PRIMARY KEY
  , attr     BIT                                 NOT NULL DEFAULT 0
  , cuspros  BIT                                 NOT NULL DEFAULT 0
  , demo     BIT                                 NOT NULL DEFAULT 0
  , donr     BIT                                 NOT NULL DEFAULT 0
  , finc     BIT                                 NOT NULL DEFAULT 0
  , media    BIT                                 NOT NULL DEFAULT 0
  , rtng     BIT                                 NOT NULL DEFAULT 0
  , res_src  BIT                                 NOT NULL DEFAULT 0
  , scrn     BIT                                 NOT NULL DEFAULT 0
  , date_added DATETIME   NOT NULL
  , date_modified DATETIME  NOT NULL
);
GO

INSERT INTO dbo.pa_constit (coreid, attr, date_added, date_modified)
SELECT attrid          AS coreid
     , 1               AS attr
     , MIN(attrcrdate) AS date_added
     , MAX(attrdate)   AS date_modified
FROM   mill_attribute t
WHERE  t.attrgroup = 'pt'
GROUP BY attrid;

MERGE INTO dbo.pa_constit t
USING (
  SELECT cprsid
       , MIN(cprscrdate) AS cprscrdate
       , MAX(cprsdate)   AS cprsdate
  FROM   mill_customprospect
  GROUP BY cprsid
) s
  ON   s.cprsid = t.coreid
WHEN MATCHED THEN UPDATE
  SET cuspros = 1
    , date_added = IIF(s.cprscrdate < t.date_added, s.cprscrdate, t.date_added)
    , date_modified = IIF(s.cprsdate > t.date_modified, s.cprsdate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, cuspros, date_added, date_modified
)
VALUES (s.cprsid, 1, s.cprscrdate, s.cprsdate);

MERGE INTO dbo.pa_constit t
USING (
  SELECT demoid
       , MIN(democrdate) AS democrdate
       , MAX(demodate)   AS demodate
  FROM   mill_demogrph
  GROUP BY demoid
) s
  ON   s.demoid = t.coreid
WHEN MATCHED THEN UPDATE
  SET demo = 1
    , date_added = IIF(s.democrdate < t.date_added, s.democrdate, t.date_added)
    , date_modified = IIF(s.demodate > t.date_modified, s.demodate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, demo, date_added, date_modified
)
VALUES (s.demoid, 1, s.democrdate, s.demodate);

MERGE INTO dbo.pa_constit t
USING (
  SELECT donrid
       , MIN(donrcrdate) AS donrcrdate
       , MAX(donrdate)   AS donrdate
  FROM   mill_donor
  GROUP BY donrid
) s
  ON   s.donrid = t.coreid
WHEN MATCHED THEN UPDATE
  SET donr = 1
    , date_added = IIF(s.donrcrdate < t.date_added, s.donrcrdate, t.date_added)
    , date_modified = IIF(s.donrdate > t.date_modified, s.donrdate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, donr, date_added, date_modified
)
VALUES (s.donrid, 1, s.donrcrdate, s.donrdate);

MERGE INTO dbo.pa_constit t
USING (
  SELECT finid
       , MIN(fincrdate) AS fincrdate
       , MAX(findate)   AS findate
  FROM   mill_finance
  GROUP BY finid
) s
  ON   s.finid = t.coreid
WHEN MATCHED THEN UPDATE
  SET finc = 1
    , date_added = IIF(s.fincrdate < t.date_added, s.fincrdate, t.date_added)
    , date_modified = IIF(s.findate > t.date_modified, s.findate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, finc, date_added, date_modified
)
VALUES (s.finid, 1, s.fincrdate, s.findate);

MERGE INTO dbo.pa_constit t
USING (
  SELECT mediaid
       , MIN(mediacrdat) AS mediacrdat
       , MAX(mediadate)  AS mediadate
  FROM   mill_media
  GROUP BY mediaid
) s
  ON   s.mediaid = t.coreid
WHEN MATCHED THEN UPDATE
  SET media = 1
    , date_added = IIF(s.mediacrdat < t.date_added, s.mediacrdat, t.date_added)
    , date_modified = IIF(s.mediadate > t.date_modified, s.mediadate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, media, date_added, date_modified
)
VALUES (s.mediaid, 1, s.mediacrdat, s.mediadate);

MERGE INTO dbo.pa_constit t
USING (
  SELECT rateid
       , MIN(ratecrdate) AS ratecrdate
       , MAX(ratedate)   AS ratedate
  FROM   mill_rating
  GROUP BY rateid
) s
  ON   s.rateid = t.coreid
WHEN MATCHED THEN UPDATE
  SET rtng = 1
    , date_added = IIF(s.ratecrdate < t.date_added, s.ratecrdate, t.date_added)
    , date_modified = IIF(s.ratedate > t.date_modified, s.ratedate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, rtng, date_added, date_modified
)
VALUES (s.rateid, 1, s.ratecrdate, s.ratedate);

MERGE INTO dbo.pa_constit t
USING (
  SELECT resid
       , MIN(rescrdate) AS rescrdate
       , MAX(resdate)   AS resdate
  FROM   mill_research_source
  GROUP BY resid
) s
  ON   s.resid = t.coreid
WHEN MATCHED THEN UPDATE
  SET res_src = 1
    , date_added = IIF(s.rescrdate < t.date_added, s.rescrdate, t.date_added)
    , date_modified = IIF(s.resdate > t.date_modified, s.resdate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, res_src, date_added, date_modified
)
VALUES (s.resid, 1, s.rescrdate, s.resdate);

MERGE INTO dbo.pa_constit t
USING (
  SELECT scrnid
       , MIN(scrncrdate) AS scrncrdate
       , MAX(scrndate)   AS scrndate
  FROM   mill_screener
  GROUP BY scrnid
) s
  ON   s.scrnid = t.coreid
WHEN MATCHED THEN UPDATE
  SET scrn = 1
    , date_added = IIF(s.scrncrdate < t.date_added, s.scrncrdate, t.date_added)
    , date_modified = IIF(s.scrndate > t.date_modified, s.scrndate, t.date_modified)
WHEN NOT MATCHED BY TARGET THEN INSERT (
  coreid, scrn, date_added, date_modified
)
VALUES (s.scrnid, 1, s.scrncrdate, s.scrndate);

SELECT *
FROM   dbo.pa_constit t;


---------------------------------------------------------------------------------
-- assemble constituents to migrate to PP Research Profile
---------------------------------------------------------------------------------
drop table if exists PartyPhilanthropicRsrchPrfl;

CREATE TABLE PartyPhilanthropicRsrchPrfl_load (
  Id                   CHAR(18)        NULL
, Error                VARCHAR(4000)   NULL
, ASLE_External_Id__c  VARCHAR(50)     NOT NULL  PRIMARY KEY
, AccountId            CHAR(18)        NULL
, CreatedDate          VARCHAR(30)     NULL
, LastModifiedDate     VARCHAR(30)     NULL
, acct_xid             VARCHAR(50)     NULL
);

INSERT INTO PartyPhilanthropicRsrchPrfl_load (
  ASLE_External_Id__c, AccountId, CreatedDate, LastModifiedDate, acct_xid
)
-- 52591
-- 52155
SELECT 'rp_' + t.coreid AS ASLE_External_Id__c
     --, a.Id AS AccountId
     , t.date_added AS CreatedDate
     , t.date_modified AS LastModifiedDate
     , t.coreid AS acct_xid
     , n.namefirst
     , n.namelast
FROM   dbo.pa_constit t
left JOIN   sf_accounts a
  ON   a.ASLE_External_ID_c = t.coreid
left join MuhlMillProd.dbo.name n
  ON  n.nameid = t.coreid
  and n.nametype = 'a'
WHERE a.Id is null





select count(*) FROM account_person_load


select * FROM [MuhlMillProd].dbo.name where nameid = '0000170109'

