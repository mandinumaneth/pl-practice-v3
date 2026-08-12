CREATE OR REPLACE PROCEDURE PLC_DWH.CONFIG_SCHEMA.SP_MAIN_SILVER_CURATION("P_PIPELINE_RUN_ID" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS ' 
DECLARE 
   V_SOURCE_SCHEMA VARCHAR DEFAULT ''BRONZE_LAYER''; 
   V_TARGET_SCHEMA VARCHAR DEFAULT ''SILVER_LAYER''; 
   V_TABLE_NAME VARCHAR; 
   V_STAGING_METHOD VARCHAR; 
   V_SQL VARCHAR; 
   V_LOG_MSG VARCHAR DEFAULT ''''; 
 
   -- Cursor to loop through all active curation tables 
   CUR_TABLES CURSOR FOR  
       SELECT TARGET_SNOWFLAKE_TABLE, STAGING_METHOD  
       FROM PLC_DWH.CONFIG_SCHEMA.INGESTION_CONFIG  
       WHERE IS_CURATION_ACTIVE = TRUE  
         AND IS_ACTIVE = TRUE; 
BEGIN 
   -- Force the session context for Azure Data Factory 
   EXECUTE IMMEDIATE ''USE SCHEMA PLC_DWH.CONFIG_SCHEMA''; 
 
   -- Loop through each active table from the metadata config 
   FOR REC IN CUR_TABLES DO 
       V_TABLE_NAME := REC.TARGET_SNOWFLAKE_TABLE; 
       V_STAGING_METHOD := REC.STAGING_METHOD; 
 
       -- Dynamically route to Full Load or Incremental Merge based on config, passing the RUN_ID 
       IF (V_STAGING_METHOD = ''TRUNCATE'') THEN 
           V_SQL := ''CALL PLC_DWH.CONFIG_SCHEMA.SP_SILVER_FULL_LOAD('''''' || V_SOURCE_SCHEMA || '''''', '''''' || V_TABLE_NAME || '''''', '''''' || V_TARGET_SCHEMA || '''''', '''''' || P_PIPELINE_RUN_ID || '''''')''; 
       ELSE 
           V_SQL := ''CALL PLC_DWH.CONFIG_SCHEMA.SP_SILVER_INCREMENTAL_MERGE('''''' || V_SOURCE_SCHEMA || '''''', '''''' || V_TABLE_NAME || '''''', '''''' || V_TARGET_SCHEMA || '''''', '''''' || P_PIPELINE_RUN_ID || '''''')''; 
       END IF; 
 
       -- Execute the child worker SP 
       EXECUTE IMMEDIATE V_SQL; 
 
       -- Append result log 
       V_LOG_MSG := V_LOG_MSG || V_TABLE_NAME || '' ('' || V_STAGING_METHOD || '') successfully called. ''; 
   END FOR; 
 
   RETURN ''Main Curation Complete! Pipeline Run ID: '' || P_PIPELINE_RUN_ID || '' | Details: '' || V_LOG_MSG; 
END; 
';