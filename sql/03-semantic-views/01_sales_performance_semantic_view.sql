-- Create the Semantic View for Cortex Analyst
-- Defines facts, dimensions, and provides Cortex Analyst with business context
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
