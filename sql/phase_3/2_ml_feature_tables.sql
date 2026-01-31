-- ============================================================================
-- Phase 3.2 - ML Feature Table for Promo Optimizer
-- Purpose: Create feature table for promo ROI prediction
-- Created: 2026-01-31 | Fixed for actual schema
-- ============================================================================

USE DATABASE ANYCOMPANY_LAB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- ML_PROMO_EFFECTIVENESS: Training data for promo ROI optimizer
-- ============================================================================

CREATE OR REPLACE TABLE ANALYTICS.ML_PROMO_EFFECTIVENESS AS
WITH promo_sales AS (
    -- Calculate sales during each promotion
    SELECT 
        p.PROMOTION_ID,
        p.PRODUCT_CATEGORY,
        p.START_DATE,
        p.END_DATE,
        p.DISCOUNT_PERCENTAGE,
        p.PROMOTION_TYPE,
        p.REGION,
        DATEDIFF(day, p.START_DATE, p.END_DATE) + 1 AS DURATION_DAYS,
        
        -- Sales during promo (from financial transactions where type = 'Sale')
        COUNT(DISTINCT t.TRANSACTION_ID) AS TRANSACTIONS_COUNT,
        SUM(t.AMOUNT) AS TOTAL_SALES,
        AVG(t.AMOUNT) AS AVG_TRANSACTION_VALUE
        
    FROM SILVER.PROMOTIONS_CLEAN p
    LEFT JOIN SILVER.FINANCIAL_TRANSACTIONS_CLEAN t 
        ON t.TRANSACTION_DATE BETWEEN p.START_DATE AND p.END_DATE
        AND t.REGION = p.REGION
        AND t.TRANSACTION_TYPE = 'Sale'
    GROUP BY 1,2,3,4,5,6,7,8
),
baseline_sales AS (
    -- Calculate baseline sales (30 days before promo, same region)
    SELECT 
        p.PROMOTION_ID,
        AVG(t.AMOUNT) AS BASELINE_AVG_TRANSACTION,
        COUNT(DISTINCT t.TRANSACTION_ID) / 30.0 AS BASELINE_DAILY_TRANSACTIONS,
        SUM(t.AMOUNT) / 30.0 AS BASELINE_DAILY_SALES
        
    FROM SILVER.PROMOTIONS_CLEAN p
    LEFT JOIN SILVER.FINANCIAL_TRANSACTIONS_CLEAN t 
        ON t.TRANSACTION_DATE BETWEEN DATEADD(day, -30, p.START_DATE) 
                                  AND DATEADD(day, -1, p.START_DATE)
        AND t.REGION = p.REGION
        AND t.TRANSACTION_TYPE = 'Sale'
    GROUP BY p.PROMOTION_ID
),
campaign_overlap AS (
    -- Check if promo overlaps with campaigns
    SELECT 
        p.PROMOTION_ID,
        MAX(CASE WHEN c.CAMPAIGN_ID IS NOT NULL THEN 1 ELSE 0 END) AS HAS_CAMPAIGN_OVERLAP,
        COUNT(DISTINCT c.CAMPAIGN_ID) AS NUM_OVERLAPPING_CAMPAIGNS
    FROM SILVER.PROMOTIONS_CLEAN p
    LEFT JOIN SILVER.MARKETING_CAMPAIGNS_CLEAN c 
        ON c.REGION = p.REGION
        AND (c.START_DATE <= p.END_DATE AND c.END_DATE >= p.START_DATE)
    GROUP BY p.PROMOTION_ID
),
seasonality AS (
    -- Add temporal features
    SELECT 
        PROMOTION_ID,
        EXTRACT(MONTH FROM START_DATE) AS START_MONTH,
        EXTRACT(QUARTER FROM START_DATE) AS START_QUARTER,
        DAYOFWEEK(START_DATE) AS START_DAY_OF_WEEK,
        CASE 
            WHEN EXTRACT(MONTH FROM START_DATE) IN (11, 12) THEN 1 
            ELSE 0 
        END AS IS_HOLIDAY_SEASON,
        CASE 
            WHEN DAYOFWEEK(START_DATE) IN (0, 6) THEN 1 
            ELSE 0 
        END AS STARTS_ON_WEEKEND
    FROM SILVER.PROMOTIONS_CLEAN
)

