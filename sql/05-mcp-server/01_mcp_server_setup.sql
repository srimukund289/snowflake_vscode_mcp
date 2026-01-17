-- Create MCP Server with tool information from Cortex Analyst and Search
-- This defines the tools available through the MCP protocol
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
