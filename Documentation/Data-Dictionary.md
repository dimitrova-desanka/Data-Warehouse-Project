# Data Dictionary for the Gold Layer

## Overview
The Gold Layer is the business-level data representation, structured to support analytical and reporting use cases. It consists of **dimension tables** and a **fact table** for specific business metrics.

---

### 1. **gold.dim_customers**
- **Purpose:** Stores customer details enriched with demographic and geographic data.
- **Columns:**

| Column Name      | Data Type     | Description                                                                                   |
|------------------|---------------|-----------------------------------------------------------------------------------------------|
| customer_surrogate_key     | BIGINT           | Surrogate key uniquely identifying each customer record in the customer dimension table.               |
| customer_id      | INT           | Unique numerical identifier assigned to each customer.                                        |
| customer_code  | NVARCHAR(50)  | Alphanumeric identifier representing the customer, consisting of a fixed prefix followed by the customer_id (e.g. 'AW00011045').         |
| customer_first_name       | NVARCHAR(50)  | The customer's first name, as recorded in the system.                                         |
| customer_last_name        | NVARCHAR(50)  | The customer's last name or family name.                                                     |
| customer_country          | NVARCHAR(50)  | The country of residence for the customer (e.g. 'Australia').                               |
| customer_birth_date        | DATE          | The date of birth of the customer, formatted as YYYY-MM-DD (e.g. 1971-10-06).               |
| customer_marital_status   | NVARCHAR(50)  | The marital status of the customer (e.g. 'Married', 'Single').                              |
| customer_gender_newer           | NVARCHAR(50)  | The gender of the customer (e.g. 'Male', 'Female', 'n/a').                                  |
| customer_create_date      | DATE          | The date and time when the customer record was created in the system. |

---

### 2. **gold.dim_products**
- **Purpose:** Provides information about the products and their attributes.
- **Columns:**

| Column Name         | Data Type     | Description                                                                                   |
|---------------------|---------------|-----------------------------------------------------------------------------------------------|
| product_surrogate_key         | BIGINT           | Surrogate key uniquely identifying each product record in the product dimension table.         |
| product_id          | INT           | Unique numerical identifier assigned to each product.            |
| product_code      | NVARCHAR(50)  | Structured alphanumeric code representing the product, reflecting key product characteristics such as category, color, and size (e.g. 'BK-M82B-38'). |
| product_name        | NVARCHAR(50)  | Descriptive name of the product, including key product characteristics such as category, color, and size (e.g. 'Mountain-100 Black- 38').         |
| product_category_id         | NVARCHAR(50)  | Unique identifier for the product's category, linking to its high-level classification.     |
| product_category            | NVARCHAR(50)  | The broader classification of the product (e.g. 'Bikes', 'Components') to group related items.  |
| product_subcategory         | NVARCHAR(50)  | A more detailed classification of the product within the category, such as product type.      |
| product_line        | NVARCHAR(50)  | The specific product line or series to which the product belongs (e.g. 'Road', 'Mountain').      |
| product_maintenance         | NVARCHAR(50)  | Indicates whether the product requires maintenance (e.g. 'Yes', 'No').                       |
| product_cost                | INT           | The cost or base price of the product, measured in monetary units.                            |
| product_start_date          | DATE          | The date when the product became available for sale or use. |

---

### 3. **gold.fact_sales**
- **Purpose:** Stores transactional sales data for analytical purposes.
- **Columns:**

| Column Name     | Data Type     | Description                                                                                   |
|-----------------|---------------|-----------------------------------------------------------------------------------------------|
| sales_order_number    | NVARCHAR(50)  | Unique alphanumeric identifier for each sales order (e.g. 'SO54496').                      |
| customer_surrogate_key    | BIGINT           | Surrogate key linking the order to the customer dimension table.                              |
| product_surrogate_key     | BIGINT           | Surrogate key linking the order to the product dimension table.                               |
| sales_order_date      | DATE          | The date when the order was placed.                                                           |
| sales_shipping_date   | DATE          | The date when the order was shipped to the customer.                                          |
| sales_due_date        | DATE          | The date when the order payment was due.                                                      |
| price           | INT           | The price per unit of the product for the line item, in whole currency units (e.g. 25).      |
| quantity        | INT           | The number of units of the product ordered for the line item (e.g. 1).                       |
| sales    | INT           | The total monetary value of the sale for the line item, in whole currency units (e.g., 25).   |
