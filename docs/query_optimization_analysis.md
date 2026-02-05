# Query Optimization Analysis - SNOWFLAKE_SAMPLE_DATA

**Date:** February 5, 2026  
**Analysis:** Slow queries (>5 minutes execution time)

---

## Summary of Slow Queries Found

I identified **1 query** against the SNOWFLAKE_SAMPLE_DATA database that exceeded 5 minutes:

**Query ID:** `01c230c5-0000-9410-0014-ccdf002840de`
- **Execution Time:** 396.85 seconds (~6.6 minutes)
- **Database/Schema:** SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000
- **Warehouse:** COMPUTE_WH (X-Small)
- **Data Scanned:** 148.94 GB
- **Partitions Scanned:** 32,773 out of 34,315 (95.5%)
- **Local Spillage:** 32.86 GB
- **Cache Hit Rate:** 0.3%

---

## Query Pattern Analysis

### Query Type
Multi-table join with correlated subqueries (EXISTS/NOT EXISTS)

### Query Structure
```sql
SELECT
    s_name,
    COUNT(*) AS numwait
FROM
    supplier,
    lineitem l1,
    orders,
    nation
WHERE
    s_suppkey = l1.l_suppkey
    AND o_orderkey = l1.l_orderkey
    AND o_orderstatus = 'F'
    AND l1.l_receiptdate > l1.l_commitdate
    AND EXISTS (
        SELECT * FROM lineitem l2
        WHERE l2.l_orderkey = l1.l_orderkey
        AND l2.l_suppkey <> l1.l_suppkey
    )
    AND NOT EXISTS (
        SELECT * FROM lineitem l3
        WHERE l3.l_orderkey = l1.l_orderkey
        AND l3.l_suppkey <> l1.l_suppkey
        AND l3.l_receiptdate > l3.l_commitdate
    )
    AND s_nationkey = n_nationkey
    AND n_name = 'SAUDI ARABIA'
GROUP BY
    s_name
ORDER BY
    numwait DESC,
    s_name
LIMIT 100;
```

### Query Characteristics
- Joins 4 tables: supplier, lineitem, orders, nation
- Contains 2 correlated subqueries for existence checks
- Performs aggregation (COUNT, GROUP BY)
- Includes multiple filter conditions

---

## Key Performance Bottlenecks Identified

1. **High Partition Scan Rate (95.5%)**
   - Nearly all partitions were scanned, indicating poor partition pruning
   - Only 1,542 partitions could be skipped out of 34,315 total

2. **Significant Local Spillage (32.86 GB)**
   - Data exceeded memory and spilled to local disk
   - Indicates warehouse is undersized for this workload

3. **Low Cache Utilization (0.3%)**
   - Minimal benefit from result caching
   - Query pattern likely varies preventing cache hits

4. **Undersized Warehouse (X-Small)**
   - X-Small warehouse insufficient for 149 GB scan with complex joins
   - Memory constraints causing spillage and slow performance

---

## Specific Snowflake Optimization Recommendations

### 1. Clustering Keys Implementation ⭐ (Highest Impact)

**Problem:** 95.5% partition scan indicates poor data organization for the query filters.

**Solution:** Add clustering keys on frequently filtered columns:

```sql
-- Cluster the LINEITEM table by order key and receipt date
ALTER TABLE SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.LINEITEM 
CLUSTER BY (L_ORDERKEY, L_RECEIPTDATE);

-- Cluster the ORDERS table by order key and status
ALTER TABLE SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.ORDERS 
CLUSTER BY (O_ORDERKEY, O_ORDERSTATUS);

-- Cluster the SUPPLIER table by nation key
ALTER TABLE SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.SUPPLIER 
CLUSTER BY (S_NATIONKEY);
```

**Expected Impact:** 
- Reduce partition scanning from 95.5% to 20-40%
- Cut scan time by 60-75%
- Significantly reduce data scanned (from 149 GB to ~30-60 GB)

**Monitoring:**
```sql
-- Check clustering depth
SELECT SYSTEM$CLUSTERING_INFORMATION('LINEITEM', '(L_ORDERKEY, L_RECEIPTDATE)');

-- Monitor clustering health
SELECT * FROM TABLE(INFORMATION_SCHEMA.CLUSTERING_INFORMATION(
    TABLE_NAME => 'LINEITEM'
));
```

---

### 2. Warehouse Scaling (Immediate Performance Gain)

**Problem:** 32.86 GB spilled to local storage indicates insufficient memory for joins.

**Solution:** Scale up the warehouse:

```sql
-- Option 1: Temporarily scale up for this query type
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';

-- Option 2: Create a dedicated warehouse for heavy analytical queries
CREATE WAREHOUSE ANALYTICS_WH WITH 
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for complex analytical queries with large joins';

-- Use the analytics warehouse
USE WAREHOUSE ANALYTICS_WH;
```

