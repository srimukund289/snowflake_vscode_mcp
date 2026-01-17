-- Gold Layer: Executive Revenue Dashboard (Data Product)
-- Aggregated KPI metrics at region/nation/segment level by month
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
