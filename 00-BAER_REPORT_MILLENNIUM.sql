/***************************************************************************************
        PURPOSE:    Populate the BAER REPORT tables
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
        CREATED:    8/20/2026
  LAST MODIFIED:    8/20/2026
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
     Gathers all metadata from the Muhlenberg Millennium backup database.  This includes, lookup
     values, usage counts (which shows us where the heaviest and most important kinds of data 
     live).  It also helps us to translate MILL lookup values to Salesforce picklists and processes.
     In addition, the BAER Reports are shared to our business analysts who are able to advise on 
     best practices moving forward based on past usage.

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  08-20-2026:  Original version -- candy's enhancements >> (gathering datatypes from sys instead
                    of fieldlist. also creating loop to get foreign key constraints and counts
                    for usage column).
   CH  08/23/2026:  limiting results to only those tables with a dbo schema
     
*************************************************************************************************/

--========================================================================
-- PART ONE: GET ALL TABLES/COLUMNS/DATATYPES FROM SYS
-- use foreign key constraint definitions to find the lookup relations
--========================================================================
Use SleekConversion;
drop table if exists SleekConversion.dbo.BAERReport;
SELECT  t.object_id                 as TblId,
        c.column_id                 as ColId,
        cast(0 as int)              as LkpId,
        t.name                      as TableName,
        ltrim(rtrim(c.name))        as ColumnName,
        fk.LookupTable              as LookupTable,
        fk.LookupColumn             as LookupColumn,
        cast(null as varchar(150))  as LookupCode,
        cast(null as varchar(255))  as LookupValue,
        cast(0 as int)              as Usage,
        case when p.name in ('numeric','money','float','int') then p.name + '('+cast(c.precision as varchar(10))+','+cast(c.scale as varchar(10))+')'
             else p.name + '('+cast(c.max_length as varchar(10))+')' end as DataType,
        case when c.is_nullable=1 then NULL else 'NOT NULL' end as Nullable,
        f.reference                 as Reference,
        f.column_alias              as Alias,
        f.displaytype               as Display,
        f.syscolind                 as SysColInd
into    SleekConversion.dbo.BAERReport
FROM    muhlmillprod.sys.objects t
join    muhlmillprod.sys.columns c on t.object_id=c.object_id
join    MuhlMillProd.sys.types p on c.user_type_id=p.user_type_id
left    join MuhlMillProd.dbo.fieldlst f on t.name=f.table_name and c.name=f.column_name
left    join (SELECT    fk.parent_object_id             as TableObjectId,
                        t.name                          AS TableName,
                        rtrim(ltrim(col_parent.name))   AS ColumnName,
                        r.name                          as LookupTable,
                        col_ref.name                    AS LookupColumn
                FROM    muhlmillprod.sys.foreign_keys fk
                join    muhlmillprod.sys.tables t on fk.parent_object_id=t.object_id
                join    muhlmillprod.sys.tables r on fk.referenced_object_id=r.object_id
                JOIN    muhlmillprod.sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
                jOIN    muhlmillprod.sys.columns col_parent ON fkc.parent_object_id = col_parent.object_id 
                                          AND fkc.parent_column_id = col_parent.column_id
                JOIN    muhlmillprod.sys.columns col_ref ON fkc.referenced_object_id = col_ref.object_id 
                                        AND fkc.referenced_column_id = col_ref.column_id
            )fk on t.object_id=fk.TableObjectId and ltrim(rtrim(c.name))=fk.ColumnName
WHERE   t.type='U'
and     t.schema_id=1
order by 1,2,3;

