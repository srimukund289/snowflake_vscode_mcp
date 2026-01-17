-- Snowflake MCP Project - Master Setup Script
-- Execute all SQL scripts in sequence to set up the complete data product
-- 
-- EXECUTION ORDER (important):
-- 1. sql/01-setup/*.sql - Create database, schema, and stage
-- 2. sql/02-tables/*.sql - Create tables and views
-- 3. sql/03-semantic-views/*.sql - Create semantic views
-- 4. sql/04-cortex/*.sql - Set up Cortex Search Service
-- 5. sql/05-mcp-server/*.sql - Create MCP Server
--
-- Prerequisites:
-- - Snowflake account with ACCOUNTADMIN role
-- - Cortex capabilities enabled
-- - COMPUTE_WH warehouse available or create one
--
-- Time to complete: ~5-10 minutes

-- ============================================================================
-- STEP 1: Setup Database, Schema, and Stage
-- ============================================================================
-- File: sql/01-setup/01_database_schema_setup.sql
CREATE DATABASE IF NOT EXISTS TPCH_DATA_PRODUCT;
CREATE SCHEMA IF NOT EXISTS TPCH_DATA_PRODUCT.ANALYTICS;
USE SCHEMA TPCH_DATA_PRODUCT.ANALYTICS;
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;

-- File: sql/01-setup/02_stage_setup.sql
CREATE OR REPLACE STAGE SAMPLE_STAGE
	DIRECTORY = ( ENABLE = true ) 
	ENCRYPTION = ( TYPE = 'SNOWFLAKE_SSE' );

-- ============================================================================
-- STEP 2: Create Tables and Views (Silver and Gold Layers)
-- ============================================================================
-- File: sql/02-tables/01_integrated_sales_view.sql
CREATE OR REPLACE TABLE V_INTEGRATED_SALES AS
SELECT 
    o.O_ORDERKEY AS Order_ID,
    o.O_ORDERDATE AS Order_Date,
    c.C_NAME AS Customer_Name,
    c.C_MKTSEGMENT AS Market_Segment,
    n.N_NAME AS Nation,
    r.R_NAME AS Region,
    p.P_NAME AS Product_Name,
    p.P_TYPE AS Product_Type,
    l.L_QUANTITY AS Quantity,
    l.L_EXTENDEDPRICE AS Gross_Revenue,
    l.L_DISCOUNT AS Discount_Rate,
    (l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS Net_Revenue,
    l.L_LINESTATUS AS Line_Status
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS o
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM l ON o.O_ORDERKEY = l.L_ORDERKEY
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c ON o.O_CUSTKEY = c.C_CUSTKEY
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n ON c.C_NATIONKEY = n.N_NATIONKEY
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION r ON n.N_REGIONKEY = r.R_REGIONKEY
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART p ON l.L_PARTKEY = p.P_PARTKEY;

-- File: sql/02-tables/02_sales_performance_kpi.sql
CREATE OR REPLACE TABLE SALES_PERFORMANCE_KPI AS
SELECT 
    Region,
    Nation,
    Market_Segment,
    DATE_TRUNC('MONTH', Order_Date) AS Sales_Month,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Quantity) AS Total_Units_Sold,
    ROUND(SUM(Net_Revenue), 2) AS Total_Net_Revenue,
    ROUND(AVG(Discount_Rate) * 100, 2) AS Avg_Discount_Percent
FROM V_INTEGRATED_SALES
GROUP BY 1, 2, 3, 4
ORDER BY Sales_Month DESC, Total_Net_Revenue DESC;

-- File: sql/02-tables/03_parsed_pdf_table.sql
CREATE OR REPLACE TABLE PARSED_PRODPDF (
    FILENAME VARCHAR(255),
    EXTRACTED_CONTENT VARCHAR(16777216),
    PARSE_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP
);

-- File: sql/02-tables/04_insert_parsed_pdf.sql
INSERT INTO PARSED_PRODPDF (FILENAME, EXTRACTED_CONTENT)
SELECT
    t1.RELATIVE_PATH AS FILENAME,
    t1.EXTRACTED_CONTENT
FROM
    (
        SELECT
            RELATIVE_PATH,
            TO_VARCHAR(
                SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                    '@TPCH_DATA_PRODUCT.ANALYTICS.SAMPLE_STAGE',
                    RELATIVE_PATH,
                    {'mode': 'OCR'}
                ):content
            ) AS EXTRACTED_CONTENT
        FROM
            DIRECTORY('@TPCH_DATA_PRODUCT.ANALYTICS.SAMPLE_STAGE')
    ) AS t1;

-- File: sql/02-tables/05_product_chunk_table.sql
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

-- ============================================================================
-- STEP 3: Create Semantic View (for Cortex Analyst)
-- ============================================================================
-- File: sql/03-semantic-views/01_sales_performance_semantic_view.sql
CREATE OR REPLACE SEMANTIC VIEW TPCH_DATA_PRODUCT.ANALYTICS.SV_SALES_PERFORMANCE
    TABLES (
        SALES_DATA AS TPCH_DATA_PRODUCT.ANALYTICS.V_INTEGRATED_SALES PRIMARY KEY (ORDER_ID)
    )
    FACTS (
        SALES_DATA.QUANTITY AS QUANTITY 
            WITH SYNONYMS=('volume', 'units sold', 'count') 
            COMMENT='The number of units sold for a specific line item.',
        
        SALES_DATA.GROSS_REVENUE AS GROSS_REVENUE 
            WITH SYNONYMS=('gross sales', 'revenue before discount') 
            COMMENT='The total price before any discounts are applied.',
        
        SALES_DATA.NET_REVENUE AS NET_REVENUE 
            WITH SYNONYMS=('sales', 'actual revenue', 'income') 
            COMMENT='The final revenue amount after the discount has been subtracted from the gross price.'
    )
    DIMENSIONS (
        SALES_DATA.ORDER_ID AS ORDER_ID 
            WITH SYNONYMS=('transaction id', 'order number') 
            COMMENT='Unique identifier for each customer order.',
            
        SALES_DATA.ORDER_DATE AS ORDER_DATE 
            WITH SYNONYMS=('sale date', 'transaction date') 
            COMMENT='The date the order was placed.',
            
        SALES_DATA.CUSTOMER_NAME AS CUSTOMER_NAME 
            WITH SYNONYMS=('client', 'buyer') 
            COMMENT='The name of the customer who made the purchase.',
            
        SALES_DATA.MARKET_SEGMENT AS MARKET_SEGMENT 
            WITH SYNONYMS=('industry', 'customer category') 
            COMMENT='The market segment the customer belongs to, such as AUTOMOBILE or HOUSEHOLD.',
            
        SALES_DATA.NATION AS NATION 
            WITH SYNONYMS=('country', 'territory') 
            COMMENT='The country where the customer is located.',
            
        SALES_DATA.REGION AS REGION 
            WITH SYNONYMS=('continent', 'geographic area') 
            COMMENT='The broad geographic region such as ASIA, EUROPE, or AMERICA.',
            
        SALES_DATA.PRODUCT_NAME AS PRODUCT_NAME 
            WITH SYNONYMS=('item name', 'part name') 
            COMMENT='The name of the specific part or product sold.',
            
        SALES_DATA.PRODUCT_TYPE AS PRODUCT_TYPE 
            WITH SYNONYMS=('category', 'item type') 
            COMMENT='The category of the product.',
            
        SALES_DATA.LINE_STATUS AS LINE_STATUS 
            WITH SYNONYMS=('order status', 'fulfillment status') 
            COMMENT='The status of the line item, such as F for Finished or O for Open.'
    )
    WITH EXTENSION (CA='{
        "tables": [
            {
                "name": "SALES_DATA",
                "dimensions": [
                    {"name": "REGION", "sample_values": ["AMERICA", "EUROPE", "ASIA"]},
                    {"name": "MARKET_SEGMENT", "sample_values": ["AUTOMOBILE", "BUILDING", "HOUSEHOLD"]},
                    {"name": "LINE_STATUS", "sample_values": ["O", "F"]}
                ],
                "time_dimensions": [
                    {"name": "ORDER_DATE", "sample_values": ["1992-01-01", "1998-12-31"]}
                ],
                "facts": [
                    {"name": "TOTAL_NET_REVENUE", "sample_values": ["1500.50", "45000.00"]}
                ]
            }
        ],
        "verified_queries": [
            {
                "name": "Total revenue by region",
                "question": "What is the total net revenue for each region?",
                "sql": "SELECT REGION, SUM(NET_REVENUE) FROM V_INTEGRATED_SALES GROUP BY 1"
            },
            {
                "name": "Top customers in Automobile",
                "question": "Who are the top 5 customers in the Automobile segment by net revenue?",
                "sql": "SELECT CUSTOMER_NAME, SUM(NET_REVENUE) as REVENUE FROM V_INTEGRATED_SALES WHERE MARKET_SEGMENT = \'AUTOMOBILE\' GROUP BY 1 ORDER BY REVENUE DESC LIMIT 5"
            }
        ]
    }');

-- ============================================================================
-- STEP 4: Create Cortex Search Service
-- ============================================================================
-- File: sql/04-cortex/01_cortex_search_service.sql
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

-- ============================================================================
-- STEP 5: Create MCP Server
-- ============================================================================
-- File: sql/05-mcp-server/01_mcp_server_setup.sql
CREATE OR REPLACE MCP SERVER TPCH_PRODUCTS
  FROM SPECIFICATION $$
    tools:
      - name: "PRODUCT_ANALYTICS_TPCH"
        type: "CORTEX_SEARCH_SERVICE_QUERY"
        identifier: "TPCH_DATA_PRODUCT.ANALYTICS.PRODUCT_ANALYTICS_TPCH"
        description: "Cortex search service for all products"
        title: "Product Search"

      - name: "SV_SALES_PERFORMANCE"
        type: "CORTEX_ANALYST_MESSAGE"
        identifier: "TPCH_DATA_PRODUCT.ANALYTICS.SV_SALES_PERFORMANCE"
        description: "Semantic view for all tpch product tables"
        title: "Semantic view for product analytics"
  $$;

-- ============================================================================
