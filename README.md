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
snowflake_vscode_mcp/
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
│   └── mcp.json.template            # MCP configuration template (safe to share)
├── docs/                            # Documentation
├── SETUP_COMPLETE.sql               # Initial database and schema setup
├── NETWORK_POLICY.sql               # IP whitelist security policy
├── README.md                        # This file
└── .gitignore                       # Git ignore rules
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

## Why Snowflake MCP with Cortex Agents?

Instead of jumping between Snowflake UI and your IDE, Snowflake MCP transforms VS Code Copilot into a **data-aware assistant**:

- **Intelligence where you type**: Your VS Code Copilot becomes data-aware, using the MCP bridge to ask Cortex Agents for ground truth about your Snowflake data
- **Zero-Copy Context**: No need to copy-paste schemas; the agent "sees" the schema through the MCP server
- **Native Orchestration**: Ask Copilot to "summarize the latest sales trends using the Cortex Analyst agent," and results appear right in your sidebar
- **Reduced Context Switching**: Your data exploration stays in VS Code
- **Faster Development**: Natural language queries beat manual SQL worksheet navigation
- **Better Developer Experience**: Copilot understands your data structure and can assist proactively

## Getting Started

### Quick Start (One-Click Setup - Under 5 Minutes)

If you just want to get up and running quickly:

```bash
# 1. Clone or fork this repository
git clone https://github.com/YOUR_USERNAME/snowflake_vscode_mcp.git
cd snowflake_vscode_mcp

# 2. Copy template files
cp config/mcp.json.template .vscode/mcp.json
# Create .env file for credentials (will NOT be committed)
echo "SNOWFLAKE_ACCOUNT=your_account_id" > .env
echo "SNOWFLAKE_PAT_TOKEN=your_pat_token" >> .env

# 3. Install VS Code extensions from command line (optional)
code --install-extension ms-copilot.copilot-chat
code --install-extension Snowflake.snowflake-mcp

# 4. Update .env with your actual credentials
# Edit .env and replace placeholders
```

Then continue with detailed steps below.

### Detailed Setup Guide

**Required Snowflake Account Setup:**
- Snowflake account with Cortex capabilities enabled
- Personal Access Token (PAT) - to be generated later
- Public IP address (for network policy whitelist)

**Required VS Code Extensions:**
1. **GitHub Copilot Chat** (ms-copilot.copilot-chat)
   - Provides the AI-powered chat interface in VS Code
   - Install: Open VS Code → Extensions → Search "GitHub Copilot Chat" → Install

2. **MCP (Model Context Protocol)** (Snowflake.snowflake-mcp)
   - Enables VS Code to connect to your Snowflake MCP server
   - Install: Open VS Code → Extensions → Search "Snowflake MCP" → Install

**Optional but Recommended:**
- Python 3.8+ (for helper scripts and local testing)
- Git (for version control)

### Step 1: Execute the Setup Scripts

1. In your Snowflake environment, run:
   ```sql
   -- Execute: SETUP_COMPLETE.sql
   ```
   This creates the required databases (e.g., `TPCH_DATA_PRODUCT`) and analytics schemas needed for the MCP server and Cortex tools.

2. Run the remaining SQL scripts in order:
   ```sql
   -- sql/01-setup/01_database_schema_setup.sql
   -- sql/01-setup/02_stage_setup.sql
   -- sql/02-tables/ (all files)
   -- sql/03-semantic-views/ (all files)
   -- sql/04-cortex/ (all files)
   -- sql/05-mcp-server/ (all files)
   ```

### Step 2: Upload Reference PDFs to Snowflake Stage (Required)

Cortex Search and Cortex Analyst rely on documents stored in Snowflake stages for unstructured context.

1. Navigate in Snowflake UI: **Data → Databases → TPCH_DATA_PRODUCT**
2. Open the configured internal stage (created by `SETUP_COMPLETE.sql`)
3. Upload the PDF files located in the repo's `config/` directory

### Step 3: Security First - Configure Network Policy

Snowflake requires a secure handshake between your local machine and the MCP endpoint.