--=================================================================
-- PART TWO: cursor through the fields with lookups, 
-- append lookup values based on the foreign keys found 
-- in the above baer report. With the object table id, 
-- the column id, and now the lookup id we should have unique
-- ids across the board
--=================================================================
-----------------------------------------------------------------------------------------
-->> handle easy ones first....where the lookup columns are table_code/table_val
-->> best results are to print out the insert statements and run them in bulk 
-->> from the MUHL database 
-----------------------------------------------------------------------------------------
USE SleekConversion;

    declare @tid varchar(50), @cid varchar(10), @tname varchar(150),
            @cname varchar(150), @lname varchar(150), @lcol varchar(150),
            @lcode varchar(50), @lvalue varchar(255), @qry nvarchar(max);

    declare clist cursor for
    select  TblId, ColId, TableName, ColumnName, LookupTable, LookupColumn
    from    SleekConversion.dbo.BAERReport 
    where   LookupTable is not null
    and     LookupColumn='table_code';

    open clist;
    fetch next from clist into @tid,@cid,@tname,@cname,@lname,@lcol;
    while @@FETCH_STATUS =0 
    begin
        set @qry='insert into SleekConversion.dbo.BAERReport (TblId,ColId,LkpId,TableName,ColumnName,LookupTable,LookupColumn,LookupCode,LookupValue)
                  select '+@tid+','+@cid+',row_number() over (order by table_code) as lcount,'''+@tname+''','''+@cname+''','''+@lname+''','''+@lcol+''','+'table_code'+','+'table_val from MuhlMillProd.dbo.['+@lname+'];';

        print @qry; -- copy results into another sheet and execute -- WAY FASTER
        --exec (@qry);

        FETCH NEXT FROM clist INTO @tid,@cid,@tname,@cname,@lname,@lcol;
    end;
    close clist;
    deallocate clist;

-----------------------------------------------------------------------------------------
-->> ade_source as a lookup can be added manually (easy way)
-----------------------------------------------------------------------------------------
USE SleekConversion;
    insert into SleekConversion.dbo.BAERReport (TblId,ColId,LkpId,TableName,ColumnName,LookupTable,LookupColumn,LookupCode,LookupValue)
    select  TblId,ColId,1,TableName,ColumnName,LookupTable,LookupColumn,'',''
    from    SleekConversion.dbo.BAERReport x
    where   x.lookuptable='ade_source'
    and     x.lookupcolumn='table_val'
    union
    select  TblId,ColId,2,TableName,ColumnName,LookupTable,LookupColumn,'Online Directory','Online Directory'
    from    SleekConversion.dbo.BAERReport x
    where   x.lookuptable='ade_source'
    and     x.lookupcolumn='table_val'
    union
    select  TblId,ColId,3,TableName,ColumnName,LookupTable,LookupColumn,'Soft Edit','Soft Edit'
    from    SleekConversion.dbo.BAERReport x
    where   x.lookuptable='ade_source'
    and     x.lookupcolumn='table_val';

-----------------------------------------------------------------------------------------
-->> circle definition (easy update)
-----------------------------------------------------------------------------------------
USE SleekConversion;
    insert into SleekConversion.dbo.BAERReport (TblId,ColId,LkpId,TableName,ColumnName,LookupTable,LookupColumn,LookupCode,LookupValue)
    select  TblId,ColId,1,TableName,ColumnName,LookupTable,LookupColumn,'BoT','Board of Trustees'
    from    SleekConversion.dbo.BAERReport x
    where   x.lookuptable='circle_definition'
    and     x.lookupcolumn='cir_code'
    union
    select  TblId,ColId,2,TableName,ColumnName,LookupTable,LookupColumn,'DAR','Development & Alumni Relations'
    from    SleekConversion.dbo.BAERReport x
    where   x.lookuptable='circle_definition'
    and     x.lookupcolumn='cir_code';

-----------------------------------------------------------------------------------------
-->> insert chart of accounts codes
-----------------------------------------------------------------------------------------
USE SleekConversion;
    insert into SleekConversion.dbo.BAERReport (TblId,ColId,LkpId,TableName,ColumnName,LookupTable,LookupColumn,LookupCode,LookupValue)
    select  TblId,ColId,y.lkpid,TableName,ColumnName,LookupTable,LookupColumn,y.chart_code,y.chart_val
    from    SleekConversion.dbo.BAERReport x
    cross join (select row_number() over (order by chart_code) as lkpid, chart_code, chart_val
                from MuhlMillPROD.dbo.chart_of_accounts) y
    where   x.lookuptable='chart_of_accounts'
    and     x.lookupcolumn='chart_code'
    order by tblid, colid, y.lkpid;

