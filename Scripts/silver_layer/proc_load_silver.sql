/*
Stored Procedure: Loading the Silver Layer (Bronze → Silver)
============================================================
Purpose:
This stored procedure performs the ETL (Extract, Transform, Load) process to populate the six Silver tables
with data from the corresponding Bronze tables.

Methods:
It uses the truncate and insert method to fully refresh the Silver tables and prevent duplication of the data.
Truncate allows to preserve the columns and the table structure while resetting the data inside the table.
Various data transformations and cleansing operations are performed within this procedure, listed below.

Transformation types:
#1: Removing duplicates
-- Duplicates were removed from the primary key in the 1st table.
#2: Derived columns
-- Two new columns were derived from a composite column in the 2nd table.
#3: Data Normalization & Standardization
-- To increase readability, low-cardinality columns were standardized using CASE WHEN, to map abbreviations to more friendly, clear and meaningful values.
-- The UPPER and TRIM functions were also used to help catch all different capitalization cases and extra whitespaces.
#4: Handling Missing Values
-- Strings had their NULLs and empty strings ("") replaced with a default value "n/a", implemented within the CASE WHEN function.
-- Integer-type columns had their 0s replaced with NULLs, using the ISNULL and NULLIF functions.
#5: Handling Invalid Values
-- Invalid values such as 0s, NULLs, and bad quality data were cleaned up.
#6: Data Type Conversion
-- Columns with improper data types were converted using the CAST function.
#7: Removing unwanted spaces
-- String-value columns with extra whitespaces were trimmed.

Progress Tracking and Error Handling:
PRINT statements are included to track loading progress and assist with debugging.
This will help identify bottlenecks by showing the loading time for each table, and for the entire Silver layer.
Error handling is implemented using TRY...CATCH, making debugging and troubleshooting easier.
If an error occurs during loading, the CATCH block prints several diagnostic messages to help identify the issue.
After loading, data quality checks can be performed to validate row counts, column values, and business rules.

Run the script:
	EXECUTE silver.load_silver;
=================================================================================================================
*/

