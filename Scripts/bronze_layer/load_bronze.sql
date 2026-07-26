/*
Stored Procedure: Loading the Bronze Layer (Source → Bronze)
============================================================
Purpose:
This stored procedure loads/inserts data into the six Bronze tables from the respective external CSV files.

Methods:
It uses the truncate and bulk insert method to fully refresh the Silver tables and prevent duplication of the data.
By using this method, we insert data from the CSV files from scratch.
The column headers are skipped and data starts being inserted from the 2nd row, because the headers have already been defined upon creation of the tables (FIRSTROW = 2).
The delimiter/separator used in the CSV files needs to be correctly defined in the code; in this case the files use comma (FIELDTERMINATOR = ',').
Optionally, we can choose where the rows end. But this needs to be double-checked, because some rows can have blank values and be mistaken as the last row (ROWTERMINATOR = '\r\n').
TABLOCK is used to lock the entire table during the loading, in order to prevent issues and to improve performance. (needs checking)

Progress Tracking and Error Handling:
PRINT statements are included to track loading progress and assist with debugging.
This will help identify bottlenecks by showing the loading time for each table, and for the entire Silver layer.
Error handling is implemented using TRY...CATCH, making debugging and troubleshooting easier.
If an error occurs during loading, the CATCH block prints several diagnostic messages to help identify the issue.
After loading, data quality checks can be performed to validate row counts, column values, and business rules.

Warning:
Make sure to replace <folder_name> with your actual folder name. The full path needs to be specified exactly the same, otherwise this won't work.

Run the script:
	EXECUTE bronze.load_bronze;
===================================================================================================================
*/

USE Data_Warehouse_Project; -- switch to the correct database, if not already there
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN

	DECLARE 
		@start_time DATETIME, 
		@end_time DATETIME, 
		@batch_start_time DATETIME,
		@batch_end_time DATETIME;
	
	BEGIN TRY
		SET @batch_start_time = GETDATE(); -- start time for loading the entire Bronze layer
		
		PRINT '========================================================';
		PRINT 'Loading into the Bronze Layer';
		PRINT '========================================================';

		-- PRINT '--------------------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '--------------------------------------------------------';


		/**************************/
		-- Table 1: CRM customers

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: bronze.crm_customer_info';
		TRUNCATE TABLE bronze.crm_customer_info;

		PRINT '>>> Inserting Data into Table: bronze.crm_customer_info';
		BULK INSERT bronze.crm_customer_info
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\customer_info.csv' -- replace <folder_name> with your actual folder name
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- optional
			TABLOCK
		);
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';

		-- Code to count the number of rows for each table. Skipped here because the output already presents the number of rows affected.
		/*
		SELECT @row_count = COUNT(*) FROM bronze.crm_customer_info;
		PRINT '>>> Rows Loaded into bronze.crm_customer_info: ' + CAST(@row_count AS NVARCHAR(50));
		*/


		/**************************/
		-- Table 2: CRM products

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: bronze.crm_product_info';
		TRUNCATE TABLE bronze.crm_product_info;

		PRINT '>>> Inserting Data into Table: bronze.crm_product_info';
		BULK INSERT bronze.crm_product_info
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\product_info.csv' -- replace <folder_name> with your actual folder name
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- optional
			TABLOCK
		);
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';


		/**************************/
		-- Table 3: CRM sales

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: bronze.crm_sales_details';
		TRUNCATE TABLE bronze.crm_sales_details;

		PRINT '>>> Inserting Data into Table: bronze.crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\sales_details.csv' -- replace <folder_name> with your actual folder name
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- optional
			TABLOCK
		);
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';


		PRINT '--------------------------------------------------------';
		PRINT 'Loading EPR tables';
		PRINT '--------------------------------------------------------';


		/**************************/
		-- Table 4: ERP customers

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: bronze.erp_customers_AZ12';
		TRUNCATE TABLE bronze.erp_customers_AZ12;
	
		PRINT '>>> Inserting Data into Table: bronze.erp_customers_AZ12';
		BULK INSERT bronze.erp_customers_AZ12
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\customers_AZ12.csv' -- replace <folder_name> with your actual folder name
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- optional
			TABLOCK
		);
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';


		/**************************/
		-- Table 5: ERP location

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: bronze.erp_location_A101';
		TRUNCATE TABLE bronze.erp_location_A101;

		PRINT '>>> Inserting Data into Table: bronze.erp_location_A101';
		BULK INSERT bronze.erp_location_A101
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\location_A101.csv' -- replace <folder_name> with your actual folder name
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- optional
			TABLOCK
		);
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '---------------';


		/**************************/
		-- Table 6: ERP product category

		SET @start_time = GETDATE();
		
		PRINT '>>> Truncating Table: bronze.erp_px_category_G1V2';
		TRUNCATE TABLE bronze.erp_px_category_G1V2;

		PRINT '>>> Inserting Data into Table: bronze.erp_px_category_G1V2';
		BULK INSERT bronze.erp_px_category_G1V2
		FROM 'D:\Users\User\Desktop\<folder_name>\source_crm\px_category_G1V2.csv' -- replace <folder_name> with your actual folder name
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			-- ROWTERMINATOR = '\r\n', -- optional
			TABLOCK
		);
		
		SET @end_time = GETDATE();
		PRINT '>>> Load Duration: ' + CAST( DATEDIFF(second, @start_time, @end_time) AS NVARCHAR(50)) + ' seconds';
		/**************************/


		SET @batch_end_time = GETDATE(); -- end time for loading the entire Bronze layer
		
		PRINT '========================================================';
		PRINT 'Loading Bronze Layer is Completed';
		PRINT '>>> Total Load Duration: ' + CAST( DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR(50)) + ' seconds';
		PRINT '========================================================';

		-- SELECT 1/0 -- use this for testing the CATCH block. It divides by 0, so it should return an error.

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

END; -- procedure
