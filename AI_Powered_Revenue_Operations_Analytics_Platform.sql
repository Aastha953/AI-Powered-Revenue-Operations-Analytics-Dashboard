/*===============================================================
 Project: AI-Powered Revenue Operations Analytics Platform
 Purpose: Create database, create CRM tables, load/validate data,
          create reporting view, and generate RevOps KPIs.
 Author: Aaditya Ratanpara
===============================================================*/


-- =============================================================
-- 1. CREATE DATABASE
-- =============================================================

IF DB_ID('RevOpsAnalytics') IS NULL
BEGIN
    CREATE DATABASE RevOpsAnalytics;
END;
GO

USE RevOpsAnalytics;
GO


-- =============================================================
-- 2. DROP EXISTING OBJECTS IF THEY EXIST
-- =============================================================

IF OBJECT_ID('vw_RevenueOpsDashboard', 'V') IS NOT NULL
    DROP VIEW vw_RevenueOpsDashboard;
GO

IF OBJECT_ID('Sales_Pipeline', 'U') IS NOT NULL DROP TABLE Sales_Pipeline;
IF OBJECT_ID('Sales_Teams', 'U') IS NOT NULL DROP TABLE Sales_Teams;
IF OBJECT_ID('Products', 'U') IS NOT NULL DROP TABLE Products;
IF OBJECT_ID('Accounts', 'U') IS NOT NULL DROP TABLE Accounts;
GO


-- =============================================================
-- 3. CREATE TABLES
-- =============================================================

CREATE TABLE Accounts
(
    account NVARCHAR(255) NOT NULL,
    sector NVARCHAR(100) NULL,
    year_established SMALLINT NULL,
    revenue FLOAT NULL,
    employees INT NULL,
    office_location NVARCHAR(100) NULL,
    subsidiary_of NVARCHAR(255) NULL
);
GO

CREATE TABLE Products
(
    product NVARCHAR(100) NOT NULL,
    series NVARCHAR(50) NULL,
    sales_price FLOAT NULL
);
GO

CREATE TABLE Sales_Teams
(
    sales_agent NVARCHAR(100) NOT NULL,
    manager NVARCHAR(100) NULL,
    regional_office NVARCHAR(50) NULL
);
GO

CREATE TABLE Sales_Pipeline
(
    opportunity_id NVARCHAR(50) NOT NULL,
    sales_agent NVARCHAR(100) NULL,
    product NVARCHAR(100) NULL,
    account NVARCHAR(255) NULL,
    deal_stage NVARCHAR(50) NULL,
    engage_date DATE NULL,
    close_date DATE NULL,
    close_value FLOAT NULL
);
GO


-- =============================================================
-- 4. OPTIONAL: ADD PRIMARY KEYS
-- =============================================================

ALTER TABLE Accounts
ADD CONSTRAINT PK_Accounts PRIMARY KEY (account);
GO

ALTER TABLE Products
ADD CONSTRAINT PK_Products PRIMARY KEY (product);
GO

ALTER TABLE Sales_Teams
ADD CONSTRAINT PK_SalesTeams PRIMARY KEY (sales_agent);
GO

ALTER TABLE Sales_Pipeline
ADD CONSTRAINT PK_SalesPipeline PRIMARY KEY (opportunity_id);
GO


-- =============================================================
-- 5. LOAD DATA
-- =============================================================
-- Since you already imported CSV files using SSMS Import Wizard,
-- you do NOT need this section right now.
--
-- If you wanted to load manually using SQL, you would use BULK INSERT.
-- Update file paths based on your computer.


/*===============================================================
 LOAD ACCOUNTS
===============================================================*/

BULK INSERT Accounts
FROM 'C:\Users\aasth\Downloads\CRM+Sales+Opportunities\accounts.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);


/*===============================================================
 LOAD PRODUCTS
===============================================================*/

BULK INSERT Products
FROM 'C:\Users\aasth\Downloads\CRM+Sales+Opportunities\products.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);


/*===============================================================
 LOAD SALES TEAMS
===============================================================*/

BULK INSERT Sales_Teams
FROM 'C:\Users\aasth\Downloads\CRM+Sales+Opportunities\sales_teams.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);


/*===============================================================
 LOAD SALES PIPELINE
===============================================================*/

BULK INSERT Sales_Pipeline
FROM 'C:\Users\aasth\Downloads\CRM+Sales+Opportunities\sales_pipeline.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);


-- =============================================================
-- 6. DATA LOAD VALIDATION
-- =============================================================

SELECT COUNT(*) AS AccountsCount
FROM Accounts;

SELECT COUNT(*) AS ProductsCount
FROM Products;

SELECT COUNT(*) AS SalesTeamsCount
FROM Sales_Teams;

SELECT COUNT(*) AS SalesPipelineCount
FROM Sales_Pipeline;


-- =============================================================
-- 7. PIPELINE STAGE VALIDATION
-- =============================================================

SELECT DISTINCT
    deal_stage
FROM Sales_Pipeline
ORDER BY deal_stage;


-- =============================================================
-- 8. DATA QUALITY CHECKS
-- =============================================================

SELECT COUNT(*) AS MissingAccountMatches
FROM Sales_Pipeline p
LEFT JOIN Accounts a
    ON p.account = a.account
