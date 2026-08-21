CREATE OR REPLACE TABLE PLC_DWH_V5.CONFIG_SCHEMA.DATA_PIPELINE_TABLE_LOG
(
    /* =========================================================
       IDENTIFIERS
       ========================================================= */
    LOG_ID                   VARCHAR DEFAULT UUID_STRING(),
    END_TO_END_RUN_ID        VARCHAR,
    ADF_PIPELINE_RUN_ID      VARCHAR,
    CURATION_RUN_ID          VARCHAR,
 
    PIPELINE_NAME            VARCHAR,
    SOURCE_SYSTEM_ID         VARCHAR,
 
    /* =========================================================
       SOURCE TABLE
       ========================================================= */
    SOURCE_DB_NAME           VARCHAR,
    SOURCE_SCHEMA_NAME       VARCHAR,
    SOURCE_TABLE_NAME        VARCHAR,
 
    STAGING_METHOD           VARCHAR,
    WATERMARK_COLUMN         VARCHAR,
    WATERMARK_START          TIMESTAMP_NTZ(9),
    WATERMARK_END            TIMESTAMP_NTZ(9),
 
    SOURCE_EXTRACTION_START_TIME TIMESTAMP_NTZ(9),
    SOURCE_EXTRACTION_END_TIME   TIMESTAMP_NTZ(9),
 
    ROWS_READ_FROM_SOURCE    NUMBER(38,0),
 
    SOURCE_TO_BLOB_STATUS    VARCHAR,
    SOURCE_TO_BLOB_ERROR     VARCHAR,
    SOURCE_TO_BLOB_DURATION_SECONDS NUMBER(38,0),
 
    /* =========================================================
       AZURE BLOB
       ========================================================= */
    DESTINATION_BLOB_PATH    VARCHAR,
    BLOB_FILE_NAME           VARCHAR,
    BLOB_FILE_COUNT          NUMBER(38,0),
 
    ROWS_WRITTEN_TO_BLOB     NUMBER(38,0),
 
    /* =========================================================
       BLOB TO BRONZE
       ========================================================= */
    TARGET_BRONZE_DATABASE   VARCHAR,
    TARGET_BRONZE_SCHEMA     VARCHAR,
    TARGET_BRONZE_TABLE      VARCHAR,
 
    BLOB_TO_BRONZE_START_TIME TIMESTAMP_NTZ(9),
    BLOB_TO_BRONZE_END_TIME   TIMESTAMP_NTZ(9),
 
    ROWS_LOADED_TO_BRONZE    NUMBER(38,0),
 
    BLOB_TO_BRONZE_STATUS    VARCHAR,
    BLOB_TO_BRONZE_ERROR     VARCHAR,
    BLOB_TO_BRONZE_DURATION_SECONDS NUMBER(38,0),
 
    /* =========================================================
       SCHEMA DRIFT / SCHEMA EVOLUTION
       ========================================================= */
    SCHEMA_DRIFT_START_TIME  TIMESTAMP_NTZ(9),
    SCHEMA_DRIFT_END_TIME    TIMESTAMP_NTZ(9),
 
    SCHEMA_DRIFT_DETECTED    BOOLEAN,
    SCHEMA_DRIFT_STATUS      VARCHAR,
    SCHEMA_EVOLVE_STATUS     VARCHAR,
 
    ADDED_COLUMNS            VARIANT,
    REMOVED_COLUMNS          VARIANT,
    CHANGED_COLUMNS          VARIANT,
 
    SCHEMA_DRIFT_ERROR       VARCHAR,
 
    /* =========================================================
       CURATION
       ========================================================= */
    TARGET_CURATED_DATABASE  VARCHAR,
    TARGET_CURATED_SCHEMA    VARCHAR,
    TARGET_CURATED_TABLE     VARCHAR,
 
    CURATION_START_TIME      TIMESTAMP_NTZ(9),
    MERGE_START_TIME         TIMESTAMP_NTZ(9),
    MERGE_END_TIME           TIMESTAMP_NTZ(9),
    FULL_LOAD_START_TIME     TIMESTAMP_NTZ(9),
    FULL_LOAD_END_TIME       TIMESTAMP_NTZ(9),
    CURATION_END_TIME        TIMESTAMP_NTZ(9),
 
    MERGE_RESULT             VARCHAR,
    FULL_LOAD_RESULT         VARCHAR,
 
    FALLBACK_USED            BOOLEAN DEFAULT FALSE,
    FALLBACK_REASON          VARCHAR,
 
    ROWS_INSERTED            NUMBER(38,0),
    ROWS_UPDATED             NUMBER(38,0),
    ROWS_DELETED             NUMBER(38,0),
    ROWS_LOADED_TO_CURATED   NUMBER(38,0),
 
    CURATION_STATUS          VARCHAR,
    CURATION_ERROR           VARCHAR,
 
    /* =========================================================
       DATA RECONCILIATION
       ========================================================= */
    SOURCE_BLOB_ROW_DIFFERENCE    NUMBER(38,0),
    BLOB_BRONZE_ROW_DIFFERENCE    NUMBER(38,0),
    BRONZE_CURATED_ROW_DIFFERENCE NUMBER(38,0),
 
    RECONCILIATION_STATUS    VARCHAR,
    RECONCILIATION_MESSAGE   VARCHAR,
 
    /* =========================================================
       FINAL END-TO-END STATUS
       ========================================================= */
    OVERALL_START_TIME       TIMESTAMP_NTZ(9),
    OVERALL_END_TIME         TIMESTAMP_NTZ(9),
    OVERALL_DURATION_SECONDS NUMBER(38,0),
 
    FINAL_STATUS             VARCHAR,
    FAILED_STAGE             VARCHAR,
    RAW_ERROR_MESSAGE        VARCHAR,
 
    RETRY_COUNT              NUMBER(38,0) DEFAULT 0,
    IS_REPROCESS             BOOLEAN DEFAULT FALSE,
 
    CREATED_AT               TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT               TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
 
    CONSTRAINT PK_DATA_PIPELINE_TABLE_LOG
        PRIMARY KEY (LOG_ID)
);