1. Find your public IP address at [whatismyip.com](https://whatismyip.com)
2. In your Snowflake environment, execute:
   ```sql
   -- Execute: NETWORK_POLICY.sql
   -- Make sure to replace your public IP address
   ```
   This whitelists your IP address so only authorized machines can access your MCP server.

   **Pro Tip**: Store your public IP in a safe location. If your ISP changes it, you'll need to update the network policy.

### Step 4: Configure VS Code

VS Code needs to know where your Snowflake MCP server lives. Use environment variables to keep credentials secure.

#### Option A: Using Environment Variables (Recommended)

1. Create a `.env` file in your project root:
   ```bash
   SNOWFLAKE_ACCOUNT=your_account_id
   SNOWFLAKE_PAT_TOKEN=your_pat_token
   ```

2. **CRITICAL**: Add `.env` to `.gitignore` (already included in this repo)
   ```bash
   # Verify .gitignore contains:
   .env
   .env.local
   .env.*.local
   ```

3. Copy the template and use environment variables:
   ```bash
   cp config/mcp.json.template .vscode/mcp.json
   ```

4. Update `.vscode/mcp.json` to reference environment variables:
   ```json
   {
     "servers": {
       "Snowflake": {
         "url": "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/TPCH_DATA_PRODUCT/schemas/ANALYTICS/mcp-servers/TPCH_PRODUCTS",
         "headers": {
           "Authorization": "Bearer ${SNOWFLAKE_PAT_TOKEN}"
         }
       }
     }
   }
   ```

#### Option B: Direct Configuration (Development Only)

If using direct configuration, follow these steps:

1. Copy the template:
   ```bash
   cp config/mcp.json.template .vscode/mcp.json
   ```

2. Replace the placeholders:
   - `{SNOWFLAKE_ACCOUNT}`: Your Snowflake account locator (find it in your Snowflake URL)
   - `{SNOWFLAKE_PAT_TOKEN}`: Your Personal Access Token (generate in Snowflake → Admin → Users & Roles)

**⚠️ CRITICAL Security Warning**: 
- Never commit `.vscode/mcp.json` to version control
- Never commit `.env` files with real credentials
- Both are already listed in `.gitignore`—verify before committing
- Use a **dedicated service user with Least Privilege** roles (e.g., read-only on specific schemas)

### Step 5: Activate the Connection

1. Save your configuration
2. Look for the **"Start Server"** option in your VS Code status bar or MCP extension pane
3. Click to initialize the connection (you should see a confirmation message)
4. Open the **Copilot Agent** chat and select **'add context'** → select **'tools'** in the dropdown
5. Type **'Snowflake'** and select it as your active MCP tool
6. Press enter to confirm

You're now connected! Your data is ready to talk.

### Step 6: Query Your Data with Natural Language

This is where the magic happens. You can now ask Copilot questions like:

- "What are the top-selling products in the TPCH dataset?"
- "Which region generated the highest Total Net Revenue in December 1996?"
- "List the top 5 nations by Total Orders for the 'FURNITURE' market segment."
- "Find any internal reports discussing why the 'BUILDING' segment in CANADA had higher-than-average discounts in late 1996."

Behind the scenes, Copilot uses the MCP server to fetch metadata and execute queries — all without you leaving your code editor.

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

## Key Takeaways

✅ **Reduced Context Switching**: Your data exploration stays in VS Code  
✅ **Faster Development**: Natural language queries beat manual SQL worksheet navigation  
✅ **Better Developer Experience**: Copilot understands your data structure and can assist proactively  
✅ **Security Built-in**: IP whitelisting and PAT tokens keep your data safe

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

### Authentication Methods

**Tutorial Standard: Personal Access Token (PAT)**
- Used in this tutorial for ease of setup
- Generate in Snowflake → Admin → Users & Roles
- Use a **dedicated service user account** with minimal required permissions only (Least Privilege)
- Never use your admin account for this
- Rotate tokens regularly (every 90 days recommended)

**Production-Grade Alternatives:**

- **Key-Pair Authentication** (Recommended for production)
  - Generate and use RSA key pairs instead of tokens
  - More secure than PAT tokens
  - Cryptographically signed connections
  - Setup: [Snowflake Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)
  
- **OAuth 2.0** (Best for enterprise and teams)
  - Delegated access without sharing credentials
  - Supports single sign-on (SSO)
  - Ideal for team collaboration
  - Setup: [Snowflake OAuth](https://docs.snowflake.com/en/user-guide/oauth-intro)

### Credential Management Best Practices

✅ **DO:**
- Store all credentials in `.env` files (this file is in `.gitignore` and won't be committed)
- Use environment variables in configuration files
- Create dedicated **service accounts** with **Least Privilege** (minimal permissions needed)
- Rotate credentials regularly (every 90 days for PAT tokens)
- Review `.gitignore` file to ensure sensitive files are excluded before every commit
- Never commit `.vscode/mcp.json` with hardcoded credentials

❌ **DO NOT:**
- Hardcode credentials in any configuration files
- Commit `.env`, `.vscode/mcp.json`, or `config/mcp.json` to version control
- Use admin/personal accounts for service integrations
- Share `.env` files via email, Slack, or any communication channel
- Reuse the same credentials across multiple projects or environments
- Store passwords in plain text anywhere in your codebase

## Query Tagging & Monitoring

### Tracking MCP Queries in Snowflake

When queries are executed through the VS Code MCP agent, Snowflake automatically tags them for easy identification and monitoring. Administrators can view these in the Snowflake Query History.

**View MCP Agent Queries:**

1. In Snowflake UI, navigate to **Monitor → Query History**
2. Filter by queries from your MCP service user account
3. Look for queries with tags like:
   - Source: `VS Code MCP Agent`
   - Application: `snowflake-mcp`

**Example Query Tag Visibility:**
```sql
-- In Snowflake Query History, you'll see:
-- Query Tag: source=vscode_mcp|user=<service_account>|timestamp=<timestamp>
-- Application: snowflake-mcp
```

**Admin Benefits:**
- 📊 **Cost Attribution**: Track compute costs per team/project running MCP queries
- 🔍 **Query Auditing**: Identify all queries from VS Code MCP agents
- 📈 **Performance Monitoring**: See which queries consume the most resources
- 🛡️ **Security & Compliance**: Audit data access from IDE tools

**To Enable Custom Query Tags (Advanced):**

If you want to add custom tags for your team or project:

1. Modify your connection config to include custom tags:
   ```json
   {
     "servers": {
       "Snowflake": {
         "url": "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/TPCH_DATA_PRODUCT/schemas/ANALYTICS/mcp-servers/TPCH_PRODUCTS",
         "headers": {
           "Authorization": "Bearer ${SNOWFLAKE_PAT_TOKEN}"
         },
         "query_tag": "team=data_engineering|project=mcp_integration|env=prod"
       }
     }
   }
   ```

2. All queries from this MCP agent will appear with these tags in Snowflake's Query History

**Viewing Query Metrics:**

```sql
-- Run this in Snowflake to see all MCP queries:
SELECT 
  QUERY_ID,
  QUERY_TEXT,
  USER_NAME,
  QUERY_TAG,
  EXECUTION_TIME,
  ROWS_SCANNED,
  BYTES_SCANNED,
  QUERY_HASH
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TAG ILIKE '%vscode_mcp%'
  OR QUERY_TAG ILIKE '%mcp_integration%'
ORDER BY START_TIME DESC
LIMIT 50;
```

## Files to Never Commit

These are already in `.gitignore`, but verify before committing:
- `.vscode/mcp.json` - Contains API credentials and PAT tokens
- `.env` - Environment variables with secrets
- `.env.local` - Local environment overrides
- `.env.*.local` - Environment-specific overrides
- `config/mcp.json` - Actual MCP configuration with credentials

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

## What's Next?

Once you're comfortable with basic queries, explore advanced capabilities:

- **Creating reusable data transformations**: Build custom SQL transformations for your specific use cases
- **Building complex analytical workflows**: Chain multiple Cortex queries together for sophisticated analysis
- **Sharing query patterns with your team**: Collaborate on common data patterns and queries

The future of data engineering isn't about jumping between tools — it's about bringing the tools to where you work.

**Ready to eliminate context-switching? Start with Step 1 above and connect Snowflake to VS Code today!**


---

**Happy analyzing!** 🚀