WHERE a.account IS NULL
  AND p.account IS NOT NULL;

SELECT COUNT(*) AS MissingProductMatches
FROM Sales_Pipeline p
LEFT JOIN Products pr
    ON REPLACE(p.product, ' ', '') = REPLACE(pr.product, ' ', '')
WHERE pr.product IS NULL
  AND p.product IS NOT NULL;

SELECT COUNT(*) AS MissingSalesAgentMatches
FROM Sales_Pipeline p
LEFT JOIN Sales_Teams s
    ON p.sales_agent = s.sales_agent
WHERE s.sales_agent IS NULL
  AND p.sales_agent IS NOT NULL;


-- =============================================================
-- 9. CREATE REPORTING VIEW
-- =============================================================

CREATE VIEW vw_RevenueOpsDashboard AS
SELECT
    p.opportunity_id,
    p.sales_agent,
    s.manager,
    s.regional_office,
    p.account,
    a.sector,
    a.office_location,
    p.product,
    pr.series,
    pr.sales_price,
    p.deal_stage,
    p.engage_date,
    p.close_date,
    p.close_value
FROM Sales_Pipeline p
LEFT JOIN Sales_Teams s
    ON p.sales_agent = s.sales_agent
LEFT JOIN Accounts a
    ON p.account = a.account
LEFT JOIN Products pr
    ON REPLACE(p.product, ' ', '') = REPLACE(pr.product, ' ', '');
GO


-- =============================================================
-- 10. REPORTING VIEW VALIDATION
-- =============================================================

SELECT COUNT(*) AS ViewRows
FROM vw_RevenueOpsDashboard;

SELECT
    deal_stage,
    COUNT(*) AS OpportunityCount
FROM vw_RevenueOpsDashboard
GROUP BY deal_stage
ORDER BY OpportunityCount DESC;


-- =============================================================
-- 11. EXECUTIVE KPI SUMMARY
-- =============================================================

SELECT
    SUM(close_value) AS TotalRevenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won';

SELECT
    COUNT(*) AS WonDeals
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won';

SELECT
    CAST(
        COUNT(CASE WHEN deal_stage = 'Won' THEN 1 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS WinRate
FROM vw_RevenueOpsDashboard;

SELECT
    COUNT(*) AS OpenPipelineOpportunities
FROM vw_RevenueOpsDashboard
WHERE deal_stage IN ('Prospecting', 'Engaging');


-- =============================================================
-- 12. PIPELINE FUNNEL ANALYSIS
-- =============================================================

SELECT
    deal_stage,
    COUNT(*) AS Opportunities,
    COUNT(close_value) AS OpportunitiesWithValue
FROM vw_RevenueOpsDashboard
GROUP BY deal_stage
ORDER BY Opportunities DESC;


-- =============================================================
-- 13. REVENUE BY REGION
-- =============================================================

SELECT
    regional_office,
    SUM(close_value) AS Revenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won'
GROUP BY regional_office
ORDER BY Revenue DESC;


-- =============================================================
-- 14. SALES REP PERFORMANCE
-- =============================================================

SELECT
    sales_agent,
    SUM(close_value) AS Revenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won'
GROUP BY sales_agent
ORDER BY Revenue DESC;


-- =============================================================
-- 15. PRODUCT PERFORMANCE
-- =============================================================

SELECT
    product,
    SUM(close_value) AS Revenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won'
GROUP BY product
ORDER BY Revenue DESC;


-- =============================================================
-- 16. INDUSTRY PERFORMANCE
-- =============================================================

SELECT
    sector,
    SUM(close_value) AS Revenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won'
GROUP BY sector
ORDER BY Revenue DESC;


-- =============================================================
-- 17. MANAGER PERFORMANCE
-- =============================================================

SELECT
    manager,
    SUM(close_value) AS Revenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won'
GROUP BY manager
ORDER BY Revenue DESC;


-- =============================================================
-- 18. DEAL EFFICIENCY METRICS
-- =============================================================

SELECT
    AVG(close_value) AS AvgDealSize
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won';

SELECT
    AVG(DATEDIFF(DAY, engage_date, close_date)) AS AvgSalesCycleDays
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won';

-- =============================================================
-- 19. REVENUE TREND ANALYSIS
-- =============================================================

SELECT
    YEAR(close_date) AS SalesYear,
    MONTH(close_date) AS SalesMonth,
    SUM(close_value) AS Revenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won'
GROUP BY
    YEAR(close_date),
    MONTH(close_date)
ORDER BY
    SalesYear,
    SalesMonth;


-- =============================================================
-- 20. WIN RATE BY REGION
-- =============================================================

SELECT
    regional_office,
    CAST(
        COUNT(CASE WHEN deal_stage = 'Won' THEN 1 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS WinRate
FROM vw_RevenueOpsDashboard
GROUP BY regional_office
ORDER BY WinRate DESC;


-- =============================================================
-- 21. TOP CUSTOMER ACCOUNTS
-- =============================================================

SELECT
    account,
    SUM(close_value) AS Revenue
FROM vw_RevenueOpsDashboard
WHERE deal_stage = 'Won'
GROUP BY account
ORDER BY Revenue DESC;