**Expected Impact:** 
- Eliminate memory spillage (32.86 GB → 0 GB)
- 4-8x faster execution (X-Small → Large = 16x more compute)
- Estimated execution time: 50-100 seconds
- Better parallelism for complex joins

**Cost Consideration:**
- Large warehouse uses 16x credits of X-Small
- But executes 4-8x faster = 2-4x actual cost
- Worth it for queries >5 minutes

---

### 3. Query Rewriting (Optimize Subquery Pattern)

**Problem:** Correlated EXISTS/NOT EXISTS subqueries are expensive with large datasets.

**Solution:** Rewrite using LEFT JOINs and window functions:

```sql
-- Optimized version using CTEs and explicit joins
WITH lineitem_flags AS (
    SELECT 
        l1.l_orderkey,
        l1.l_suppkey,
        l1.l_receiptdate > l1.l_commitdate AS is_late,
        COUNT(DISTINCT l2.l_suppkey) AS other_suppliers,
        SUM(CASE WHEN l3.l_suppkey <> l1.l_suppkey 
                 AND l3.l_receiptdate > l3.l_commitdate 
            THEN 1 ELSE 0 END) AS other_late_suppliers
    FROM lineitem l1
    LEFT JOIN lineitem l2 
        ON l2.l_orderkey = l1.l_orderkey 
        AND l2.l_suppkey <> l1.l_suppkey
    LEFT JOIN lineitem l3 
        ON l3.l_orderkey = l1.l_orderkey
    WHERE l1.l_receiptdate > l1.l_commitdate
    GROUP BY l1.l_orderkey, l1.l_suppkey, is_late
)
SELECT 
    s.s_name,
    COUNT(*) AS numwait
FROM supplier s
INNER JOIN lineitem_flags lf ON s.s_suppkey = lf.l_suppkey
INNER JOIN orders o ON o.o_orderkey = lf.l_orderkey
INNER JOIN nation n ON s.s_nationkey = n.n_nationkey
WHERE o.o_orderstatus = 'F'
    AND lf.is_late = TRUE
    AND lf.other_suppliers > 0
    AND lf.other_late_suppliers = 0
    AND n.n_name = 'SAUDI ARABIA'
GROUP BY s.s_name
ORDER BY numwait DESC, s.s_name
LIMIT 100;
```

**Expected Impact:** 
- 30-50% reduction in execution time
- Reduced correlated subquery overhead
- Better query plan optimization opportunities

---

### 4. Materialized Views (For Recurring Queries)

**Problem:** Complex joins executed repeatedly waste compute.

**Solution:** Create a materialized view for this query pattern:

```sql
-- Create materialized view for supplier wait times analysis
CREATE MATERIALIZED VIEW MV_SUPPLIER_WAIT_TIMES AS
SELECT 
    s.s_suppkey,
    s.s_name,
    n.n_name as nation_name,
    o.o_orderstatus,
    l1.l_orderkey,
    l1.l_receiptdate > l1.l_commitdate as is_late,
    l1.l_receiptdate,
    l1.l_commitdate
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.supplier s
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.nation n 
    ON s.s_nationkey = n.n_nationkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.lineitem l1 
    ON s.s_suppkey = l1.l_suppkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.orders o 
    ON o.o_orderkey = l1.l_orderkey;

-- Query against the materialized view
SELECT 
    s_name,
    COUNT(*) AS numwait
FROM MV_SUPPLIER_WAIT_TIMES
WHERE o_orderstatus = 'F'
    AND is_late = TRUE
    AND nation_name = 'SAUDI ARABIA'
GROUP BY s_name
ORDER BY numwait DESC, s_name
LIMIT 100;
```

**Expected Impact:** 
- Near-instant query execution (sub-second)
- Automatic refresh keeps data current
- Significant cost savings for frequently-run queries

**Maintenance:**
```sql
-- Check materialized view status
SHOW MATERIALIZED VIEWS LIKE 'MV_SUPPLIER_WAIT_TIMES';

-- Manually refresh if needed
ALTER MATERIALIZED VIEW MV_SUPPLIER_WAIT_TIMES REFRESH;
```

---

### 5. Search Optimization Service (Improve Point Lookups)

**Problem:** Filtering on nation name requires full scans.

**Solution:** Enable search optimization for selective filters:

```sql
-- Enable search optimization on NATION table
ALTER TABLE SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.NATION 
ADD SEARCH OPTIMIZATION ON EQUALITY(N_NAME);

-- Enable search optimization on ORDERS table
ALTER TABLE SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.ORDERS 
ADD SEARCH OPTIMIZATION ON EQUALITY(O_ORDERSTATUS);

-- Check search optimization status
SELECT * FROM TABLE(INFORMATION_SCHEMA.SEARCH_OPTIMIZATION_HISTORY(
    TABLE_NAME => 'NATION'
));
```

