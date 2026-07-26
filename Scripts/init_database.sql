/*
Create Database and Schemas
===========================
Script Purpose:
This script creates a new database named "Data Warehouse Project" after checking if it already exists.
If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas
within the database: "bronze", "silver", and "gold", following our architecture design.

WARNING:
Running this script will drop the entire "Data Warehouse Project" database if it exists.
All data in the database will be permanently deleted. Proceed with caution
and ensure you have proper backups before running this script.
*/

USE master; -- Switch to the master database (system) to create your new project database.

-- Check if the "Data Warehouse Project" database exists, then drop and recreate it.
-- But beware if it has data and it's been worked on, because you won't be able to bring it back.
/*
IF EXISTS (SELECT 1 FROM sys. databases WHERE name = 'Data Warehouse Project')
BEGIN
ALTER DATABASE 'Data Warehouse Project' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE 'Data Warehouse Project';
END;
*/

CREATE DATABASE "Data Warehouse Project";

USE "Data Warehouse Project"; -- Switch to the new database. 

-- Now we can go and start building things inside this database.
-- Next step is to start creating the schemas. The meaning of schema is, you can think about it like a folder or a container that helps you to keep things organized.
-- So as we decided in the architecture, we have three layers: bronze, silver, and gold.
-- And now we're going to create a schema for each layer.

CREATE SCHEMA bronze;
CREATE SCHEMA silver;
GO -- Separate batches when working with multiple SQL statements (if you want to run the silver and gold at once).
CREATE SCHEMA gold;
-- In order to check if the schemas are there, go to the Security folder, and open the Schemas subfolder.

-- Now we have the database and the three layers, and we can start developing each layer individually.
