-- ============================================================
-- business_analytics.sql
-- Business Intelligence Queries for Instacart Market Basket Analysis
-- ============================================================
-- These queries answer key business questions about customer behavior,
-- ordering patterns, and product preferences
-- ============================================================

-- ============================================================
-- SECTION 1: CUSTOMER ORDERING BEHAVIOR
-- ============================================================

-- Q1.1: When do customers place orders? (by hour of day)
-- Business insight: Identify peak ordering hours for resource planning
SELECT 
    order_hour_of_day AS hour,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders
GROUP BY order_hour_of_day
ORDER BY order_hour_of_day;

-- Q1.2: When do customers place orders? (by day of week)
-- Business insight: Understand weekly ordering patterns
SELECT 
    order_dow AS day_of_week,
    CASE order_dow
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders
GROUP BY order_dow
ORDER BY order_dow;

-- Q1.3: Order frequency - How many days between orders?
-- Business insight: Understand customer return patterns
SELECT 
    CASE 
        WHEN days_since_prior_order IS NULL THEN 'First Order'
        WHEN days_since_prior_order <= 7 THEN '0-7 days (Weekly)'
        WHEN days_since_prior_order <= 14 THEN '8-14 days (Bi-weekly)'
        WHEN days_since_prior_order <= 21 THEN '15-21 days (Tri-weekly)'
        WHEN days_since_prior_order <= 30 THEN '22-30 days (Monthly)'
        ELSE '30+ days (Rare)'
    END AS order_frequency,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders
GROUP BY 
    CASE 
        WHEN days_since_prior_order IS NULL THEN 'First Order'
        WHEN days_since_prior_order <= 7 THEN '0-7 days (Weekly)'
        WHEN days_since_prior_order <= 14 THEN '8-14 days (Bi-weekly)'
        WHEN days_since_prior_order <= 21 THEN '15-21 days (Tri-weekly)'
        WHEN days_since_prior_order <= 30 THEN '22-30 days (Monthly)'
        ELSE '30+ days (Rare)'
    END
ORDER BY 
    CASE 
        WHEN days_since_prior_order IS NULL THEN 0
        WHEN days_since_prior_order <= 7 THEN 1
        WHEN days_since_prior_order <= 14 THEN 2
        WHEN days_since_prior_order <= 21 THEN 3
        WHEN days_since_prior_order <= 30 THEN 4
        ELSE 5
    END;

-- Q1.4: Customer retention analysis
-- Business insight: How many customers return after their first order?
SELECT 
    CASE 
        WHEN is_first_order THEN 'First Order'
        ELSE 'Repeat Order'
    END AS order_type,
    COUNT(*) AS order_count,
    COUNT(DISTINCT user_id) AS unique_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders
GROUP BY is_first_order
ORDER BY is_first_order;

-- Q1.5: Customer lifetime orders - Order distribution per customer
-- Business insight: Identify power users vs one-time buyers
SELECT 
    CASE 
        WHEN max_order_num = 1 THEN '1 order (One-time buyer)'
        WHEN max_order_num BETWEEN 2 AND 5 THEN '2-5 orders (Occasional)'
        WHEN max_order_num BETWEEN 6 AND 10 THEN '6-10 orders (Regular)'
        WHEN max_order_num BETWEEN 11 AND 20 THEN '11-20 orders (Loyal)'
        ELSE '20+ orders (Power user)'
    END AS customer_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM (
    SELECT user_id, MAX(order_number) AS max_order_num
    FROM orders
    GROUP BY user_id
) AS user_orders
GROUP BY 
    CASE 
        WHEN max_order_num = 1 THEN '1 order (One-time buyer)'
        WHEN max_order_num BETWEEN 2 AND 5 THEN '2-5 orders (Occasional)'
        WHEN max_order_num BETWEEN 6 AND 10 THEN '6-10 orders (Regular)'
        WHEN max_order_num BETWEEN 11 AND 20 THEN '11-20 orders (Loyal)'
        ELSE '20+ orders (Power user)'
    END
ORDER BY 
    CASE 
        WHEN max_order_num = 1 THEN 1
        WHEN max_order_num BETWEEN 2 AND 5 THEN 2
        WHEN max_order_num BETWEEN 6 AND 10 THEN 3
        WHEN max_order_num BETWEEN 11 AND 20 THEN 4
        ELSE 5
    END;


-- ============================================================
-- SECTION 2: PRODUCT REORDERING BEHAVIOR
-- ============================================================