**Expected Impact:** 
- 3-5x faster for selective equality filters
- Particularly effective for low-cardinality columns
- Reduces micro-partition scanning

---

### 6. Result Caching Strategy

**Problem:** Only 0.3% cache hit rate.

**Solution:** Optimize for result cache utilization:

```sql
-- Enable query result caching
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- For parameterized queries, use consistent formatting
-- Bad (won't cache):
-- WHERE n_name = 'SAUDI ARABIA'
-- WHERE n_name='SAUDI ARABIA'

-- Good (consistent formatting enables caching):
-- WHERE n_name = 'SAUDI ARABIA'

-- Set warehouse to maximize cache hits
ALTER WAREHOUSE COMPUTE_WH SET 
    AUTO_SUSPEND = 300  -- 5 minutes to keep cache warm
    AUTO_RESUME = TRUE;
```

**Expected Impact:** 
- Instant results for repeated queries (24-hour cache retention)
- Zero compute cost for cache hits
- Particularly effective for dashboard queries

---

## Recommended Implementation Priority

### Phase 1: Immediate (Today)
1. **Scale warehouse to MEDIUM or LARGE** for this workload
   - Action: `ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';`
   - Impact: 4-8x performance improvement immediately
   - Time to implement: 1 minute

### Phase 2: Short-term (This Week)
2. **Implement clustering keys** on LINEITEM and ORDERS tables
   - Action: Run clustering ALTER TABLE statements
   - Impact: 60-75% reduction in data scanned
   - Time to implement: 2-4 hours (including initial clustering)

3. **Enable search optimization** on NATION and ORDERS tables
   - Action: Run search optimization ALTER TABLE statements
   - Impact: 3-5x faster point lookups
   - Time to implement: 30 minutes

### Phase 3: Medium-term (This Month)
4. **Rewrite query** to eliminate correlated subqueries
   - Action: Deploy optimized query version
   - Impact: 30-50% additional improvement
   - Time to implement: 2-3 hours (including testing)

5. **Enable result caching** with consistent query patterns
   - Action: Standardize query formatting
   - Impact: Zero-cost repeated query execution
   - Time to implement: 1 hour

### Phase 4: Long-term (As Needed)
6. **Create materialized views** if query runs frequently (>10 times/day)
   - Action: Deploy materialized view
   - Impact: Sub-second query execution
   - Time to implement: 4-6 hours (including testing and monitoring)

---

## Expected Combined Impact

Implementing all recommendations should reduce execution time:

| Phase | Execution Time | Improvement | Credits Used |
|-------|---------------|-------------|--------------|
| Baseline (X-Small) | 397 seconds | - | 0.011 |
| Phase 1 (Large warehouse) | 50-100 seconds | 75-87% | 0.022-0.044 |
| Phase 2 (+ Clustering) | 15-30 seconds | 92-96% | 0.007-0.013 |
| Phase 3 (+ Query rewrite) | 10-20 seconds | 95-97% | 0.004-0.009 |
| Phase 4 (Materialized view) | <1 second | 99%+ | 0.000 (cache hit) |

**Overall Impact:** 90%+ improvement in execution time while maintaining or reducing cost through better resource utilization.

---

## Monitoring Queries

### Check Query Performance Over Time
```sql
SELECT 
    DATE_TRUNC('day', start_time) as query_date,
    COUNT(*) as query_count,
    AVG(total_elapsed_time / 1000) as avg_execution_seconds,
    AVG(bytes_scanned / (1024*1024*1024)) as avg_gb_scanned,
    AVG(partitions_scanned::FLOAT / NULLIF(partitions_total, 0) * 100) as avg_partition_scan_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE database_name = 'SNOWFLAKE_SAMPLE_DATA'
    AND query_text LIKE '%numwait%'
    AND start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY query_date
ORDER BY query_date DESC;
```

### Monitor Clustering Health
```sql
SELECT 
    table_name,
    clustering_key,
    average_depth,
    total_constant_partition_count,
    average_overlaps
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
WHERE table_name IN ('LINEITEM', 'ORDERS', 'SUPPLIER')
    AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

### Monitor Warehouse Utilization
```sql
SELECT 
    warehouse_name,
    AVG(avg_running) as avg_concurrent_queries,
    AVG(avg_queued_load) as avg_queued,
    SUM(credits_used) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
WHERE warehouse_name IN ('COMPUTE_WH', 'ANALYTICS_WH')
    AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name;
```

---

## Conclusion

The identified slow query can be optimized from **397 seconds to under 20 seconds** through a combination of:
- Warehouse sizing (immediate impact)
- Clustering keys (long-term data organization)
- Query rewriting (algorithm optimization)
- Caching strategies (eliminate repeat costs)

The most critical optimization is implementing clustering keys, which will benefit not just this query but all queries accessing these large tables.
