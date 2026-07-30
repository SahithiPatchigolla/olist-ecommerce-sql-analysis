#  Olist E-Commerce Performance & Customer Insights (SQL Analysis)

##  Project Overview
This project performs an end-to-end relational data analysis on the **Olist E-Commerce dataset** using **MySQL Workbench**. The analysis focuses on identifying key business metrics, evaluating seller performance, segmenting customer behavior, and assessing delivery logistics to drive data-informed decisions.

---

##  Tech Stack & Database Architecture
* **Database Management System:** MySQL Workbench
* **Dataset Structure:** Consolidated transaction and logistics model (Custom `orders` schema with integrated item-level metrics).
* **SQL Techniques Used:**
  * Advanced Window Functions (`LAG`, `DENSE_RANK`)
  * CTEs (Common Table Expressions) & Aggregations
  * Conditional Logic (`CASE` statements)
  * Performance Optimization (Execution Time management & Indexing strategies)

---

##  Key Business Questions & SQL Solutions

### 1. Month-over-Month (MoM) Revenue Growth
Tracks monthly sales trends and calculates revenue growth percentage over time.

WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
        ROUND(SUM(price), 2) AS total_revenue
    FROM orders
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
)
SELECT 
    order_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY order_month) AS previous_month_revenue,
    ROUND(
        ((total_revenue - LAG(total_revenue) OVER (ORDER BY order_month)) / LAG(total_revenue) OVER (ORDER BY order_month)) * 100, 
        2
    ) AS mom_growth_percentage
FROM MonthlyRevenue
ORDER BY order_month;

### 2. Top Product Categories by State
Identifies the top 3 most popular product categories across different states using DENSE_RANK().

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

### 3. Delivery Performance Analysis
Evaluate logistics efficiency by determining the percentage of orders delivered on-time versus late.

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

### 4. Customer Segmentation  Analysis
Categorizes customers based on purchase frequency to measure customer retention and loyalty.

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

### 5. Top 10 Sellers by Revenue
Ranks top sellers based on overall sales revenue using optimized subqueries and CTEs.

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

**Key Insights & Recommendations**
​1.Logistics Optimization: Identifying delivery delays in specific regions can help renegotiate SLAs with regional carrier partners.
​2.Customer Retention: The majority of customers fall into the one-time buyer segment, highlighting an opportunity for targeted re-engagement marketing campaigns.
​3.Seller Strategy: Top-performing sellers contribute significantly to overall revenue; introducing seller incentive programs can further drive volume.