-- Q2.1: Overall reorder rate
-- Business insight: Customer loyalty to products
SELECT 
    'Overall Reorder Rate' AS metric,
    COUNT(*) AS total_products,
    SUM(CASE WHEN is_reordered THEN 1 ELSE 0 END) AS reordered_count,
    ROUND(100.0 * SUM(CASE WHEN is_reordered THEN 1 ELSE 0 END) / COUNT(*), 2) AS reorder_percentage
FROM order_products_train;

-- Q2.2: Top 20 most reordered products
-- Business insight: Staple products customers buy repeatedly
SELECT 
    p.product_id,
    p.product_name,
    d.department_name,
    a.aisle_name,
    COUNT(*) AS times_ordered,
    SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) AS times_reordered,
    ROUND(100.0 * SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) / COUNT(*), 2) AS reorder_rate
FROM order_products_train opt
JOIN products p ON opt.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
JOIN aisles a ON p.aisle_id = a.aisle_id
GROUP BY p.product_id, p.product_name, d.department_name, a.aisle_name
HAVING COUNT(*) >= 50  -- only products ordered at least 50 times
ORDER BY times_reordered DESC
LIMIT 20;

-- Q2.3: Reorder rate by department
-- Business insight: Which departments have highest customer loyalty?
SELECT 
    d.department_name,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) AS reorder_count,
    ROUND(100.0 * SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) / COUNT(*), 2) AS reorder_rate
FROM order_products_train opt
JOIN products p ON opt.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
GROUP BY d.department_name
ORDER BY reorder_rate DESC;

-- Q2.4: Reorder rate by aisle (Top 20)
-- Business insight: Most frequently repurchased product categories
SELECT 
    a.aisle_name,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) AS reorder_count,
    ROUND(100.0 * SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) / COUNT(*), 2) AS reorder_rate
FROM order_products_train opt
JOIN products p ON opt.product_id = p.product_id
JOIN aisles a ON p.aisle_id = a.aisle_id
GROUP BY a.aisle_name
HAVING COUNT(*) >= 100
ORDER BY reorder_rate DESC
LIMIT 20;


-- ============================================================
-- SECTION 3: SHOPPING CART ANALYSIS
-- ============================================================

-- Q3.1: Average cart size by day of week
-- Business insight: When do customers buy more items?
SELECT 
    o.order_dow,
    CASE o.order_dow
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(opt.product_id) AS total_products,
    ROUND(COUNT(opt.product_id)::NUMERIC / COUNT(DISTINCT o.order_id), 2) AS avg_cart_size
FROM orders o
JOIN order_products_train opt ON o.order_id = opt.order_id
GROUP BY o.order_dow
ORDER BY o.order_dow;

-- Q3.2: Average cart size by hour of day
-- Business insight: Does time of day affect purchase quantity?
SELECT 
    o.order_hour_of_day AS hour,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(opt.product_id) AS total_products,
    ROUND(COUNT(opt.product_id)::NUMERIC / COUNT(DISTINCT o.order_id), 2) AS avg_cart_size
FROM orders o
JOIN order_products_train opt ON o.order_id = opt.order_id
GROUP BY o.order_hour_of_day
ORDER BY o.order_hour_of_day;

-- Q3.3: Cart size distribution
-- Business insight: How many items do customers typically buy?
SELECT 
    cart_size,
    order_count,
    ROUND(100.0 * order_count / SUM(order_count) OVER(), 2) AS percentage
FROM (
    SELECT 
        CASE 
            WHEN item_count = 1 THEN '1 item'
            WHEN item_count BETWEEN 2 AND 5 THEN '2-5 items'
            WHEN item_count BETWEEN 6 AND 10 THEN '6-10 items'
            WHEN item_count BETWEEN 11 AND 20 THEN '11-20 items'
            WHEN item_count BETWEEN 21 AND 30 THEN '21-30 items'
            ELSE '30+ items'
        END AS cart_size,
        COUNT(*) AS order_count
    FROM (
        SELECT order_id, COUNT(*) AS item_count
        FROM order_products_train
        GROUP BY order_id
    ) AS cart_counts
    GROUP BY cart_size
) AS size_distribution
ORDER BY 
    CASE cart_size
        WHEN '1 item' THEN 1
        WHEN '2-5 items' THEN 2
        WHEN '6-10 items' THEN 3
        WHEN '11-20 items' THEN 4
        WHEN '21-30 items' THEN 5
        ELSE 6
    END;


-- ============================================================
-- SECTION 4: POPULAR PRODUCTS & DEPARTMENTS
-- ============================================================

