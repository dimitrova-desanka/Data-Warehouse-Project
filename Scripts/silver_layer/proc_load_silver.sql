/*
Loading Data into the Silver Layer (From Bronze)
===========================
Script Purpose:
This is a stored procedure that loads/inserts the data from the six Bronze tables into their respective Silver tables, using the truncate and insert method. 
This is done while also performing data transformations and cleaning at the same time.
The truncation of the tables before loading is performed to avoid duplication of the data. In other words, we're refreshing the tables i.e. clearing and re-inserting the data.
This process is saved as a stored procedure for frequent usage, since data needs to be loaded into the Silver layer daily.
PRINT statements are included for tracking progress and debugging. These show the duration of loading for each table and for the entire Silver layer.
This will help identify issues and bottlenecks by understanding which tables consume more time to load.
Error handling is implemented using TRY...CATCH, allowing logging issues (errors, warnings, etc) for easier debugging, troubleshooting and improving data integrity.
If there's an error during loading, the CATCH will print several messages to help identify the error.
After the loading is done, quality checks should ideally be performed for each table (columns and rows).
*/

USE Data_Warehouse_Project; -- switch to the correct database, if not already there
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS -- creating the stored procedure
BEGIN
	DECLARE
		@start_time DATETIME,
		@end_time DATETIME,
		@batch_start_time DATETIME, -- to the second
		@batch_end_time DATETIME; -- to the second
		-- @row_count INT; -- optional. This can be used to count the number of rows for each table, but it's not needed here because the output already shows this.

	BEGIN TRY
		SET @batch_start_time = GETDATE(); -- start time for loading the entire Silver layer.
		PRINT '========================================================';
		PRINT 'Loading into the Silver Layer';
		PRINT '========================================================';

		-- PRINT '--------------------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '--------------------------------------------------------';

		-- First table
		------ Types of transformations/What was completed:
		---- 1: Removing duplicates from the Primary Key
		-- This includes three things: deduplication, filtering the data, and removing NULLs.
		-- The primary key (cst_id) has some duplicate rows, which differ by the creation date (cst_create_date) and by presence of nulls in some of the rows.
		-- We need to keep only 1 record for each primary key/id. We'll do this by using ROW_NUMBER() to first rank the values based on the create date, and then pick the most recent/highest/latest record per customer using WHERE newest_create_date = 1. The highest (latest) create date is the freshest data, but it also coincides with the most rich data (least nulls).
		-- But the NULL rows within the primary key will be excluded directly, and won't be ranked in the ROW_NUMBER() function, since they aren't necessarily duplicates among each other (there are 4 NULLs, and they have different cst_key) and keeping only one NULL row would be misleading. This will be done by using WHERE cst_id IS NOT NULL, within the subquery containing the Row_Number() function.
		-- The NULL handling is correct: WHERE cst_id IS NOT NULL inside the subquery ensures that the NULLs are excluded before the ranking, and that they never participate in ROW_NUMBER().
		-- While having WHERE newest_create_date = 1 outside the subquery is correct. Inside the subquery we do the deduplication and removing the NULL values, while outside the subquery we pick the highest (latest) create date.
		-- Summary of the functions used:
		--- WHERE cst_id IS NOT NULL → removes NULL keys from processing
		--- ROW_NUMBER() ... PARTITION BY cst_id → deduplicates per customer
		--- WHERE newest_create_date = 1 → keeps latest record (filtering)

		---- 2: Removed unwanted spaces before and after (trim) in string-value columns
		-- This is done for all string columns: first name, last name, even marital status and gender (just in case, even if they don't actually need trimming).

		----- 3: Data Normalization & Standardization; Handling missing values
		-- Use friendly, clear and meaningful names instead of abbreviations. / Normalize marital status and gender values to readable format. (Case When functions)
		-- From the quality check, we saw that there are only 2 columns with abbreviations (that have low cardinality), the marital status and the gender.
		-- We're also handling missing values, by replacing the nulls with a default value 'n/a'. Filled in the blanks by adding a default value (n/a in this case). (Else statement equal to n/a in Case When).
		-- We're also checking lowercase values (f, m) by using UPPER function so we're able to catch them too; and TRIM just in case. So we can catch all the different cases.

		-- After the transformations, we insert the cleaned up data into the silver layer (the silver tables should have the same columns (unless they were changed re the DDL script), but these columns are still empty).


		-- SELECT * FROM silver.crm_customer_info -- check first which column headers are included here.

		SET @start_time = GETDATE(); -- exact time when we start loading this table
		PRINT '>>> Truncating Table: silver.crm_customer_info';
		TRUNCATE TABLE silver.crm_customer_info; -- first reset/empty the table to avoid duplicate insertion, but keep the columns and the structure.

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
				ELSE 'n/a'
				END AS cst_marital_status,
		CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'
				END AS cst_gndr,
		cst_create_date
		FROM (
			SELECT
			*,
			ROW_NUMBER() OVER 
				(PARTITION BY cst_id
				ORDER BY cst_create_date DESC) AS newest_create_date
			FROM bronze.crm_customer_info
			WHERE cst_id IS NOT NULL -- removes the NULLs at least for now, because they're not necessarily duplicates among each other.
			) AS create_rankings
		WHERE newest_create_date = 1 -- keeps the highest/latest one (filtering); use not equal to 1 to see all the rows that should be deleted basically.
			-- AND (cst_id IN (29449, 29473, 29433, 29483, 29466) OR cst_id IS NULL) -- this is just to check that there are no more duplicates (see quality check query)
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';

		-- If you want to include row count, use this code. But note that the output already presents the rows affected in brackets.
		/*
		SELECT @row_count = COUNT(*) FROM silver.crm_customer_info;
		PRINT '>>> Rows Loaded into silver.crm_customer_info: ' + CAST(@row_count AS NVARCHAR(50));
		*/


		-- =========================================================================
		-- ***************** PAUSED HERE with the general cleanup *****************


		/**************************/
		-- 2nd table
		------ Types of transformations/What was completed
		---- 1. Derive prd_key into 2 new columns, ie. split it into two information. This is to allow joining with other tables.
		-- Category ID for the first 5 characters (first part of the string), the remaining characters are the product ID itself.
		-- Also makes them matching so we can join them, by replacing the dash with an underscore.
		-- Then with the Where statement, we check if we can actually join these tables, by filtering out unmatched data after applying the transformation.
		-- Now we extract the second part by doing the same thing, with the Substring function. We use the LEN function so we can always get enough characters extracted, it needs to be dynamic not fixed length.
		-- Type of transformation: Derived new columns. Extracted category ID and product key from the original product key. Sometimes we need them just for analytics and can't each time go to source system and ask them to create it, so we derive our own columns. Replace and Trim functions.

		---- 2. Replace the Nulls with 0s in the integer cost column.
		-- Type of transformation: Handling missing values. Instead of null, we have 0. IsNull function.

		---- 3. Clear and friendly names instead of abbreviations for the product line column, and fixing the Nulls with n/a. Moved the line not just before the name, but also before the category ID, because it's the most aggregate one.
		-- Type of transformation: Data Normalization & Standardization plus handling the missing data (n/a here). Instead of code values, we have friendly values. Map product line codes to descriptive values. Case When function, and Else for handling missing values.

		---- 4. Using LEAD() window function to access the start date of the next row and use that as the new end date so there's no end date being earlier than start date hence overlapping & substracting one day so there's no overlapping with the next start date.
		-- BUT also there's no need to fix end dates that don't need fixing, so suggested by ChatGPT below is a more robust approach.
		-- INSERT (final step): Before creating the Insert statement, make note that there's a new column which is prd_category_id, prd_key_extracted (unless replacing this with prd_key), and the prd_end_date_new (unless replacing this with prd_end_date). Check also if types are changed from the bronze layer, eg from Datetime to Date, which for him was the case but for me it wasn't.
		-- Either way, this means few modifications are needed to/update the DDL script for the silver layer (Create query). See in comments what's new. New columns can be introduced either via Alter statement here before Insert (and before Truncate), or directly into the Create table separate query. While same goes for changing data types, either via Alter or Create, but they cannot be changed inside the INSERT statement according to ChatGPT. Then included in INSERT statement same way.
		-- Alter or Create are needed, Insert cannot introduce new columns or rename them (I think, but shouldn't rely on it anyway; unless you use Select * Into silver From bronze idk if another way), and "SQL Server will not auto-update existing table schema, This is expected behavior in relational databases".
		-- Type of transformation for point 4: Data enrichment. This is all about adding value to your data; so we're adding new, relevant data to enhance the dataset for analysis. Lead (witn DateAdd) window function.
		-- Type of transformation for point 4: (less important) He did Data Type Casting, with the DateTime to Date. Converting one data type to another. Cast function (not needed for my query).


		-- SELECT * FROM silver.crm_product_info -- first check which column headers are included here.
			
		SET @start_time = GETDATE(); -- exact time when we start loading this table
		-- PRINT ''; -- empty line for better readability in the output. Not used because it's unnecessary.
		PRINT '>>> Truncating Table: silver.crm_product_info';
		TRUNCATE TABLE silver.crm_product_info;

		PRINT '>>> Inserting Data Into: silver.crm_product_info';
		INSERT INTO silver.crm_product_info (
			prd_id,
			prd_key_original, -- existing; this might not be needed with the 2 new derived columns
			prd_line, -- moved up before cost to group with related, and before the less aggregated ones.
			prd_category_id, -- new, first substring from longer product key
			prd_key_extracted, -- new, second substring from longer product key (just the extracted)
			prd_name,
			prd_cost,
			prd_start_date,
			prd_end_date_new, -- new end date, that takes from the next start date.
			prd_end_date_old -- existing end date, the original one.
		)

		-- start of the main code so to speak
		-- SELECT *  -- extra, to check where the old and new end date aren't equal
		-- FROM (  -- extra, to check where the old and new end date aren't equal

		SELECT
		prd_id,
		prd_key AS prd_key_original, -- this might not be needed with the 2 new derived columns
		CASE UPPER(TRIM(prd_line)) -- quick Case When version for simple value mapping
				WHEN 'M' THEN 'Mountain'
				WHEN 'R' THEN 'Road'
				WHEN 'S' THEN 'Other Sales'
				WHEN 'T' THEN 'Touring'
				ELSE 'n/a' -- fixing the Null values also
				END AS prd_line,
		-- CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
		-- 	 WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
		-- 	 WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
		-- 	 WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
		-- 	 ELSE 'n/a' -- fixing the Null values also
		--	 END AS prd_line,
		REPLACE(SUBSTRING(prd_key,1,5), '-', '_') AS prd_category_id,
		TRIM(SUBSTRING(prd_key,7,LEN(prd_key))) AS prd_key_extracted, -- 7 is used instead of 6 to remove the dash inbetween the two IDs. Trim is used just in case there are whitespaces after, given LEN is used.
		prd_name,
		ISNULL(prd_cost,0) AS prd_cost,
		prd_start_date, -- CAST ([start_date/dateadd entire line just before AS prd_end_date_new] AS DATE) AS prd_start_date/prd_end_date_new -- Here no need because it's already Date, while he had DateTime with the hours. But only if the hours are actually 0s aka it's not needed.
		DATEADD(DAY, -1, -- to substract 1 day from the new end date with LEAD row, he didn't have this part just the Lead() with -1 before the AS. Calculate (new) end date as one day before the next start date.
				LEAD(prd_start_date) OVER (PARTITION BY prd_key ORDER BY prd_start_date)) AS prd_end_date_new, -- the new end date that takes from the next start date. he used -1 to substract a day, but it didn't work for me, maybe bc he has datetime or bc of different SQL Server version / compatibility level.
		prd_end_date AS prd_end_date_old -- the original end date; good to remove after checking where it's different than the old date, but can keep just in case.
		FROM bronze.crm_product_info
		-- Check if there's any category IDs that aren't in the ERP table. We didn't find only 1 category ID, which is indeed not in the other ERP table, so everything is fine.
		-- WHERE REPLACE(SUBSTRING(prd_key_original,1,5), '-', '_') NOT IN
		-- (SELECT DISTINCT id FROM bronze.erp_px_category_G1V2); 
		-- Check if there's any product key that isn't in the CRM sales details table. There are quite a lot, but by checking a few keys in sales details table or by using the more advanced check below, we see the sales details table doesn't actually have any of these product keys (no orders with those products), so everything is fine.
		-- WHERE TRIM(SUBSTRING(prd_key_original,7,LEN(prd_key_original))) NOT IN -- use just IN to see if they can actually be joined.
		-- (SELECT DISTINCT sls_prd_key FROM bronze.crm_sales_details); -- remove the ); part if using the Where statement below.
		-- WHERE sls_prd_key LIKE 'FK%'); -- check the sales details table if it's actually missing those keys, but this might require more advanced check (or longer Like substrings) bc others starting with BK for example are there.

			-- ) AS checking WHERE prd_end_date_old != prd_end_date_new -- extra, to check where the old and new end date aren't equal. Can include here AND start date isn't higher than end date, because otherwise no fixing would be needed.
			-- ORDER BY prd_start_date, prd_end_date_old, prd_end_date_new -- extra, to check where the old and new end date aren't equal
			-- end of the main code so to speak
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';

		/***/
		-- More advanced check to see if any of the non-joined product keys from the original table, are indeed not found in the CRM sales details table. Comparing the keys from the two tables. Ordering is included here too.
		/*
		SELECT DISTINCT TRIM(SUBSTRING(prd_key_original,7,LEN(prd_key_original))) AS prd_key_extracted
		FROM bronze.crm_product_info
		WHERE TRIM(SUBSTRING(prd_key_original,7,LEN(prd_key_original))) NOT IN
			(SELECT DISTINCT sls_prd_key FROM bronze.crm_sales_details)
		ORDER BY prd_key_extracted;

		SELECT DISTINCT sls_prd_key
		FROM bronze.crm_sales_details
		ORDER BY sls_prd_key;
		*/

		/***/
		-- Dates: Building the logic for the start and end date solution, using just the specific examples first.
		/*
		SELECT
		prd_id,
		prd_key_original,
		prd_name,
		prd_start_date,
		prd_end_date_old,
		DATEADD(DAY, -1,
				LEAD(prd_start_date) OVER (PARTITION BY prd_key_original ORDER BY prd_start_date)) AS prd_end_date_new -- then just take this line and move it to the main query. extra comments were moved there too.
		FROM bronze.crm_product_info
		WHERE prd_key_original IN ('AC-HE-HL-U509-B', 'AC-HE-HL-U509-R');
		*/

		/***/
		-- End date more robust approach: Using Case When to select original vs new end date, based on certain business rules listed below.
		-- "This way you're only correcting bad data instead of replacing everything.
		-- A more robust approach is this where for each row: 
		-- 1) Calculate the candidate end date: next_start_date - 1 day; 
		-- 2) If there is no next row - keep the original end date; 
		-- 3) If the original end date is before the candidate end date - keep the original end date (don't extend validity); 
		-- 4) If the original end date is after the candidate end date (overlap) - use the candidate; 
		-- 5) Optionally, if the original end date is before the start date (invalid interval) - also use the candidate".

		-- "ChatGPT would first calculate the candidate end date once, then apply the business rules. A CTE makes it much cleaner.
		-- ChatGPT prefers this over recalculating LEAD() inside every CASE branch because: 1) LEAD() is written only once, 2) The business rules read top-to-bottom in plain English, and 3) If you later change how the candidate date is computed, you only change it in one place."
		/*
		WITH product_dates AS -- this should be the CTE, but double-check
		(
			SELECT
				prd_id,
				prd_key_original,
				prd_start_date,
				prd_end_date_old,

				DATEADD(
					DAY,
					-1,
					LEAD(prd_start_date) OVER (
						PARTITION BY prd_key_original
						ORDER BY prd_start_date
					)
				) AS candidate_end_date -- prd_end_date_new

			FROM bronze.crm_product_info
		)

		SELECT
			prd_id,
			prd_key_original,
			prd_start_date,

			CASE

				-- No next start date: keep original end date
				WHEN candidate_end_date IS NULL -- this is basically the next start date
					THEN prd_end_date_old

				-- When original end date is before the Start date in the same row, aka there's an invalid interval, use the candidate
				WHEN prd_end_date_old < prd_start_date
					THEN candidate_end_date

				-- When original end date is after candidate (candidate is earlier than original end date), use the candidate/shorten the validity period. This means the current validity period extends beyond where the next version begins, which is the overlap you're correcting.
				WHEN prd_end_date_old > candidate_end_date
					THEN candidate_end_date

				-- When original end date is before candidate, keep the original (ChatGPT didn't have this and implied it in the final Else statement. But I created this just to have explicit business rules, even though it's more verbose, and kept Else anyway for the other cases.)
				WHEN prd_end_date_old < candidate_end_date -- my version
					THEN prd_end_date_old

				-- ChatGPT would definitely keep the ELSE, it makes the logic both safer and clearer. It will cover equal dates and any future edge cases you haven't anticipated. Besides, without an ELSE, if none of the WHEN conditions match, SQL Server returns NULL, so technically Else is needed.
				ELSE prd_end_date_old

			END AS prd_end_date_new

		FROM product_dates;
		*/


		/**************************/
		------ 3rd table
		------ Types of transformations/What was completed (summary)
		-- Handling invalid data: With the CASE WHENs for the 3 dates columns, in the WHEN line with the <= 0 and LEN !=8 checks.
		-- Data type casting, to change to more correct data type: With the CASE WHENs for the 3 dates columns, but this time in the CAST(CAST...)) line.
		-- Handling missing data & invalid data: With the CASE WHENs for the Sales and Prices, in the WHEN line but for IS NULL (missing) and <= 0 part (invalid). We're handling the missing data and also the invalid data by deriving the column from already existing ones/from specific calculation (the equation, referring to the quantity*price and sales/quantity). (Prices very similar, he said).

		---- 1st fix:
		-- (Related to the 4th check or so.)
		-- This combines two fixes in the order date column. Replaces the 0s with nulls, and replaces the bad quality data with 0s as well (the values 32154 and 5489, ie. number of characters is lower or higher than 8).
		-- The ship date and due date are fine for all of the sub-checks, only the order date column needs fixing. He only uses Case When for these because he didn't like what happened with the order date, so he applies the same rules just in case these issues happen to these columns too in the future; however casting as date is still needed here regardless.
		-- Re The ship date and due date: "And if you don't want to apply it now, you have always to build like quality checks that runs every day in order to detect those issues. And once you detect it, then you can go and do the transformations.
		-- Re The ship date and due date (cont.): But for now I'm going to apply it right away".
		-- ChatGPT: The reason why he uses Case When in the original code instead of NullIf, is because NullIF It cannot handle: negative values (the less than part), wrong length LEN(...) != 8, impossible dates, and other invalid formats.
		-- "So in ETL and data warehouse code, CASE is generally preferred whenever you have more than one validation rule, because it's easy to extend later, and everything will be in the same place".
		-- Keep in mind he converts the type from integer to date into the Else statement. But we first need to cast it to varchar, and then from varchar cast to date, because we cannot cast from integer to date (directly he means probably) in SQL Server.
		-- This is how we transform an integer to a date; this is how it's done in SQL Server (not sure if it applies for other variants).
		-- Now they're all (x3) real dates, and there isn't any wrong data inside those columns.

		---- 2nd fix:
		-- (Related to the Sales, Quantities and Prices)
		-- The Rules for fixing are as follows (we're going to build the transformations based on these rules. Afterwards: we have applied the business rules from the experts, and with that we cleaned up the data warehouse / so now we have cleaned up Sales, Quantity and Price, and it is following our business rules):
		-- a. If Sales is negative, zero or null, OR doesn't equal Quantity by Price, derive it using the equation Quantity and Price.
		-- b. If Price is zero or null, calculate it using Sales and Quantity.
		-- c. If Price is negative, convert it to a positive value (without any calculations, he said). Though he doesn't explicitly fix this using ABS(), it probably gets fixed when it's derived from the equation like the rule above. Besides making it ABS() when the sales is already equal to this positive value, would return the same result.
		-- I guess he doesn't replace the nulls with 0s (as with products costs), of course if the business allows that, because they can be derived from the other two columns.


		-- SELECT * FROM silver.crm_sales_details -- first check which column headers are included here.
			
		SET @start_time = GETDATE(); -- exact time when we start loading this table
		PRINT '>>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;

		PRINT '>>> Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
				sls_ord_number,
				sls_prd_key,
				sls_cust_id,
				sls_order_date,
				sls_ship_date,
				sls_due_date,
				sls_quantity,
				sls_price,
				sls_sales
		)

		-- basis for building the warehouse -- this comment might be older or copied from similar code
		SELECT
		-- the keys/IDs:
		sls_ord_number,
		sls_prd_key,
		sls_cust_id,
		-- the Dates:
		CASE WHEN sls_order_date <= 0 OR LEN(sls_order_date) != 8 -- there's nothing outside the boundaries, so that fix isn't needed here
				THEN NULL
				ELSE CAST(CAST(sls_order_date AS VARCHAR) AS DATE)
		END AS sls_order_date,
		CASE WHEN sls_ship_date <= 0 OR LEN(sls_ship_date) != 8 -- there's nothing outside the boundaries, so that fix isn't needed here
				THEN NULL
				ELSE CAST(CAST(sls_ship_date AS VARCHAR) AS DATE) -- this CAST part would've been enough for this example, but Case When is used just in case
		END AS sls_ship_date,
		CASE WHEN sls_due_date <= 0 OR LEN(sls_due_date) != 8 -- there's nothing outside the boundaries, so that fix isn't needed here
				THEN NULL
				ELSE CAST(CAST(sls_due_date AS VARCHAR) AS DATE) -- this CAST part would've been enough for this example, but Case When is used just in case
		END AS sls_due_date,

		sls_quantity, -- he didn't touch this, because it's already fine most likely.

		-- we start transforming the prices:
		CASE WHEN sls_price <= 0 OR sls_price IS NULL -- the < in <= was added by him, otherwise this would've been just =, if the < (negative) would be handled within the ABS() fix.
				THEN sls_sales / NULLIF(sls_quantity, 0) -- There are 2 aspects here. First, if the existing price is invalid as checked above (zero, negative or NULL), recalculate it here. Second, if the Quantity is zero, make it Null (using NULLIF). And when Price is derived by dividing Sales with NULL (quantity), it would also return NULL as a result. Make sure not to divide by zero, because the whole code is gonna break. Here we don't have zeros for Quantity, but in the future it might happen.
				-- By the way, there's an inherent flaw here regarding the quantity, because he skips the part that the Quantity can also be negative (not just zero, or null). Which we don't have, but we might. And I don't know how to fix this here. Note that the negative Quantity in the division and when the Price itself is negative (fixed with ABS below), are two different problems.
				-- WHEN sls_price < 0 THEN ABS(sls_price) -- this would've followed the rule of c., when price is negative convert to positive, without any calculations. But, he didn't use it for some reason.
				ELSE sls_price
		END AS sls_price,

		-- we start building the new sales:
		CASE WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales != sls_quantity * ABS(sls_price) -- negatives, zeros, nulls, and wrong calculations -- ABS is used to avoid the negative prices, which are wrong anyway (maybe he assumes they will be fixed in the prices step).
				THEN sls_quantity * ABS(sls_price) -- derive from the equation/use the right calculation -- ABS is used to avoid the negative prices, which would also make the sales wrong as a result.
				ELSE sls_sales -- if nothing is wrong, based on these rules for fixing above, then just use the sales as the are, because it means it's correct.
		END AS sls_sales

		-- sls_price AS sls_price_original -- he renamed it and kept it for the check, but I think it's not necessary beyond the check.
		-- sls_sales AS sls_sales_original, -- he renamed it and kept it for the check, but I think it's not necessary beyond the check.

		FROM bronze.crm_sales_details
		-- ORDER BY sls_price_original, sls_sales_original -- to check just the Sales/Quantity/Price parts
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';

		PRINT '--------------------------------------------------------';
		PRINT 'Loading EPR tables';
		PRINT '--------------------------------------------------------';

		/**************************/
		------ 4th table
		------ Types of transformations/What was completed (summary)
		-- Handling invalid values: with the 1st column, the cid. We removed the 'NAS' part at the beginning, now we're able to join with the customer table from the CRM system.
		-- Handling invalid values: with the 2nd column as well, the birth date. We handled invalid value, by setting future birthdates to NULL.
		-- Data Normalization & Handling missing values: with the 3rd column, the gender. We've Normalized the gender values/mapping the codes to more friendly values, and handled unknown cases (using 'n/a').


		-- SELECT * FROM silver.erp_customers_AZ12 -- first check which column headers are included here.

		SET @start_time = GETDATE(); -- exact time when we start loading this table
		PRINT '>>> Truncating Table: silver.erp_customers_AZ12';
		TRUNCATE TABLE silver.erp_customers_AZ12;

		PRINT '>>> Inserting Data Into: silver.erp_customers_AZ12';
		INSERT INTO silver.erp_customers_AZ12 (cid, bdate, gender) -- here he put all columns in the same row, unlike previous Insert statements.

		-- SELECT DISTINCT gender FROM ( -- gender_new if checking against the original
		SELECT
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
		END AS cid,
		CASE WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
		END AS bdate,
		CASE WHEN UPPER(TRIM(gender)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(gender)) = 'M' THEN 'Male'
				WHEN UPPER(TRIM(gender)) = '' OR gender IS NULL THEN 'n/a'
				ELSE TRIM(gender) -- Male and Female remain as-is
		END AS gender -- make this gender_new to check against the original gender
		-- his version
		/*
		CASE WHEN UPPER(TRIM(gender)) IN ('F', 'FEMALE') THEN 'Female'
				WHEN UPPER(TRIM(gender)) IN ('M', 'MALE') THEN 'Male'
				ELSE 'n/a' -- the blank and NULL become 'n/a'
		END AS gender
		*/
		FROM bronze.erp_customers_AZ12
		-- ) AS temp_gender_check
		-- check if there's any remaining cleaned-up cid's that aren't in the other table
		-- WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		--   	 ELSE cid
		-- END NOT IN (SELECT D ISTINCT cst_key FROM silver.crm_customer_info)
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';


		/**************************/
		------ 5th table
		------ Types of transformations/What was completed (summary):
		-- Handling invalid values: 1st column, the cid. We removed the dash with an empty string.
		-- Data Normalization & Handling missing values: 2nd column, the country. We have Normalized and Handled missing or blank country codes/replaced codes with friendly values, and at the same time handled missing values by replacing the empty strigs and NULL with 'n/a'.
		-- Remove unwanted spaces (TRIM): Again for the 2nd column, because we used TRIM for every line.


		-- SELECT * FROM silver.erp_location_A101 -- first check which column headers are included here.

		SET @start_time = GETDATE(); -- exact time when we start loading this table
		PRINT '>>> Truncating Table: silver.erp_location_A101';
		TRUNCATE TABLE silver.erp_location_A101;

		PRINT '>>> Inserting Data Into: silver.erp_location_A101';
		INSERT INTO silver.erp_location_A101
		(cid, country) -- here he put all columns in the same row, but a second one, unlike previous Insert statements.
		-- SELECT DISTINCT country FROM ( -- country_new if checking against the original
		SELECT
		REPLACE(cid, '-', '') AS cid,
		CASE WHEN TRIM(country) = 'DE' THEN 'Germany'
				WHEN TRIM(country) IN ('US', 'USA') THEN 'United States'
				WHEN TRIM(country) = '' OR country IS NULL THEN 'n/a'
				ELSE TRIM(country) -- other countries (with full names) remain as-is
		END AS country
		FROM bronze.erp_location_A101;
		-- ) AS temp_country_check
		-- check if there's any remaining cleaned-up cid's that aren't in the other table. 
		-- We're not finding any unmatching data now, which means our transformation is working, and we can connect the two tables.
		-- WHERE REPLACE(cid, '-', '') NOT IN
		-- (SELECT cst_key FROM silver.crm_customer_info)
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '------------------';


		/**************************/
		------ 6th table
		-- This doesn't need any transformations, based on the checks in the other code.


		-- SELECT * FROM silver.erp_px_category_G1V2 -- first check which column headers are included here.

		SET @start_time = GETDATE(); -- exact time when we start loading this table
		PRINT '>>> Truncating Table: silver.erp_px_category_G1V2';
		TRUNCATE TABLE silver.erp_px_category_G1V2;

		PRINT '>>> Inserting Data Into: silver.erp_px_category_G1V2';
		INSERT INTO silver.erp_px_category_G1V2 
		(id, category, subcategory, maintenance) -- here he put all columns in the same row, but a second one, unlike previous Insert statements.
		SELECT
		id,
		category,
		subcategory,
		maintenance
		FROM bronze.erp_px_category_G1V2;
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';

		SET @batch_end_time = GETDATE(); -- end time of loading the entire Silver Layer
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


-- Quality check (copied from Bronze layer)
-- Go through each table and check that everything is loaded as expected.
-- Change the table name to proceed to the next one. See the list of all tables below.
/*
SELECT COUNT(*) FROM silver.crm_customer_info; -- Check that all rows are included.
SELECT * FROM silver.crm_customer_info; -- Inspect that everything is loaded and is in the proper columns.
*/

-- List of all table names:
---- silver.crm_customer_info
---- silver.crm_product_info
---- silver.crm_sales_details;
---- silver.erp_customers_AZ12;
---- silver.erp_location_A101;
---- silver.erp_px_category_G1V2;
