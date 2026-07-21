/*
Loading Data into the Bronze Layer (From the Source)
===========================
Script Purpose:
This is a stored procedure that loads/inserts the data from the six external CSV files into the respective Bronze tables, using the truncate and bulk insert method.
The truncation of the tables before loading is performed to avoid duplication of the data. In other words, we're refreshing the tables i.e. clearing and re-inserting the data.
This process is saved as a stored procedure for frequent usage, since data needs to be loaded into the Bronze layer daily.
PRINT statements are included for tracking progress and debugging. These show the duration of loading for each table and for the entire Bronze layer.
This will help identify issues and bottlenecks by understanding which tables consume more time to load.
Error handling is implemented using TRY...CATCH, allowing logging issues (errors, warnings, etc) for easier debugging, troubleshooting and improving data integrity.
If there's an error during loading, the CATCH will print several messages to help identify the error.
After the loading is done, quality checks should be performed for each table (columns and rows), especially when working with files.
*/

USE Data_Warehouse_Project; -- switch to the correct database, if not already there
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS -- create the stored procedure
BEGIN
	DECLARE 
		@start_time DATETIME, 
		@end_time DATETIME, 
		@batch_start_time DATETIME, -- to the second
		@batch_end_time DATETIME; -- to the second
		-- @row_count INT; -- optional. This can be used to count the number of rows for each table, but it's not needed here because the output already shows this.
	
	BEGIN TRY
		SET @batch_start_time = GETDATE(); -- start time for loading the entire Bronze layer.
		PRINT '========================================================';
		PRINT 'Loading into the Bronze Layer';
		PRINT '========================================================';

		-- PRINT '--------------------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '--------------------------------------------------------';

		-- First table
		SET @start_time = GETDATE(); -- exact time when we start loading this table
		PRINT '>>> Truncating Table: bronze.crm_customer_info';
		TRUNCATE TABLE bronze.crm_customer_info; -- first reset/empty the table to avoid duplicate insertion, but keep the columns and the structure.

		PRINT '>>> Inserting Data into Table: bronze.crm_customer_info';
		BULK INSERT bronze.crm_customer_info -- Then insert the data from the CSV file into the truncated table from scratch.
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\customer_info.csv' -- replace <folder_name> with your actual folder name. The full path needs to be specified exactly the same, otherwise this won't work.
		WITH (
			FIRSTROW = 2, -- start inserting the data from the second row, skipping the header (it's already been defined).
			FIELDTERMINATOR = ',', -- the delimiter/separator for the fields that is used in the CSV files.
			-- ROWTERMINATOR = '\r\n', -- where the rows end. Optional, but needs to be double-checked because some rows have blank values.
			TABLOCK -- locks the entire table during the loading to improve performance.
		);
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';

		-- Code to count the number of rows for each table. Skipped here because the output already presents the number of rows affected.
		/*
		SELECT @row_count = COUNT(*) FROM bronze.crm_customer_info;
		PRINT '>>> Rows Loaded into bronze.crm_customer_info: ' + CAST(@row_count AS NVARCHAR(50));
		*/

		-- Second table
		SET @start_time = GETDATE();
		PRINT ''; -- empty line for better readability in the output
		PRINT '>>> Truncating Table: bronze.crm_product_info';
		TRUNCATE TABLE bronze.crm_product_info;

		PRINT '>>> Inserting Data into Table: bronze.crm_product_info';
		BULK INSERT bronze.crm_product_info
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\product_info.csv' -- replace <folder_name> with your actual folder name, and ensure the full path is correct.
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- where the rows end. Optional, but needs to be double-checked because some rows have blank values.
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';

		-- Third table
		SET @start_time = GETDATE();
		PRINT ''; -- empty line for better readability in the output
		PRINT '>>> Truncating Table: bronze.crm_sales_details';
		TRUNCATE TABLE bronze.crm_sales_details;

		PRINT '>>> Inserting Data into Table: bronze.crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\sales_details.csv' -- replace <folder_name> with your actual folder name, and ensure the full path is correct.
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- where the rows end. Optional, but needs to be double-checked because some rows have blank values.
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		-- PRINT '---------------';

		PRINT '--------------------------------------------------------';
		PRINT 'Loading EPR tables';
		PRINT '--------------------------------------------------------';

		-- Fourth table
		SET @start_time = GETDATE();
		PRINT ''; -- empty line for better readability in the output
		PRINT '>>> Truncating Table: bronze.erp_customers_AZ12';
		TRUNCATE TABLE bronze.erp_customers_AZ12;
	
		PRINT '>>> Inserting Data into Table: bronze.erp_customers_AZ12';
		BULK INSERT bronze.erp_customers_AZ12
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\customers_AZ12.csv' -- replace <folder_name> with your actual folder name, and ensure the full path is correct.
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- where the rows end. Optional, but needs to be double-checked because some rows have blank values.
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';

		-- Fifth table
		SET @start_time = GETDATE();
		PRINT ''; -- empty line for better readability in the output
		PRINT '>>> Truncating Table: bronze.erp_location_A101';
		TRUNCATE TABLE bronze.erp_location_A101;

		PRINT '>>> Inserting Data into Table: bronze.erp_location_A101';
		BULK INSERT bronze.erp_location_A101
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\location_A101.csv' -- replace <folder_name> with your actual folder name, and ensure the full path is correct.
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- where the rows end. Optional, but needs to be double-checked because some rows have blank values.
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';

		-- Sixth table
		SET @start_time = GETDATE();
		PRINT ''; -- empty line for better readability in the output
		PRINT '>>> Truncating Table: bronze.erp_px_category_G1V2';
		TRUNCATE TABLE bronze.erp_px_category_G1V2;

		PRINT '>>> Inserting Data into Table: bronze.erp_px_category_G1V2';
		BULK INSERT bronze.erp_px_category_G1V2
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\px_category_G1V2.csv' -- replace <folder_name> with your actual folder name, and ensure the full path is correct.
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- where the rows end. Optional, but needs to be double-checked because some rows have blank values.
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		-- PRINT '---------------';

		SET @batch_end_time = GETDATE(); -- end time for loading the entire Bronze layer.
		PRINT '========================================================';
		PRINT 'Loading Bronze Layer is Completed';
		PRINT '>>> Total Load Duration: ' + CAST( DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '========================================================';

		-- SELECT 1/0 -- use this for testing the CATCH block.

	END TRY

	BEGIN CATCH
		PRINT '========================================================';
		PRINT 'ERROR OCCURRED DURING LOADING INTO BRONZE LAYER';
		PRINT CONCAT('Error Message: ', ERROR_MESSAGE());
		PRINT CONCAT('Error Number: ', ERROR_NUMBER());
		PRINT CONCAT('Error State: ', ERROR_STATE());
		PRINT CONCAT('Error Line: ', ERROR_LINE());
		PRINT CONCAT('Error Procedure: ', COALESCE(ERROR_PROCEDURE(), 'N/A'));
		PRINT CONCAT('Error Severity: ', ERROR_SEVERITY());
		PRINT CONCAT('Error Time: ', CONVERT(VARCHAR(19), GETDATE(), 120));
		PRINT '========================================================';
	END CATCH

END; -- end of the stored procedure

-- Quality check
-- Go through each table and check that everything is loaded as expected.
-- Change the table name to proceed to the next one. See the list of all tables below.
/*
SELECT COUNT(*) FROM bronze.crm_customer_info; -- Check that all rows are included.
SELECT * FROM bronze.crm_customer_info; -- Inspect that everything is loaded and is in the proper columns.
*/

-- List of all table names:
---- bronze.crm_customer_info
---- bronze.crm_product_info
---- bronze.crm_sales_details;
---- bronze.erp_customers_AZ12;
---- bronze.erp_location_A101;
---- bronze.erp_px_category_G1V2;
