-- Data Assessment and Understanding the data structure
SELECT *
FROM downtime_factors;
SELECT *
FROM line_downtime;
SELECT *
FROM line_productivity_batches;
SELECT *
FROM products;

-- Number of rows
SELECT COUNT(*) AS row_downtime_factors FROM downtime_factors;
SELECT COUNT(*) AS row_line_downtime FROM line_downtime;
SELECT COUNT(*) AS row_line_productivity_batches FROM line_productivity_batches;
SELECT COUNT(*) AS row_products FROM products;

-- Check for nulls
SELECT COUNT(*) AS factor1_null_count FROM line_downtime
WHERE Factor_1 IS NULL;

SELECT COUNT(*) AS factor2_null_count FROM line_downtime
WHERE Factor_2 IS NULL;

SELECT COUNT(*) AS all_factors_null_count FROM line_downtime
WHERE COALESCE(Factor_1, Factor_2, Factor_3, Factor_4, Factor_5, Factor_6, Factor_7, Factor_8,
               Factor_9, Factor_10, Factor_11, Factor_12)IS NULL;

-- Start Date repetition in 'Date' and 'Start_Time' Columns 
WITH start_dates AS (
        SELECT Date, CAST(Start_TIME AS Date) AS Start_Date
        FROM line_productivity_batches)
SELECT * FROM start_dates WHERE Date != Start_Date;

-- Data Cleaning and Transformation
-- Handle null line downtime 
CREATE VIEW downtimes AS
SELECT Batch_ID, REPLACE(Factor, 'Factor_', '') AS Factor_ID, Minutes FROM line_downtime
UNPIVOT(Minutes FOR Factor IN (Factor_1, Factor_2, Factor_3, Factor_4, Factor_5, Factor_6, Factor_7,
        Factor_8, Factor_9, Factor_10, Factor_11, Factor_12, Factor_13)) AS UnpivotDowntimes;


SELECT * FROM downtimes
ORDER BY Batch_ID;

-- New batch production table (Date as Start Date, extract time from start and end time)  
CREATE VIEW batch_pd AS
    SELECT Date AS Start_Date, Product_ID, Batch_ID, Operator, CAST(End_Time AS Date) AS End_Date,
    CAST(Start_Time AS Time) AS Start_Time, CAST(End_Time AS Time) AS End_Time, Planned_Min_Batch_Hours,
    DATEDIFF(hour, Start_Time, End_Time) AS Actual_Duration,
    DATEDIFF(hour, Start_Time, End_Time)-Planned_Min_Batch_Hours AS Extra_Time_Hr
    FROM line_productivity_batches;

SELECT * FROM batch_pd;

-- Validatinf downtime minutes against planned production time and reported start/end time
SELECT batch_pd.Batch_ID, SUM(Minutes) AS accounted_delay_minutes, Extra_Time_Hr FROM batch_pd
JOIN downtimes ON batch_pd.Batch_ID = downtimes.Batch_ID
GROUP BY batch_pd.Batch_ID, Extra_Time_Hr;

-- ANALYSIS
-- Downtime key factors
SELECT Factor_Name, COUNT(Batch_ID) AS Frequency, SUM(Minutes) AS Delay_Mins FROM downtimes 
JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
GROUP BY Factor_Name
ORDER BY Frequency DESC;

-- Operator vs Non Operator Errors
SELECT
     CASE Operator_Error
          WHEN 1 THEN 'Yes'
          ELSE 'No'
    END AS Operator_Error,
    COUNT(Batch_ID) AS Frequency, SUM(Minutes) AS Delay_Mins FROM downtimes 
    JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
    GROUP BY Operator_Error;

-- Downtime Operator Errors
SELECT Factor_Name, Description, COUNT(Batch_ID) AS Frequency, SUM(Minutes) AS Delay_Mins FROM downtimes 
       JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
       WHERE Operator_Error = 1
       GROUP BY Factor_Name, Description
       ORDER BY SUM(Minutes) DESC;

-- Downtime Non Operator Errors
SELECT Factor_Name, Description, COUNT(Batch_ID) AS Frequency, SUM(Minutes) AS Delay_Mins FROM downtimes 
       JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
       WHERE Operator_Error = 0
       GROUP BY Factor_Name, Description
       ORDER BY SUM(Minutes) DESC;

