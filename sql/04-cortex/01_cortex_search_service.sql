-- Create Cortex Search Service on the chunked dataset
-- Enables semantic search over parsed and chunked product documentation
CREATE OR REPLACE
CORTEX SEARCH SERVICE 
PRODUCT_ANALYTICS_TPCH
  ON chunk
  ATTRIBUTES file_url, chunk_id, filename
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (
  SELECT
    chunk,
    file_url,
    chunk_id,
    filename
  FROM PRODUCT_CHUNK_TABLE
);
