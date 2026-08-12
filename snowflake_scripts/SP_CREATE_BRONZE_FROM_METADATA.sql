CREATE OR REPLACE PROCEDURE PLC_DWH.CONFIG_SCHEMA.SP_CREATE_BRONZE_FROM_METADATA("P_TARGET_SCHEMA" VARCHAR, "P_TARGET_TABLE" VARCHAR, "P_COLUMN_METADATA" VARIANT)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
    var ddl = ''CREATE OR REPLACE TABLE PLC_DWH.'' + P_TARGET_SCHEMA + ''."'' + P_TARGET_TABLE + ''" ('';
    var cols = [];
    
    // Loop through the JSON array provided by Azure Data Factory
    for (var i = 0; i < P_COLUMN_METADATA.length; i++) {
        var col = P_COLUMN_METADATA[i];
        var colName = ''"'' + col.COLUMN_NAME + ''"'';
        var dataType = String(col.DATA_TYPE).toUpperCase();
        var maxLen = col.CHARACTER_MAXIMUM_LENGTH;
        var precision = col.NUMERIC_PRECISION;
        var scale = col.NUMERIC_SCALE;
        
        var sfType = ''VARCHAR(16777216)''; // Fallback default
        
        // 1. String Types
        if ([''VARCHAR'', ''NVARCHAR'', ''CHAR'', ''NCHAR''].includes(dataType)) {
            if (maxLen && maxLen > 0) {
                sfType = ''VARCHAR('' + maxLen + '')'';
            } else {
                sfType = ''VARCHAR(16777216)''; // Handles VARCHAR(MAX)
            }
        } 
        // 2. Exact Numeric Types
        else if ([''DECIMAL'', ''NUMERIC''].includes(dataType)) {
            if (precision !== null && scale !== null) {
                sfType = ''NUMBER('' + precision + '','' + scale + '')'';
            } else {
                sfType = ''NUMBER(38,8)'';
            }
        } 
        // 3. Integer Types
        else if ([''INT'', ''BIGINT'', ''SMALLINT'', ''TINYINT''].includes(dataType)) {
            sfType = ''NUMBER(38,0)'';
        } 
        // 4. Boolean Types
        else if ([''BIT''].includes(dataType)) {
            sfType = ''BOOLEAN'';
        } 
        // 5. Pure Date Types (THIS IS THE FIX)
        else if ([''DATE''].includes(dataType)) {
            sfType = ''DATE'';
        } 
        // 6. Date/Time Types (THIS IS THE FIX)
        else if ([''DATETIME'', ''DATETIME2'', ''TIMESTAMP''].includes(dataType)) {
            sfType = ''TIMESTAMP_NTZ(9)'';
        } 
        // 7. Floating Point Types
        else if ([''FLOAT'', ''REAL''].includes(dataType)) {
            sfType = ''FLOAT'';
        }
        
        cols.push(colName + '' '' + sfType);
    }
    
    ddl += cols.join('', '') + '');'';
    
    // Execute the dynamically built DDL
    var stmt = snowflake.createStatement({sqlText: ddl});
    stmt.execute();
    
    return ''SUCCESS: Bronze table created perfectly. DDL Executed: '' + ddl;
';