-- Q4.1: Top 30 most ordered products
-- Business insight: Best-selling products across all orders
SELECT 
    p.product_id,
    p.product_name,
    d.department_name,
    a.aisle_name,
    COUNT(*) AS order_count
FROM order_products_train opt
JOIN products p ON opt.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
JOIN aisles a ON p.aisle_id = a.aisle_id
GROUP BY p.product_id, p.product_name, d.department_name, a.aisle_name
ORDER BY order_count DESC
LIMIT 30;

-- Q4.2: Most popular departments
-- Business insight: Which departments drive the most sales?
SELECT 
    d.department_name,
    COUNT(DISTINCT p.product_id) AS unique_products,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM order_products_train opt
JOIN products p ON opt.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
GROUP BY d.department_name
ORDER BY total_orders DESC;

-- Q4.3: Most popular aisles (Top 20)
-- Business insight: Most shopped aisles
SELECT 
    a.aisle_name,
    COUNT(DISTINCT p.product_id) AS unique_products,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM order_products_train opt
JOIN products p ON opt.product_id = p.product_id
JOIN aisles a ON p.aisle_id = a.aisle_id
GROUP BY a.aisle_name
ORDER BY total_orders DESC
LIMIT 20;


-- ============================================================
-- SECTION 5: ORDER TIMING PATTERNS
-- ============================================================

-- Q5.1: Orders by time period (Morning/Afternoon/Evening/Night)
-- Business insight: Peak ordering periods
SELECT 
    order_period,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders
WHERE order_period IS NOT NULL
GROUP BY order_period
ORDER BY 
    CASE order_period
        WHEN 'Morning' THEN 1
        WHEN 'Afternoon' THEN 2
        WHEN 'Evening' THEN 3
        WHEN 'Night' THEN 4
    END;

-- Q5.2: Average days between orders by customer segment
-- Business insight: Order frequency varies by customer loyalty
SELECT 
    CASE 
        WHEN max_order_num = 1 THEN 'One-time buyer'
        WHEN max_order_num BETWEEN 2 AND 5 THEN 'Occasional'
        WHEN max_order_num BETWEEN 6 AND 10 THEN 'Regular'
        WHEN max_order_num BETWEEN 11 AND 20 THEN 'Loyal'
        ELSE 'Power user'
    END AS customer_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(avg_days), 2) AS avg_days_between_orders
FROM (
    SELECT 
        user_id,
        MAX(order_number) AS max_order_num,
        AVG(days_since_prior_order) AS avg_days
    FROM orders
    WHERE days_since_prior_order IS NOT NULL
    GROUP BY user_id
) AS user_stats
GROUP BY 
    CASE 
        WHEN max_order_num = 1 THEN 'One-time buyer'
        WHEN max_order_num BETWEEN 2 AND 5 THEN 'Occasional'
        WHEN max_order_num BETWEEN 6 AND 10 THEN 'Regular'
        WHEN max_order_num BETWEEN 11 AND 20 THEN 'Loyal'
        ELSE 'Power user'
    END
ORDER BY 
    CASE 
        WHEN max_order_num = 1 THEN 1
        WHEN max_order_num BETWEEN 2 AND 5 THEN 2
        WHEN max_order_num BETWEEN 6 AND 10 THEN 3
        WHEN max_order_num BETWEEN 11 AND 20 THEN 4
        ELSE 5
    END;


-- ============================================================
-- SECTION 6: SUMMARY STATISTICS
-- ============================================================

-- Q6.1: Overall database summary
SELECT 
    'Total Aisles' AS metric, COUNT(*)::TEXT AS value FROM aisles
UNION ALL
SELECT 'Total Departments', COUNT(*)::TEXT FROM departments
UNION ALL
SELECT 'Total Products', COUNT(*)::TEXT FROM products
UNION ALL
SELECT 'Total Orders', COUNT(*)::TEXT FROM orders
UNION ALL
SELECT 'Unique Customers', COUNT(DISTINCT user_id)::TEXT FROM orders
UNION ALL
SELECT 'Train Order Items', COUNT(*)::TEXT FROM order_products_train
UNION ALL
SELECT 'Prior Order Items', COUNT(*)::TEXT FROM order_products_prior;

-- ============================================================
-- END OF BUSINESS ANALYTICS QUERIES
-- ============================================================
-- Usage: Run these queries in psql or pgAdmin after loading data
-- Example: psql -U postgres -d bigdata_db -f sql/business_analytics.sql
-- ============================================================
