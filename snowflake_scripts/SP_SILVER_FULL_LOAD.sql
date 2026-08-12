CREATE OR REPLACE PROCEDURE PLC_DWH.CONFIG_SCHEMA.SP_SILVER_FULL_LOAD("P_SOURCE_SCHEMA" VARCHAR, "P_TABLE_NAME" VARCHAR, "P_TARGET_SCHEMA" VARCHAR, "P_RUN_ID" VARCHAR)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS ' 
function qident(v) { return ''"'' + String(v).replace(/"/g, ''""'') + ''"''; } 
function qstr(v) { return v === null || v === undefined ? "NULL" : "''" + String(v).replace(/''/g, "''''") + "''"; } 
function exec(sqlText) { return snowflake.createStatement({sqlText: sqlText}).execute(); } 
function singleValue(sqlText) { var rs = exec(sqlText); return rs.next() ? rs.getColumnValue(1) : null; } 
 
var startTimeSql = "CURRENT_TIMESTAMP()"; 
var sourceCount = 0; 
var rowsAffected = 0; 
var addColCount = 0; 
var widenColCount = 0; 
var schemaMsg = ""; 
var targetTable = P_TABLE_NAME; 
 
try { 
   // 1. Get Source Count 
   try { 
       sourceCount = singleValue(''SELECT COUNT(*) FROM PLC_DWH.'' + qident(P_SOURCE_SCHEMA) + ''.'' + qident(P_TABLE_NAME)); 
   } catch (e) { 
       sourceCount = 0; 
   } 
 
   // 2. Check if Target Table exists in Silver 
   var curExists = singleValue(` 
       SELECT COUNT(*) 
       FROM PLC_DWH.INFORMATION_SCHEMA.TABLES 
       WHERE TABLE_SCHEMA = ${qstr(P_TARGET_SCHEMA)} 
         AND TABLE_NAME = ${qstr(P_TABLE_NAME)} 
   `); 
 
   // 3. Create Target if missing 
   if (Number(curExists) === 0) { 
       exec( 
           ''CREATE TABLE PLC_DWH.'' + qident(P_TARGET_SCHEMA) + ''.'' + qident(P_TABLE_NAME) + 
           '' AS SELECT * FROM PLC_DWH.'' + qident(P_SOURCE_SCHEMA) + ''.'' + qident(P_TABLE_NAME) + 
           '' WHERE 1=0'' 
       ); 
   } 
 
   // 4. Schema Drift: Add Missing Columns + Widen Columns 
   try { 
       var evolveRs = exec( 
           "CALL PLC_DWH.CONFIG_SCHEMA.SP_EVOLVE_SILVER_SCHEMA(" + 
           qstr(P_SOURCE_SCHEMA) + ", " + qstr(P_TABLE_NAME) + ", " + qstr(P_TARGET_SCHEMA) + ")" 
       ); 
       var evolveResult = evolveRs.next() ? evolveRs.getColumnValue(1) : null; 
       var evolveObj = {}; 
 
       if (evolveResult !== null) { 
           if (typeof evolveResult === ''object'') { 
               evolveObj = evolveResult; 
           } else { 
               try { evolveObj = JSON.parse(evolveResult); } catch (err) { evolveObj = {status: "ERROR"}; } 
           } 
       } else { 
           evolveObj = {status: "SUCCESS"}; 
       } 
 
       addColCount = evolveObj.added_columns || 0; 
       widenColCount = evolveObj.widened_columns || 0; 
   } catch (e) { 
       evolveObj = {status: "EVOLVE_CALL_FAILED", error: String(e.message || e)}; 
   } 
 
   // 5. Build Insert/Select Mapping 
   var colListSql = ` 
       SELECT 
           LISTAGG(''"'' || REPLACE(c.COLUMN_NAME, ''"'', ''""'') || ''"'', '', '') WITHIN GROUP (ORDER BY c.ORDINAL_POSITION) AS INSERT_COLS, 
           LISTAGG(''SRC."'' || REPLACE(c.COLUMN_NAME, ''"'', ''""'') || ''"'', '', '') WITHIN GROUP (ORDER BY c.ORDINAL_POSITION) AS SELECT_COLS 
       FROM PLC_DWH.INFORMATION_SCHEMA.COLUMNS c 
       JOIN PLC_DWH.INFORMATION_SCHEMA.COLUMNS s 
         ON UPPER(c.COLUMN_NAME) = UPPER(s.COLUMN_NAME) 
       WHERE c.TABLE_SCHEMA = ${qstr(P_TARGET_SCHEMA)} AND c.TABLE_NAME = ${qstr(P_TABLE_NAME)} 
         AND s.TABLE_SCHEMA = ${qstr(P_SOURCE_SCHEMA)} AND s.TABLE_NAME = ${qstr(P_TABLE_NAME)} 
   `; 
   var rsCols = exec(colListSql); 
   var insertCols = null; 
   var selectCols = null; 
   if (rsCols.next()) { 
       insertCols = rsCols.getColumnValue(''INSERT_COLS''); 
       selectCols = rsCols.getColumnValue(''SELECT_COLS''); 
   } 
 
   if (selectCols !== null) { 
       selectCols = selectCols.replace(/SRC."_INGESTED_AT"/ig, ''CURRENT_TIMESTAMP()''); 
   } 
 
   if (insertCols === null || insertCols === '''') throw "No common columns found between STG and CUR"; 
 
   // 6. Execute Truncate and Load 
   exec(''TRUNCATE TABLE PLC_DWH.'' + qident(P_TARGET_SCHEMA) + ''.'' + qident(targetTable)); 
 
   var insertSql = ''INSERT INTO PLC_DWH.'' + qident(P_TARGET_SCHEMA) + ''.'' + qident(targetTable) + 
                   '' ('' + insertCols + '') SELECT '' + selectCols + '' FROM PLC_DWH.'' + qident(P_SOURCE_SCHEMA) + ''.'' + qident(P_TABLE_NAME) + '' SRC''; 
 
   var stmtInsert = snowflake.createStatement({sqlText: insertSql}); 
   stmtInsert.execute(); 
   rowsAffected = stmtInsert.getNumRowsAffected(); 
 
   // 7. Log Success using JSON Metadata 
   var metaStr = JSON.stringify({ 
       "load_type": "FULL_LOAD", 
       "added_columns": addColCount, 
       "widened_columns": widenColCount, 
       "evolve_status": evolveObj.status || "SUCCESS" 
   }); 
 
   exec(` 
       INSERT INTO PLC_DWH.CONFIG_SCHEMA.LOAD_AUDIT_LOG (ADF_PIPELINE_RUN_ID, SOURCE_SCHEMA, SOURCE_TABLE, TARGET_SCHEMA, TARGET_TABLE, START_TIME, END_TIME, SOURCE_ROW_COUNT, ROWS_AFFECTED, STATUS, ERROR_MESSAGE, LOAD_METADATA) 
       SELECT ${qstr(P_RUN_ID)}, ${qstr(P_SOURCE_SCHEMA)}, ${qstr(P_TABLE_NAME)}, ${qstr(P_TARGET_SCHEMA)}, ${qstr(targetTable)}, ${startTimeSql}, CURRENT_TIMESTAMP(), ${sourceCount}, ${rowsAffected}, ''SUCCESS'', NULL, PARSE_JSON(${qstr(metaStr)}) 
   `); 
 
   return ''SUCCESS - '' + rowsAffected + '' rows (FULL LOAD)''; 
 
} catch (err) { 
   var errMsg = String(err.message || err).substring(0, 1500); 
   try { 
       exec(` 
           INSERT INTO PLC_DWH.CONFIG_SCHEMA.LOAD_AUDIT_LOG (ADF_PIPELINE_RUN_ID, SOURCE_SCHEMA, SOURCE_TABLE, TARGET_SCHEMA, TARGET_TABLE, START_TIME, END_TIME, SOURCE_ROW_COUNT, ROWS_AFFECTED, STATUS, ERROR_MESSAGE, LOAD_METADATA) 
           SELECT ${qstr(P_RUN_ID)}, ${qstr(P_SOURCE_SCHEMA)}, ${qstr(P_TABLE_NAME)}, ${qstr(P_TARGET_SCHEMA)}, ${qstr(targetTable)}, ${startTimeSql}, CURRENT_TIMESTAMP(), ${sourceCount}, 0, ''FAILED'', ${qstr(errMsg)}, NULL 
       `); 
   } catch (logErr) {} 
 
   return ''FAILED - '' + errMsg; 
} 
';