SELECT 
    ps.PROMOTION_ID,
    ps.PRODUCT_CATEGORY,
    ps.PROMOTION_TYPE,
    ps.REGION,
    ps.DISCOUNT_PERCENTAGE,
    ps.DURATION_DAYS,
    ps.START_DATE,
    ps.END_DATE,
    
    -- Sales metrics
    ps.TRANSACTIONS_COUNT,
    ps.TOTAL_SALES,
    ps.AVG_TRANSACTION_VALUE,
    
    -- Baseline comparison
    COALESCE(bs.BASELINE_AVG_TRANSACTION, 0) AS BASELINE_AVG_TRANSACTION,
    COALESCE(bs.BASELINE_DAILY_TRANSACTIONS, 0) AS BASELINE_DAILY_TRANSACTIONS,
    COALESCE(bs.BASELINE_DAILY_SALES, 0) AS BASELINE_DAILY_SALES,
    
    -- Campaign context
    COALESCE(co.HAS_CAMPAIGN_OVERLAP, 0) AS HAS_CAMPAIGN_OVERLAP,
    COALESCE(co.NUM_OVERLAPPING_CAMPAIGNS, 0) AS NUM_OVERLAPPING_CAMPAIGNS,
    
    -- Temporal features
    s.START_MONTH,
    s.START_QUARTER,
    s.START_DAY_OF_WEEK,
    s.IS_HOLIDAY_SEASON,
    s.STARTS_ON_WEEKEND,
    
    -- Target variables (ROI proxies)
    CASE 
        WHEN bs.BASELINE_DAILY_SALES > 0 
        THEN ((ps.TOTAL_SALES / ps.DURATION_DAYS) - bs.BASELINE_DAILY_SALES) / bs.BASELINE_DAILY_SALES 
        ELSE 0 
    END AS SALES_LIFT_RATIO,
    
    CASE 
        WHEN ps.TOTAL_SALES > bs.BASELINE_DAILY_SALES * ps.DURATION_DAYS 
        THEN 1 
        ELSE 0 
    END AS IS_SUCCESSFUL,
    
    -- Estimated promo cost (proxy: discount × sales volume)
    ps.TOTAL_SALES * ps.DISCOUNT_PERCENTAGE AS ESTIMATED_PROMO_COST,
    
    -- ROI proxy = (incremental sales) / (estimated cost)
    CASE 
        WHEN ps.TOTAL_SALES * ps.DISCOUNT_PERCENTAGE > 0
        THEN (ps.TOTAL_SALES - (bs.BASELINE_DAILY_SALES * ps.DURATION_DAYS)) / 
             (ps.TOTAL_SALES * ps.DISCOUNT_PERCENTAGE)
        ELSE 0
    END AS ROI_PROXY

FROM promo_sales ps
LEFT JOIN baseline_sales bs ON ps.PROMOTION_ID = bs.PROMOTION_ID
LEFT JOIN campaign_overlap co ON ps.PROMOTION_ID = co.PROMOTION_ID
LEFT JOIN seasonality s ON ps.PROMOTION_ID = s.PROMOTION_ID
WHERE bs.BASELINE_DAILY_SALES IS NOT NULL;  -- Only keep promos with baseline data

-- ============================================================================
-- Verification
-- ============================================================================

SELECT 
    'ML_PROMO_EFFECTIVENESS created successfully!' AS STATUS,
    COUNT(*) AS total_promos,
    AVG(SALES_LIFT_RATIO) AS avg_sales_lift,
    SUM(IS_SUCCESSFUL) AS successful_promos,
    ROUND(AVG(ROI_PROXY), 2) AS avg_roi_proxy
FROM ANALYTICS.ML_PROMO_EFFECTIVENESS;

-- Grant permissions
GRANT SELECT ON TABLE ANALYTICS.ML_PROMO_EFFECTIVENESS TO ROLE SYSADMIN;

SELECT '✅ Setup complete! Ready to train ML models.' AS NEXT_STEP;
