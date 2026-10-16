DECLARE @TableName SYSNAME = N'rating';   -- <-- change this
DECLARE @SchemaName SYSNAME = N'dbo';            -- <-- change this if needed
DECLARE @sql NVARCHAR(MAX) = N'';
 
SELECT @sql = @sql +
    N'SELECT ''' + c.COLUMN_NAME + N''' AS FieldName, '
    + N'''' + c.DATA_TYPE + N''' AS DataType, '
    + N''''
    + CASE
        WHEN c.CHARACTER_MAXIMUM_LENGTH IS NOT NULL
            THEN CAST(c.CHARACTER_MAXIMUM_LENGTH AS NVARCHAR(20))
        WHEN c.NUMERIC_PRECISION IS NOT NULL
            THEN CAST(c.NUMERIC_PRECISION AS NVARCHAR(20)) + N',' + CAST(ISNULL(c.NUMERIC_PRECISION_RADIX, 0) AS NVARCHAR(20))
        ELSE N''
      END
    + N''' AS SizeInfo, '
    + CASE
        WHEN c.DATA_TYPE = 'bit'
            THEN N'SUM(CASE WHEN ' + QUOTENAME(c.COLUMN_NAME) + N' = 1 THEN 1 ELSE 0 END)'
        ELSE N'COUNT(' + QUOTENAME(c.COLUMN_NAME) + N')'
      END
    + N' AS RecordCount FROM '
    + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
    + N' UNION ALL '
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME = @TableName
  AND c.TABLE_SCHEMA = @SchemaName;
 
-- Strip trailing 'UNION ALL '
SET @sql = LEFT(@sql, LEN(@sql) - LEN('UNION ALL '));
 
EXEC sp_executesql @sql;