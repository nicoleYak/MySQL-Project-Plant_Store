-- Inspecting the data

SELECT * FROM orders;
SELECT * FROM customers;
SELECT * FROM inventory;
SELECT * FROM suppliers;

-- Checking unique values

-- Distinct dates:
SELECT DISTINCT purchase_date FROM orders ORDER BY purchase_date ASC;
SELECT DISTINCT MONTHNAME(purchase_date) AS purchase_months FROM orders;

-- Distinct customer:
SELECT COUNT(DISTINCT first_name, last_name) AS unique_customer FROM customers;

-- Distinct plants:
SELECT 
	COUNT(DISTINCT plant_name) AS total_plants,
    COUNT(DISTINCT plant_family) AS total_plant_families 
FROM inventory;

-- ANALYSIS:

-- Grouping sales by plant families:

SELECT 
	plant_family,
    ROUND(SUM(total_amount), 2) AS total_sales,
    SUM(quantity) AS total_units_sold
FROM orders
GROUP BY plant_family
ORDER BY total_sales DESC;


-- I want to see the plants that are not selling so well: (Based on the previous query)
SELECT plant_name
FROM orders
WHERE plant_family IN('Magnoliaceae' , 'Ginkgoaceae' , 'Santalaceae' , 'Caryophyllaceae' , 'Araliaceae');

-- Grouping sales by plant name: 
SELECT 
	plant_name,
    ROUND(SUM(total_amount), 2) AS total_sales,
    SUM(quantity) AS total_units_sold
FROM orders
GROUP BY plant_name
ORDER BY total_sales DESC;


-- What are the total sales each month? And what was the best month?

SELECT 
		DATE_FORMAT(purchase_date, '%Y-%m') AS month,
		ROUND(SUM(total_amount),2) AS revenue
	FROM orders 
	GROUP BY DATE_FORMAT(purchase_date, '%Y-%m')
    ORDER BY month;
    
 -- What are the total sales each day of the week and which day is the most profitable?
 
SELECT 
	DAYNAME(purchase_date) AS day_of_week,
    ROUND(SUM(total_amount),2) AS total_sales,
    COUNT(*) AS NumberOfTrans,
    SUM(quantity) AS total_sold,
    ROUND(AVG(total_amount/quantity),2) AS AVG_sales,
    'Peak Sales Day' AS Description
FROM orders
GROUP BY day_of_week
ORDER BY total_sales DESC
LIMIT 1;


-- Who is our most profitable customer? Commercial. landscape or residential?

SELECT
customer_type,
ROUND(SUM(total_amount),2) AS total_spent,
SUM(times_purchased) AS times_purchased
FROM orders
JOIN customers
ON orders.customer_id = customers.id
WHERE recurring_customer = 'Yes' AND times_purchased > 1
GROUP BY customer_type
ORDER BY total_spent DESC;

/* I want to see which plant varieties have suboptimal inventory levels, 
leading to potential overstocking or understocking?  */


SELECT 
	DISTINCT(CONCAT_WS(' - ', plant_name, plant_family)) AS Plant,
    units_left
FROM inventory
WHERE units_left > 50 AND plant_cost > 20
ORDER BY units_left DESC;

-- checking to see whether anyone has ordered these plants in the last few months:

SELECT 
	CONCAT_WS(' - ', inventory.plant_name, inventory.plant_family) AS Plant,
    COUNT(orders.id) AS total_ordered
FROM inventory
JOIN orders
ON orders.plant_name = inventory.plant_name
WHERE units_left > 50 AND plant_cost > 20
GROUP BY Plant
ORDER BY total_ordered DESC;


-- Checking which plant varieties are understocked and need to be re-stocked:

SELECT 
	orders.id,
    orders.quantity,
	CONCAT_WS(' - ', orders.plant_name, orders.plant_family) AS Plant,
    price,
    plant_cost,
    units_left,
    date_received
FROM inventory
JOIN orders
ON orders.plant_name = inventory.plant_name
WHERE units_left < 20
ORDER BY quantity DESC;

-- Which plants cost the shop the most? Which cost the least?

SELECT 
	CONCAT_WS(' - ', plant_name, plant_family) AS Plant,
    price,
    plant_cost,
    ROUND((price - plant_cost),2) AS profit
FROM inventory
ORDER BY plant_cost DESC;


-- What is the profitability ratio of the plant store?
-- Profitability ratio = Profit metric / revenue

WITH monthly_data AS (
	SELECT 
		DATE_FORMAT(o.purchase_date, '%Y-%m') AS month,
		ROUND(SUM(o.total_amount),2) AS revenue,
		ROUND(SUM(o.quantity * i.plant_cost),2) AS cost
	FROM orders o
	JOIN inventory i ON o.plant_name = i.plant_name
	GROUP BY DATE_FORMAT(o.purchase_date, '%Y-%m')
)

SELECT
	month,
    revenue,
    cost,
    CONCAT(ROUND((((revenue - cost) / revenue) * 100),2), '%') AS profitability_ratio
FROM monthly_data
ORDER BY month;


-- How do suppliers perform in terms of pricing, and reliability for high-demand plant varieties?
-- First, we will identify high - demand plants:

WITH HighDemandPlants AS (
	SELECT 
		plant_name,
        SUM(quantity) AS total_quantity_sold
	FROM orders
    GROUP BY plant_name
    HAVING SUM(quantity) > (SELECT AVG(quantity) FROM orders)
),
-- Identify pricing metrics for high-demand plants by supplier
SupplierPricing AS (
	SELECT
		I.supplier_id,
        S.supplier_name AS supplier_name,
        I.plant_name,
        I.price,
        I.plant_cost
	FROM inventory I
    JOIN suppliers S 
    ON I.supplier_id - S.id
    JOIN HighDemandPlants HDP ON I.plant_name = HDP.plant_name
)
SELECT
    supplier_name,
    ROUND(AVG(price),2) AS average_price,
    ROUND(AVG(plant_cost),2) AS average_cost
FROM SupplierPricing
GROUP BY supplier_name
ORDER BY average_cost DESC;

-- Supplier reliability:

WITH HighDemandPlants AS (
	SELECT 
		plant_name,
        SUM(quantity) AS total_quantity_sold
	FROM orders
    GROUP BY plant_name
    HAVING SUM(quantity) > (SELECT AVG(quantity) FROM orders)
)

SELECT
	S.id,
    S.supplier_name AS supplier_name,
    S.last_order,
    S.reorder_level,
    COUNT(I.id) AS plant_varieties_supplied,
    SUM(I.units_left) AS total_units_left
FROM suppliers S
JOIN inventory I ON S.id = I.supplier_id
JOIN HighDemandPlants HDP ON I.plant_name = HDP.plant_name
GROUP BY S.id, S.supplier_name, S.last_order, S.reorder_level
ORDER BY S.id;
















