use olist_db;
Create table raw_data_cleaned AS select DISTINCT * from olist_customers;
Create table Customerss As 
select distinct 
	   customer_id,
       customer_unique_id, 
       customer_zip_code_prefix,
       customer_city,
       customer_state 
       from Customers 
       where customer_id IS NOT NULL;
create table Products As
select distinct
       product_id,
       product_category_name,
       product_name_lenght,
       product_description_lenght,
       product_photos_qty,
       product_weight_g,
       product_length_cm,
       product_height_cm,
       product_width_cm
       from customers where product_id IS NOT NULL;
create table  Orders As
select 
       order_id,
       order_unique_id,
       customer_id,
       seller_id,
       product_id,
       order_status,
       shipping_limit_date,
       order_purchase_timestamp,
       order_approved_at,
       order_delivered_carrier_date,
       order_delivered_customer_date,
       order_estimated_delivery_date,
       day_of_purchase,
       month_of_purchase,
       year_of_purchase,
       `month/year_of_purchase`,
       price,
       freight_value
from customers where order_id IS NOT NULL;
create table Sellers As
select
       seller_id,
       seller_city,
       seller_state,
       seller_zip_code_prefix
from customers where seller_id IS NOT NULL;
create table Order_payments As
select
      order_id,
      payment_sequential,
      payment_installments,
      payment_value
from customers where order_id IS NOT NULL;

show tables;
select * from Customerss limit 5;

--- Month-over-Month (MoM) Revenue Growth Rate ---
WITH MonthlySales AS (
    SELECT 
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS sales_month,
        ROUND(SUM(price), 2) AS total_revenue
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
)
SELECT 
    sales_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY sales_month) AS previous_month_revenue,
    ROUND(
        ((total_revenue - LAG(total_revenue) OVER (ORDER BY sales_month)) / 
        LAG(total_revenue) OVER (ORDER BY sales_month)) * 100, 2
    ) AS mom_growth_percentage
FROM MonthlySales
ORDER BY sales_month;
--- Top 3 Categories ----
WITH StateCategorySales AS (
    SELECT 
        c.customer_state,
        p.product_category_name,
        ROUND(SUM(o.price), 2) AS total_sales,
        DENSE_RANK() OVER (
            PARTITION BY c.customer_state 
            ORDER BY SUM(o.price) DESC
        ) AS category_rank
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN products p ON o.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY c.customer_state, p.product_category_name
)
SELECT 
    customer_state,
    category_rank,
    product_category_name,
    total_sales
FROM StateCategorySales
WHERE category_rank <= 3
ORDER BY customer_state, category_rank;
---- On-Time vs. Late Delivery  Performance Analysis ---
SELECT 
    CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late Delivery'
        ELSE 'On-Time / Early'
    END AS delivery_status,
    COUNT(order_id) AS total_orders,
    ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM orders WHERE order_status = 'delivered'), 2) AS order_percentage,
    ROUND(AVG(price), 2) AS avg_order_value
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;
--- Customer Spending Tiers (Customer Segmentation) ---
WITH CustomerTotalSpend AS (
    SELECT 
        customer_id,
        SUM(price) AS total_spent
    FROM orders
    GROUP BY customer_id
),
CustomerSegments AS (
    SELECT 
        customer_id,
        total_spent,
        CASE 
            WHEN total_spent > 500 THEN 'High Value (> $500)'
            WHEN total_spent BETWEEN 150 AND 500 THEN 'Medium Value ($150 - $500)'
            ELSE 'Low Value (< $150)'
        END AS customer_tier
    FROM CustomerTotalSpend
)
SELECT 
    customer_tier,
    COUNT(customer_id) AS total_customers,
    ROUND(SUM(total_spent), 2) AS total_revenue_generated
FROM CustomerSegments
GROUP BY customer_tier
ORDER BY total_revenue_generated DESC;
--- Top 10 Best Sellers & Cumulative Revenue Contribution ---
WITH TopSellers AS(
		select
          seller_id,
          count(DISTINCT order_id)As total_orders,
          ROUND(sum(price),2)As total_revenue
         from orders
         group by seller_id
         )
select DISTINCT
   ts.seller_id,
   s.seller_city,
   s.seller_state,
   ts.total_orders,
   ts.total_revenue,
   DENSE_RANK() OVER(ORDER BY ts.total_revenue DESC)AS seller_rank
from TopSellers ts
join sellers s ON ts.seller_id=s.seller_id
order by ts.total_revenue DESC LIMIT 10;


