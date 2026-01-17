# Snowflake MCP (Model Context Protocol) Project

A comprehensive setup for accessing Snowflake data products through VS Code using the Model Context Protocol. This project demonstrates how to build a semantic layer on top of Snowflake's TPCH sample data with Cortex AI capabilities.

## Project Overview

This project enables:

- **Semantic Analytics**: Create a business-friendly semantic layer on top of raw data
- **AI-Powered Search**: Leverage Cortex Search Services for intelligent document retrieval
- **Smart Queries**: Use Cortex Analyst to answer business questions in natural language
- **Data Product Architecture**: Multi-layered approach (Silver → Gold layers)
- **VS Code Integration**: Query Snowflake directly from VS Code using MCP

## Project Structure

```
snowmcp/
├── sql/                              # All SQL setup scripts
│   ├── 01-setup/                    # Database and schema initialization
│   │   ├── 01_database_schema_setup.sql
│   │   └── 02_stage_setup.sql
│   ├── 02-tables/                   # Tables and views
│   │   ├── 01_integrated_sales_view.sql      # Silver layer view
│   │   ├── 02_sales_performance_kpi.sql      # Gold layer KPIs
│   │   ├── 03_parsed_pdf_table.sql
│   │   ├── 04_insert_parsed_pdf.sql
│   │   └── 05_product_chunk_table.sql
│   ├── 03-semantic-views/           # Cortex Analyst semantic views
│   │   └── 01_sales_performance_semantic_view.sql
│   ├── 04-cortex/                   # Cortex AI capabilities
│   │   └── 01_cortex_search_service.sql
│   └── 05-mcp-server/               # MCP server setup
│       └── 01_mcp_server_setup.sql
├── config/                          # Configuration files
│   ├── mcp.json.template            # MCP configuration template (safe to share)
│   └── MCP_SETUP.md                 # Configuration instructions
├── docs/                            # Documentation
├── create_business_report.py         # Python script for reporting
├── create_cortex_guide.py           # Python script for Cortex setup
└── README.md                        # This file
```

## Data Architecture

### Silver Layer
**View**: `V_INTEGRATED_SALES`
- Combines TPCH sample data into a unified sales view
- Includes customer, order, product, region, and nation data
- Calculated fields: Net Revenue, Line Status

### Gold Layer
**Table**: `SALES_PERFORMANCE_KPI`
- Aggregated metrics at region/nation/segment level
- Monthly time buckets
- KPIs: Total Orders, Units Sold, Net Revenue, Average Discount

### Semantic Layer
**Semantic View**: `SV_SALES_PERFORMANCE`
- Business-friendly view for Cortex Analyst
- Defines facts: Quantity, Gross Revenue, Net Revenue
- Defines dimensions: Order ID, Date, Customer, Region, Product, etc.
- Includes verified queries and sample values

### Search & RAG Layer
**Cortex Search Service**: `PRODUCT_ANALYTICS_TPCH`
- Enables semantic search over parsed documents
- Uses embeddings for intelligent retrieval
- Supports document parsing with OCR

## Getting Started

### Prerequisites
- Snowflake account with Cortex capabilities
- VS Code with MCP extension
- Python 3.8+ (for helper scripts)

### Step 1: Configure MCP

1. Copy the template:
   ```bash
   cp config/mcp.json.template .vscode/mcp.json
   ```

2. Update with your Snowflake credentials:
   - Replace `{SNOWFLAKE_ACCOUNT}` with your account ID
   - Replace `{SNOWFLAKE_JWT_TOKEN}` with your JWT token

See [config/MCP_SETUP.md](config/MCP_SETUP.md) for detailed instructions.

### Step 2: Execute SQL Setup

Run the SQL scripts in order:

1. **Setup**
   ```sql
   -- Run all files in sql/01-setup/
   ```

2. **Create Tables & Views**
   ```sql
   -- Run all files in sql/02-tables/
   ```

3. **Create Semantic Views**
   ```sql
   -- Run all files in sql/03-semantic-views/
   ```

4. **Configure Cortex**
   ```sql
   -- Run all files in sql/04-cortex/
   ```

5. **Initialize MCP Server**
   ```sql
   -- Run all files in sql/05-mcp-server/
   ```

### Step 3: Use in VS Code

Once configured, you can:

1. **Query the Semantic View**: Ask questions about sales performance
2. **Search Products**: Use Cortex Search to find product information
3. **Generate Reports**: Get AI-powered insights directly in VS Code

## Key Features

### 1. Data Product Pattern
- Multi-layered architecture (raw → silver → gold)
- Business-friendly naming and structure
- Optimized for analytics and reporting

### 2. Semantic Understanding
- Cortex Analyst understands business context
- Natural language query support
- Verified queries for common questions

### 3. AI-Powered Search
- Document parsing with OCR
- Semantic chunking for RAG
- Intelligent retrieval with embeddings

### 4. MCP Integration
- Direct Snowflake access from VS Code
- Two primary tools:
  - **PRODUCT_ANALYTICS_TPCH**: Cortex Search Service
  - **SV_SALES_PERFORMANCE**: Semantic View for Analytics

## Sample Queries

### Sales Performance
```sql
SELECT REGION, SUM(NET_REVENUE) 
FROM V_INTEGRATED_SALES 
GROUP BY 1
```

### Top Customers by Segment
```sql
SELECT CUSTOMER_NAME, SUM(NET_REVENUE) as REVENUE 
FROM V_INTEGRATED_SALES 
WHERE MARKET_SEGMENT = 'AUTOMOBILE' 
GROUP BY 1 
ORDER BY REVENUE DESC 
LIMIT 5
```

### Using Cortex Analyst (Natural Language)
```
"What is the total net revenue for each region?"
"Who are the top 5 customers in the Automobile segment?"
"Show me sales trends by month across all regions"
```

## Security Considerations

⚠️ **Important**: Never commit `mcp.json` to version control
- Store credentials in environment variables
- Use the template file for sharing
- Rotate JWT tokens regularly
- Follow Snowflake security best practices

## Files to Never Commit
- `.vscode/mcp.json` - Contains credentials
- `.env` - Environment variables
- `config/mcp.json` - Actual configuration

## Contributing

1. Keep SQL organized by layer
2. Add comments explaining business logic
3. Update documentation when adding features
4. Use the template for configuration examples

## Useful Resources

- [Snowflake MCP Documentation](https://docs.snowflake.com/en/user-guide/mcp)
- [Cortex Analyst Guide](https://docs.snowflake.com/en/user-guide/cortex-analyst)
- [Cortex Search Services](https://docs.snowflake.com/en/user-guide/cortex-search-service)
- [TPCH Sample Data](https://docs.snowflake.com/en/user-guide/sample-data-tpch)

## License

[Choose your license - e.g., MIT, Apache 2.0]

## Support

For issues or questions:
1. Check the docs/ folder
2. Review the SQL scripts
3. Refer to [config/MCP_SETUP.md](config/MCP_SETUP.md)

---

**Happy analyzing!** 🚀