-----------------------------------------------------------------------------------------
-->> insert solicitations
-----------------------------------------------------------------------------------------
USE SleekConversion;
    insert into SleekConversion.dbo.BAERReport (TblId,ColId,LkpId,TableName,ColumnName,LookupTable,LookupColumn,LookupCode,LookupValue)
    select  TblId,ColId,y.lkpid,TableName,ColumnName,LookupTable,LookupColumn,y.sol_code,y.sol_val
    from    SleekConversion.dbo.BAERReport x
    cross join (select row_number() over (order by sol_code) as lkpid, sol_code, sol_val
                from MuhlMillPROD.dbo.solicitations) y
    where   x.lookuptable='solicitations'
    and     x.lookupcolumn='sol_code'
    order by tblid, colid, y.lkpid;

-----------------------------------------------------------------------------------------
-->> lastly, handle corebio
-----------------------------------------------------------------------------------------
USE SleekConversion;
    update  SleekConversion.dbo.BAERReport 
    set     LookupCode ='(link by coreid)',LookupValue='(link by coreid)'
    where   lookupcolumn='coreid';


--=================================================================
-- PART THREE: cursor through the fields and get usage counts
-- to see what fields are getting the most attention.
--=================================================================
-- start by setting the Usage column to 0 for all rows
update SleekConversion.dbo.BAERReport set Usage=0;

-----------------------------------------------------------------
-->> Start with non-lookup fields (where lkpid=0)
-----------------------------------------------------------------
use SleekConversion;

    declare @utid varchar(50), @ucid varchar(10), @utname varchar(150),
            @ucname varchar(150), @rcnt int, @uqry nvarchar(500);

    declare ulist cursor for
    select  tblid, colid, tablename, columnname
    from    SleekConversion.dbo.BAERReport x
    where   lkpid=0
    order by 1,2;

    select @rcnt = count(*) from BAERReport where lkpid=0;

    open ulist;
    fetch next from ulist into @utid,@ucid,@utname,@ucname;
    while @@FETCH_STATUS =0 
    begin
        set @uqry= N'update SleekConversion.dbo.BAERReport set [Usage]=(select count(['+@ucname+']) from MuhlMillProd.dbo.['+@utname+']) where TblId='+@utid+' and ColId='+@ucid+' and LkpId=0;';

        print @uqry;
        print 'update stmt is number '+str(@rcnt);
        exec (@uqry);
        print ' ';
        set @rcnt = @rcnt-1;

        FETCH NEXT FROM ulist INTO @utid,@ucid,@utname,@ucname;
    end;
    close ulist;
    deallocate ulist;

-----------------------------------------------------------------
-->> Same thing, but this time we are counting the usage of the 
-->> lookup values to determine picklist distribution
-----------------------------------------------------------------
Use SleekConversion;

    declare @xtid varchar(50), @xcid varchar(10), @xlid varchar(10), @xtname varchar(150),
            @xcname varchar(150), @xlcode varchar(50), @xcnt int, @xqry nvarchar(max);

    declare xlist cursor for
    select  tblid, colid, lkpid, tablename, columnname, lookupcode
    from    BAERReport x
    where   lkpid>0
    and     lookupcode not like '%''%'
    order by 1,2,3;

    select @xcnt = count(*) from BAERReport where lkpid>0 and lookupcode not like '%''%';

    open xlist;
    fetch next from xlist into @xtid,@xcid,@xlid,@xtname,@xcname,@xlcode;
    while @@FETCH_STATUS =0 
    begin
        set @xqry='update SleekConversion.dbo.BAERReport set [Usage]=(select count(['+@xcname+']) from MuhlMillProd.dbo.['+@xtname+'] where ['+@xcname+']='''+@xlcode+''') where TblId='+@xtid+' and ColId='+@xcid+' and LkpId='+@xlid+';';
        
        --if @xcnt<25000
            BEGIN
            print @xqry;
            print 'update stmt is number '+str(@xcnt);
            exec (@xqry);
            print ' ';
            END
        
        set @xcnt = @xcnt-1;

        fetch next from xlist into @xtid,@xcid,@xlid,@xtname,@xcname,@xlcode;
    end;
    close xlist;
    deallocate xlist;

--=================================================================
-- PART FOUR: deliver the BAER report based on usage
--=================================================================