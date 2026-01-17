-- Create table with chunked data for RAG purposes
-- Splits documents into manageable chunks for embedding and search
CREATE OR REPLACE TABLE PRODUCT_CHUNK_TABLE AS
SELECT
    FILENAME,
    ROW_NUMBER() OVER (PARTITION BY FILENAME ORDER BY SEQ) AS chunk_id,
    GET_PRESIGNED_URL('@TPCH_DATA_PRODUCT.ANALYTICS.SAMPLE_STAGE', FILENAME, 86400) AS file_url,
    CONCAT(FILENAME, ':', chunk_id::TEXT, ': ', c.value::TEXT) AS chunk,
    'English' AS language
FROM
    PARSED_PRODPDF,
    LATERAL FLATTEN(SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
        EXTRACTED_CONTENT,
        'markdown',
        200,
        30
    )) c(SEQ, value);