-- Products and downtime frequency & delay (mins)
SELECT batch_pd.Product_ID, Product_Name, COUNT(downtimes.Batch_ID) AS Frequency, SUM(Minutes) AS Delay_Mins FROM batch_pd
JOIN downtimes ON batch_pd.Batch_ID = downtimes.Batch_ID
JOIN products ON batch_pd.Product_ID = products.Product_ID
GROUP By batch_pd.Product_ID, Product_Name;

-- How many factors are involved in each product downtime?
SELECT batch_pd.Product_ID, Product_Name, COUNT(DISTINCT Factor_ID) FROM batch_pd
JOIN products ON batch_pd.Product_ID = products.Product_ID
JOIN downtimes ON batch_pd.Batch_ID = downtimes.Batch_ID
GROUP BY batch_pd.Product_ID, Product_Name;

-- Top 5 factors for Product 1 downtime 
SELECT TOP 5 Factor_Name, SUM(Minutes) AS Prd001_Delay_Mins FROM downtimes
JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Product_ID = 'PRD001'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- Top 5 factors for Product 2 downtime 
SELECT TOP 5 Factor_Name, SUM(Minutes) AS Prd002_Delay_Mins FROM downtimes
JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Product_ID = 'PRD002'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- Top 5 factors for Product 3 downtime 
SELECT TOP 5 Factor_Name, SUM(Minutes) AS Prd003_Delay_Mins FROM downtimes
JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Product_ID = 'PRD003'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- Top 5 factors for Product 4 downtime 
SELECT TOP 5 Factor_Name, SUM(Minutes) AS Prd004_Delay_Mins FROM downtimes
JOIN downtime_factors ON downtimes.Factor_ID = downtime_factors.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Product_ID = 'PRD004'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- Production Lead Operators
SELECT Operator, COUNT(Batch_ID) AS Number_of_Batches, COUNT(DISTINCT Product_ID) AS Number_of_Products
FROM batch_pd
GROUP BY Operator;

-- Production Lead Operator and Downtime Duration, Percentage Delayed Batches
SELECT Operator,
        COUNT(DISTINCT batch_pd.Batch_ID) AS Total_Batches,
        COUNT(DISTINCT downtimes.Batch_ID) AS Number_of_delayed_batches,
        COUNT(downtimes.Batch_ID) AS Number_of_downtimes,
        SUM(Minutes) AS Delay_Mins,
        CAST((COUNT(DISTINCT downtimes.Batch_ID)*100.0)/(COUNT(DISTINCT batch_pd.Batch_ID)) AS DECIMAL(10, 2))
        AS Percentage_delayed_batches
        FROM batch_pd
        LEFT JOIN downtimes ON batch_pd.Batch_ID = downtimes.Batch_ID
        GROUP BY Operator
        ORDER BY Percentage_delayed_batches DESC;

-- Factor causing downtime for top 3 lead operators with the most delay  durations
-- 1. Paul
SELECT Factor_Name, SUM(Minutes) AS Delay_Mins FROM downtime_factors
JOIN downtimes ON downtime_factors.Factor_ID = downtimes.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Operator = 'Paul'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- 2. James
SELECT Factor_Name, SUM(Minutes) AS Delay_Mins FROM downtime_factors
JOIN downtimes ON downtime_factors.Factor_ID = downtimes.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Operator = 'James'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- 3. Emily
SELECT Factor_Name, SUM(Minutes) AS Delay_Mins FROM downtime_factors
JOIN downtimes ON downtime_factors.Factor_ID = downtimes.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Operator = 'Emily'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- Factors causing downtime for the top 3 operators with the most percentage delayed batches
-- 1. Linda
SELECT Factor_Name, SUM(Minutes) AS Delay_Mins FROM downtime_factors
JOIN downtimes ON downtime_factors.Factor_ID = downtimes.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Operator = 'Linda'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- 2. Sophia
SELECT Factor_Name, SUM(Minutes) AS Delay_Mins FROM downtime_factors
JOIN downtimes ON downtime_factors.Factor_ID = downtimes.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Operator = 'Sophia'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;

-- 3. Rita
SELECT Factor_Name, SUM(Minutes) AS Delay_Mins FROM downtime_factors
JOIN downtimes ON downtime_factors.Factor_ID = downtimes.Factor_ID
JOIN batch_pd ON batch_pd.Batch_ID = downtimes.Batch_ID
WHERE Operator = 'Rita'
GROUP BY Factor_Name
ORDER BY SUM(Minutes) DESC;