USE Data_Warehouse_Project; -- switch to the correct database, if not already there
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	
	DECLARE
		@start_time DATETIME,
		@end_time DATETIME,
		@batch_start_time DATETIME,
		@batch_end_time DATETIME;

	BEGIN TRY
		SET @batch_start_time = GETDATE(); -- start time for loading the entire Silver layer
		
		PRINT '========================================================';
		PRINT 'Loading into the Silver Layer';
		PRINT '========================================================';

		-- PRINT '--------------------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '--------------------------------------------------------';


		/**************************/
		-- Table 1: CRM customers
		/*
		#1: Removing duplicates
		(needs checking for this whole section)
		Deduplication was performed for the primary key, ie. the "cst_id" column. This section also includes removing missing values.
		This column has some duplicate rows, which differ by the creation date (cst_create_date) and by presence of NULLs in some of the rows.
		Primary keys cannot have duplicate values or NULLs, which means we need to keep only 1 record for each row, and handle the NULLs.
		The ROW_NUMBER() window function was used for this purpose. First we ranked the values based on the create_date, and then picked the most recent/latest record per customer using WHERE newest_create_date = 1. 
		The latest (highest) create_date is the freshest data, but it also coincides with the richest data (with the least NULL values in that row).
		However, the NULL rows within the primary key will be excluded directly, because they aren't duplicates in this case. 
		There are 4 rows with NULL in the primary key, and they have different cst_key, so keeping only one NULL row would be misleading. 
		These NULL rows will be excluded by using WHERE cst_id IS NOT NULL, within the subquery that contains the ROW_NUMBER() window function. 
		Placing it here ensures that the NULLs are excluded before the ranking, and that these 4 NULLs never participate in ROW_NUMBER().
		Basically, inside the subquery we do the deduplication and removing the NULL values, as well as ranking them.
		While having WHERE newest_create_date = 1 placed outside the subquery, ensures we can pick the row with the latest create_date after the deduplication and ranking were completed.
		Summary of the functions used:
		-- ROW_NUMBER() ... PARTITION BY cst_id → deduplicates per customer
		-- WHERE cst_id IS NOT NULL → removes NULL primary keys from being processed
		-- WHERE newest_create_date = 1 → keeps the latest record (filtering)
		*/

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: silver.crm_customer_info';
		TRUNCATE TABLE silver.crm_customer_info;

		-- SELECT * FROM silver.crm_customer_info -- before inserting data, check first which columns are included in the table.

		PRINT '>>> Inserting Data Into: silver.crm_customer_info';
		INSERT INTO silver.crm_customer_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)

		SELECT
		cst_id,
		cst_key,
		TRIM(cst_firstname) AS cst_firstname,
		TRIM(cst_lastname) AS cst_lastname,
		CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
			 WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
			 WHEN TRIM(cst_marital_status) = '' OR cst_marital_status IS NULL THEN 'n/a'
			 ELSE TRIM(cst_marital_status)
			 END AS cst_marital_status,
		CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
		 	 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
			 WHEN TRIM(cst_gndr) = '' OR cst_gndr IS NULL THEN 'n/a'
			 ELSE TRIM(cst_gndr)
			 END AS cst_gndr,
		cst_create_date FROM (
			SELECT *,
			ROW_NUMBER() OVER
				(PARTITION BY cst_id 
				ORDER BY cst_create_date DESC) 
				AS newest_create_date
			FROM bronze.crm_customer_info
			WHERE cst_id IS NOT NULL
			) AS create_rankings
		WHERE newest_create_date = 1
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';

		-- Code to count the number of rows for each table. Skipped here because the output already presents the number of rows affected.
		/*
		SELECT @row_count = COUNT(*) FROM silver.crm_customer_info;
		PRINT '>>> Rows Loaded into silver.crm_customer_info: ' + CAST(@row_count AS NVARCHAR(50));
		*/


		/**************************/
		-- Table 2: CRM products
		/*
		#2: Derived columns
		We derived 2 new columns by splitting the prd_key. This was done to enable joining this table with other tables, since the prd_key itself isn't present elsewhere. (needs checking)
		The 2 new derived columns were the actual prd_key which was basically extracted from the original prd_key, and the category ID, which were the first 5 characters.
		The SUBSTRING function was used for this purpose, combined with LEN for the second substring so we don't cut off any characters. It needs to be dynamic, not a fixed length.
		We also used the REPLACE function to replace the dash with an underscore for the first substring, so this column matches when joining the tables. (needs checking)
		
		#5: Handling Invalid Values
		The end_date column was fixed by using the LEAD() function, combined with DATEADD. 
		Essentially, the start date of the next row was identified, then substracted 1 day from it, and this result was used as the new end date for the current row.
		This was done to avoid issues when the end_date is earlier than the start_date, which is an invalid interval, or when there are overlapping periods between two consecutive rows.
		-- Alternatively, a more robust approach can be applied where the end date is corrected using business rules and CASE WHEN.
		In this case, if the original end_date is after the start_date but before the updated end_date, the original end_date would be kept, so we don't extend the validity unnecessarily.
		The original end_date should also be preserved when there's no next row to take the start_date from.
		But for the sake of simplicity, we'll stick with the simpler method.
		*/
			
		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: silver.crm_product_info';
		TRUNCATE TABLE silver.crm_product_info;

		-- SELECT * FROM silver.crm_product_info -- before inserting data, check first which columns are included in the table.

		-- Before creating the INSERT statement, check that the created table includes the new columns: prd_category_id, prd_key_extracted, and prd_end_date_new.
		-- The original columns (prd_key_extracted and prd_end_date_original) can still be kept in the Silver layer, just to perform checks and ensure everything works properly. 

		PRINT '>>> Inserting Data Into: silver.crm_product_info';
		INSERT INTO silver.crm_product_info (
			prd_id,
			prd_key_original,
			prd_category_id,
			prd_key_extracted,
			prd_line,
			prd_name,
			prd_cost,
			prd_start_date,
			prd_end_date_new,
			prd_end_date_original
		)

		SELECT
		prd_id,
		prd_key AS prd_key_original,
		CASE UPPER(TRIM(prd_line))
			 WHEN 'M' THEN 'Mountain'
		 	 WHEN 'R' THEN 'Road'
		 	 WHEN 'S' THEN 'Other Sales'
		 	 WHEN 'T' THEN 'Touring'
		 	 ELSE 'n/a'
			 END AS prd_line,
		REPLACE(SUBSTRING(prd_key,1,5), '-', '_')
			AS prd_category_id,
		TRIM(SUBSTRING(prd_key,7,LEN(prd_key))) 
			AS prd_key_extracted,
		prd_name,
		ISNULL(prd_cost,0) AS prd_cost,
		prd_start_date,
		DATEADD(DAY, -1,
				LEAD(prd_start_date) OVER
				(PARTITION BY prd_key 
				ORDER BY prd_start_date))
			AS prd_end_date_new,
		prd_end_date AS prd_end_date_original
		FROM bronze.crm_product_info

		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';


		/**************************/
		-- Table 3: CRM sales
		/*
		#5: Handling Invalid Values
		(needs checking for this entire section bc of the quantity etc)
		a. Business rules were applied to the sales, price and quantity columns in order to fix them.
		Ideally, the transformations should be built based on business rules provided by the experts, but this isn't a real business and we'll define them by logical reasoning.
		Since all three columns could technically be wrong on some occassions, we also need to decide which should be treated as the most reliable one.
		The reasoning is:
		-- Quantity, as the number of physical units sold, will be considered the most reliable field. If no quantities are sold, technically the row shouldn't exist, unless there are returns.
		-- Price comes next, which isn't the most reliable one because there can be discounts, promotions, etc. that effectively change the price.
		-- Sales is the least reliable one because it's always calculated by multiplying the quantity with the price.
		Therefore, we'll apply the following business rules:
		-- If the quantity is 0, NULL or negative, transform it to NULL ie. treat it as invalid. We assume negatives are also invalid, for the sake of simplicity. In this case, quantity doesn't have issues, but we need safeguards just in case future data has issues.
		-- If the price is 0, NULL or negative, derive it using sales divided by quantity. If the price is negative, it could simply be converted to positive, but we cannot assume that the absolute price value is correct either.
		-- If the sales are 0, NULL or negative, or don't equal to quantity * price, derive it using the equation quantity * price.
		For the sake of simplicity, we'll assume that when one of the fields is wrong, the other two are correct. This will avoid creating CTEs and make the reading flow easier.

		b. Invalid dates were fixed by replacing the 0s, negatives, and the bad quality data with NULLs.
		Bad quality data in this case refers to the number of characters for the values not being equal to 8, because this format doesn't represent a date, eg. 32154 and 5489. (needs checking)
		The CASE WHEN function was used for this purpose, because unlike NULLIF, CASE WHEN can handle more than one validation rules: negative values (the less than part), wrong length LEN(...) != 8, impossible dates, and other invalid formats.
		Besides, CASE WHEN combines everything in the same place, and it can be extended with more validation rules later on.
		These fixes were realistically needed just for the "order_date" column, but they were applied to the "ship_date" and "due_date" columns too, just in case they experience these issues in the future.
		Otherwise we would have to build quality checks that run every day for the "ship_date" and "due_date", after loading the data.
		
		#6: Data Type Casting
		All the date columns were transformed to actual dates, since they were originally integers.
		But first we needed to cast the integers to varchar, then from varchar to date, because we cannot cast directly from integer to date in SQL Server Management Studio. (needs checking)
		Besides the casting, we're also handling the invalid values, as explained above.
		*/
			
		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;

		-- SELECT * FROM silver.crm_sales_details -- before inserting data, check first which columns are included in the table.

		-- Before creating the INSERT statement, check that the created table includes the new columns for quantity, price and sales.
		-- The original columns can still be kept in the Silver layer, just to perform checks and ensure everything works properly.

		PRINT '>>> Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
			sls_ord_number,
			sls_prd_key,
			sls_cust_id,
			sls_order_date,
			sls_ship_date,
			sls_due_date,
			sls_quantity_new,
			sls_quantity_original,
			sls_price_new,
			sls_price_original,
			sls_sales_new,
			sls_sales_original
		)

		SELECT
		sls_ord_number,
		sls_prd_key,
		sls_cust_id,
		
		-- dates transformations:
		CASE WHEN sls_order_date <= 0 OR LEN(sls_order_date) != 8
			 THEN NULL
			 ELSE CAST(CAST(sls_order_date AS VARCHAR) AS DATE)
			 END AS sls_order_date,
		CASE WHEN sls_ship_date <= 0 OR LEN(sls_ship_date) != 8
			 THEN NULL
			 ELSE CAST(CAST(sls_ship_date AS VARCHAR) AS DATE)
			 END AS sls_ship_date,
		CASE WHEN sls_due_date <= 0 OR LEN(sls_due_date) != 8
			 THEN NULL
			 ELSE CAST(CAST(sls_due_date AS VARCHAR) AS DATE)
			 END AS sls_due_date,

		-- quantity transformations:
		CASE WHEN sls_quantity <= 0 OR sls_quantity IS NULL
			 THEN NULL
			 ELSE sls_quantity
			 END AS sls_quantity_new,
		sls_quantity AS sls_quantity_original,
		
		-- prices transformations:
		CASE WHEN sls_price <= 0 OR sls_price IS NULL
			 THEN sls_sales / NULLIF(sls_quantity, 0) -- dividing by 0 would break the code, so we transform quantities with value 0 to NULL. As a result, the division would also be NULL.
			 ELSE sls_price
			 END AS sls_price_new,
		sls_price AS sls_price_original,

		-- sales transformations:
		CASE WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales != sls_quantity * sls_price
			 THEN sls_quantity * sls_price
			 ELSE sls_sales
			 END AS sls_sales_new,
		sls_sales AS sls_sales_original

		FROM bronze.crm_sales_details

		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';


		PRINT '--------------------------------------------------------';
		PRINT 'Loading EPR tables';
		PRINT '--------------------------------------------------------';


		/**************************/
		-- Table 4: ERP customers
		/*
		#5: Handling Invalid Values
		a. The "cid" column was cleaned up, so that we're able to join this table with other related tables that also contain the "cid" column.
		In this table, we removed the "NAS" substring at the beginning of the "cid".
		b. Then, the birth date in the 4th table was transformed by setting the future birthdates to NULL.
		*/

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: silver.erp_customers_AZ12';
		TRUNCATE TABLE silver.erp_customers_AZ12;

		-- SELECT * FROM silver.erp_customers_AZ12 -- before inserting data, check first which columns are included in the table.

		PRINT '>>> Inserting Data Into: silver.erp_customers_AZ12';
		INSERT INTO silver.erp_customers_AZ12 (
			cid,
			bdate,
			gender
		)

		SELECT
		CASE WHEN cid LIKE 'NAS%' 
			 THEN SUBSTRING(cid, 4, LEN(cid))
			 ELSE cid
			 END AS cid,
		CASE WHEN bdate > GETDATE() THEN NULL
			 ELSE bdate
			 END AS bdate,
		CASE WHEN UPPER(TRIM(gender)) IN ('F', 'FEMALE') THEN 'Female'
			 WHEN UPPER(TRIM(gender)) IN ('M', 'MALE') THEN 'Male'
			 WHEN TRIM(gender) = '' OR gender IS NULL THEN 'n/a'
			 ELSE TRIM(gender)
			 END AS gender
		FROM bronze.erp_customers_AZ12

		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';


		/**************************/
		-- Table 5: ERP location
		/*
		#5: Handling Invalid Values
		a. The "cid" column was cleaned up, so that we're able to join this table with other related tables that also contain the "cid" column.
		In this table, we removed the dash from the "cid" by replacing it with an empty substring ("").
		*/

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: silver.erp_location_A101';
		TRUNCATE TABLE silver.erp_location_A101;

		-- SELECT * FROM silver.erp_location_A101 -- before inserting data, check first which columns are included in the table.

		PRINT '>>> Inserting Data Into: silver.erp_location_A101';
		INSERT INTO silver.erp_location_A101 (
			cid,
			country
		)
		
		SELECT
		REPLACE(cid, '-', '') AS cid,
		CASE WHEN UPPER(TRIM(country)) = 'DE' THEN 'Germany'
			 WHEN UPPER(TRIM(country)) IN ('US', 'USA') THEN 'United States'
			 WHEN TRIM(country) = '' OR country IS NULL THEN 'n/a'
			 ELSE TRIM(country) -- keep existing full country names. Any new abbreviations or variations will be detected via quality checks, and they will be mapped as needed.
			 END AS country
		FROM bronze.erp_location_A101;

		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';


		/**************************/
		-- Table 6: ERP product category
		-- This table didn't need any transformations, based on the checks in the other code.

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: silver.erp_px_category_G1V2';
		TRUNCATE TABLE silver.erp_px_category_G1V2;

		-- SELECT * FROM silver.erp_px_category_G1V2 -- before inserting data, check first which columns are included in the table.

		PRINT '>>> Inserting Data Into: silver.erp_px_category_G1V2';
		INSERT INTO silver.erp_px_category_G1V2 (
			id, 
			category, 
			subcategory, 
			maintenance
		)
		
		SELECT
		id,
		category,
		subcategory,
		maintenance
		FROM bronze.erp_px_category_G1V2;
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		/**************************/


		SET @batch_end_time = GETDATE(); -- end time for loading the entire Silver layer

		PRINT '========================================================';
		PRINT 'Loading Silver Layer is Completed';
		PRINT '>>> Total Load Duration: ' + CAST( DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '========================================================';
		
		-- SELECT 1/0 -- use this for testing the CATCH block. It divides by 0, so it should return an error.	

	END TRY

	BEGIN CATCH
		PRINT '========================================================';
		PRINT 'ERROR OCCURRED DURING LOADING INTO SILVER LAYER';
		PRINT CONCAT('Error Message: ', ERROR_MESSAGE());
		PRINT CONCAT('Error Number: ', ERROR_NUMBER());
		PRINT CONCAT('Error State: ', ERROR_STATE());
		PRINT CONCAT('Error Line: ', ERROR_LINE());
		PRINT CONCAT('Error Procedure: ', COALESCE(ERROR_PROCEDURE(), 'N/A'));
		PRINT CONCAT('Error Severity: ', ERROR_SEVERITY());
		PRINT CONCAT('Error Time: ', CONVERT(VARCHAR(19), GETDATE(), 120)); -- Style 120 returns the ODBC canonical datetime format (yyyy-mm-dd hh:mi:ss).
		PRINT '========================================================';
	END CATCH

END; -- procedure
