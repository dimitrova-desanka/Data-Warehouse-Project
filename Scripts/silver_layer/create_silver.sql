/*
DDL Script: Create Silver Tables
===========================
Script Purpose:
This script creates tables in the silver schema, while also checking for and droppping any existing tables beforehand.
There are total of 6 tables, one for each CSV file from the source systems CRM and ERP (each with 3 tables).
Please note that this DDL script creates empty tables without data, which will be populated in a later step.
Re-run this script to re-define the DDL structure of the silver tables.
*/

IF OBJECT_ID ('silver.crm_customer_info', 'U') IS NOT NULL -- checks if the table exists; U stands for user-defined tables
	DROP TABLE silver.crm_customer_info;
CREATE TABLE silver.crm_customer_info (
	cst_id INT, -- example: 11000
	cst_key NVARCHAR(50), -- example: AW00011000
	cst_firstname NVARCHAR(50), -- example: Eugene
	cst_lastname NVARCHAR(50), -- example: Huang  
	cst_marital_status NVARCHAR(50), -- example: M or S (2 options total)
	cst_gndr NVARCHAR(50), -- example: M or F (2 options total)
	cst_create_date DATE, -- example: 10 06 2025
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- extra metadata column
);

IF OBJECT_ID ('silver.crm_product_info', 'U') IS NOT NULL
	DROP TABLE silver.crm_product_info;
CREATE TABLE silver.crm_product_info (
	prd_id INT, -- example: 213
	prd_key_original NVARCHAR(50), -- example: CO-RF-FR-R92B-58 -- the existing product key, which is longer and will be split into two.
	prd_line NVARCHAR(50), -- example: M, R, S or T (4 options total) -- moved up from under cost, to be grouped with the related columns.
	prd_category_id NVARCHAR(50), -- first substring from the existing product key, referring to the category.
  prd_key_extracted NVARCHAR(50), -- second substring from the existing product key, referring to just the extracted part.
	prd_name NVARCHAR(50), -- example: Sport-100 Helmet- Red
	prd_cost INT, -- example: 748
	prd_start_date DATE, -- example: 07 01 2011
	prd_end_date_new DATE, -- new end date, which uses the start date from the next row and substracts 1 day.
	prd_end_date_old DATE, -- example: 12 28 2007 --  original end date, which is older than the start date. This seems like invalid data, but is kept for reference.
	dwh_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID ('silver.crm_sales_details', 'U') IS NOT NULL
	DROP TABLE silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
	sls_ord_number NVARCHAR(50), -- example: SO43697
	sls_prd_key NVARCHAR(50), -- example: BK-R93R-62
	sls_cust_id INT, -- example: 28389
	sls_order_date DATE, -- original example: 20101229; converted to Date afterwards
	sls_ship_date DATE, -- original example: 20110105; converted to Date afterwards
	sls_due_date DATE, -- original example: 20110110; converted to Date afterwards
	sls_quantity INT, -- example: 10
	sls_price INT, -- example: 3578
	sls_sales INT, -- example: 3578
	dwh_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID ('silver.erp_customers_AZ12', 'U') IS NOT NULL
	DROP TABLE silver.erp_customers_AZ12;
CREATE TABLE silver.erp_customers_AZ12 (
	cid NVARCHAR(50), -- example: NASAW00011008
	bdate DATE, -- example: 08 14 1973
	gender NVARCHAR(50), -- example: Female
	dwh_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID ('silver.erp_location_A101', 'U') IS NOT NULL
	DROP TABLE silver.erp_location_A101;
CREATE TABLE silver.erp_location_A101 (
	cid NVARCHAR(50), -- example: AW-00011025
	country NVARCHAR(50), -- example: Australia
	dwh_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID ('silver.erp_px_category_G1V2', 'U') IS NOT NULL
	DROP TABLE silver.erp_px_category_G1V2;
CREATE TABLE silver.erp_px_category_G1V2 (
	id NVARCHAR(50), -- example: AC_BR
	category NVARCHAR(50), -- example: Accessories
	subcategory NVARCHAR(50), -- example: Bike Stands
	maintenance NVARCHAR(50), -- example: Yes or No (2 options total)
	dwh_create_date DATETIME2 DEFAULT GETDATE()
);
