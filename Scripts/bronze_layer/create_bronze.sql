/*
DDL Script: Create Bronze Tables
===========================
Script Purpose:
This script creates tables in the bronze schema, while also checking for and droppping any existing tables beforehand.
There are total of 6 tables, one for each CSV file from the source systems CRM and ERP (each with 3 tables).
Please note that this DDL script creates empty tables without data, which will be populated in a later step.
Re-run this script to re-define the DDL structure of the bronze tables.
*/

IF OBJECT_ID ('bronze.crm_customer_info', 'U') IS NOT NULL -- checks if the table exists; U stands for user-defined tables
	DROP TABLE bronze.crm_customer_info;
CREATE TABLE bronze.crm_customer_info (
	cst_id INT, -- example: 11000
	cst_key NVARCHAR(50), -- example: AW00011000
	cst_firstname NVARCHAR(50), -- example: Eugene
	cst_lastname NVARCHAR(50), -- example: Huang  
	cst_marital_status NVARCHAR(50), -- example: M or S (2 options total)
	cst_gndr NVARCHAR(50), -- example: M or F (2 options total)
	cst_create_date DATE -- example: 10 06 2025
);

IF OBJECT_ID ('bronze.crm_product_info', 'U') IS NOT NULL
	DROP TABLE bronze.crm_product_info;
CREATE TABLE bronze.crm_product_info (
	prd_id INT, -- example: 213
	prd_key NVARCHAR(50), -- example: CO-RF-FR-R92B-58
	prd_name NVARCHAR(50), -- example: Sport-100 Helmet- Red
	prd_cost INT, -- example: 748
	prd_line NVARCHAR(50), -- example: M, R, S or T (4 options total)
	prd_start_date DATE, -- example: 07 01 2011
	prd_end_date DATE -- example: 12 28 2007
);

IF OBJECT_ID ('bronze.crm_sales_details', 'U') IS NOT NULL
	DROP TABLE bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details (
	sls_ord_number NVARCHAR(50), -- example: SO43697
	sls_prd_key NVARCHAR(50), -- example: BK-R93R-62
	sls_cust_id INT, -- example: 28389
	sls_order_date INT, -- example: 20101229 (should be converted to Date)
	sls_ship_date INT, -- example: 20110105 (should be converted to Date)
	sls_due_date INT, -- example: 20110110 (should be converted to Date)
	sls_price INT, -- example: 3578
	sls_quantity INT, -- example: 10
	sls_sales INT -- example: 3578
);

IF OBJECT_ID ('bronze.erp_customers_AZ12', 'U') IS NOT NULL
	DROP TABLE bronze.erp_customers_AZ12;
CREATE TABLE bronze.erp_customers_AZ12 (
	cid NVARCHAR(50), -- example: NASAW00011008
	bdate DATE, -- example: 08 14 1973
	gender NVARCHAR(50) -- example: Female
);

IF OBJECT_ID ('bronze.erp_location_A101', 'U') IS NOT NULL
	DROP TABLE bronze.erp_location_A101;
CREATE TABLE bronze.erp_location_A101 (
	cid NVARCHAR(50), -- example: AW-00011025
	country NVARCHAR(50), -- example: Australia
);

IF OBJECT_ID ('bronze.erp_px_category_G1V2', 'U') IS NOT NULL
	DROP TABLE bronze.erp_px_category_G1V2;
CREATE TABLE bronze.erp_px_category_G1V2 (
	id NVARCHAR(50), -- example: AC_BR
	category NVARCHAR(50), -- example: Accessories
	subcategory NVARCHAR(50), -- example: Bike Stands
	maintenance NVARCHAR(50) -- example: Yes or No (2 options total)
);
