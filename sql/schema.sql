-- ============================================================
-- schema.sql - Instacart Database Schema
-- ============================================================
-- This file creates all tables for the Instacart Market Basket Analysis
-- Primary keys, foreign keys, and indexes are added AFTER bulk loading
-- for better performance (see load.py add_constraints function)
-- ============================================================

-- aisles table - stores the aisle categories (134 rows)
CREATE TABLE IF NOT EXISTS aisles (
    aisle_id    SMALLINT     NOT NULL,
    aisle_name  VARCHAR(100) NOT NULL
    -- PK added after load: CONSTRAINT aisles_pkey PRIMARY KEY (aisle_id)
);

-- departments table - stores the department categories (21 rows)
CREATE TABLE IF NOT EXISTS departments (
    department_id   SMALLINT    NOT NULL,
    department_name VARCHAR(50) NOT NULL
    -- PK added after load: CONSTRAINT departments_pkey PRIMARY KEY (department_id)
);

-- products table - stores all products (~50K rows)
CREATE TABLE IF NOT EXISTS products (
    product_id          INTEGER      NOT NULL,
    product_name        VARCHAR(500) NOT NULL,
    aisle_id            SMALLINT     NOT NULL,
    department_id       SMALLINT     NOT NULL,
    product_name_length SMALLINT
    -- PK added after load: CONSTRAINT products_pkey PRIMARY KEY (product_id)
    -- FK added after load: CONSTRAINT fk_products_aisle FOREIGN KEY (aisle_id) REFERENCES aisles(aisle_id)
    -- FK added after load: CONSTRAINT fk_products_dept FOREIGN KEY (department_id) REFERENCES departments(department_id)
    -- INDEX added after load: idx_products_aisle, idx_products_dept
);

-- orders table - stores all customer orders (~3.4M rows)
-- days_since_prior_order can be NULL for first orders - this is intentional
CREATE TABLE IF NOT EXISTS orders (
    order_id               INTEGER     NOT NULL,
    user_id                INTEGER     NOT NULL,
    eval_set               VARCHAR(10) NOT NULL,
    order_number           SMALLINT    NOT NULL,
    order_dow              SMALLINT    NOT NULL,  -- 0=Sunday, 6=Saturday
    order_hour_of_day      SMALLINT    NOT NULL,  -- 0-23 hour
    days_since_prior_order REAL,                  -- NULL = first order
    is_first_order         BOOLEAN,               -- derived: days_since_prior_order IS NULL
    order_period           VARCHAR(12)            -- derived: Morning/Afternoon/Evening/Night
    -- PK added after load: CONSTRAINT orders_pkey PRIMARY KEY (order_id)
    -- INDEX added after load: idx_orders_user for user_id queries
);

-- order_products_train table - training set order products (~1.4M rows)
CREATE TABLE IF NOT EXISTS order_products_train (
    order_id           INTEGER  NOT NULL,
    product_id         INTEGER  NOT NULL,
    add_to_cart_order  SMALLINT NOT NULL,  -- sequence order in cart (1, 2, 3...)
    reordered          SMALLINT NOT NULL,  -- 0 or 1
    is_reordered       BOOLEAN              -- derived: reordered = 1
    -- PK added after load: CONSTRAINT order_products_train_pkey PRIMARY KEY (order_id, product_id)
    -- FK added after load: CONSTRAINT fk_opt_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
    -- FK added after load: CONSTRAINT fk_opt_product FOREIGN KEY (product_id) REFERENCES products(product_id)
    -- INDEX added after load: idx_opt_order
);

-- order_products_prior table - prior orders (32M+ rows, loaded in chunks)
CREATE TABLE IF NOT EXISTS order_products_prior (
    order_id           INTEGER  NOT NULL,
    product_id         INTEGER  NOT NULL,
    add_to_cart_order  SMALLINT NOT NULL,
    reordered          SMALLINT NOT NULL,
    is_reordered       BOOLEAN
    -- No PK due to size (would slow down bulk load significantly)
    -- FK added after load: CONSTRAINT fk_opp_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
    -- FK added after load: CONSTRAINT fk_opp_product FOREIGN KEY (product_id) REFERENCES products(product_id)
    -- INDEX added after load: idx_opp_order, idx_opp_product for query performance
);

-- ============================================================
-- Notes:
-- 1. All constraints and indexes are added AFTER data loading
--    using add_constraints() in load.py
-- 2. This approach is 5-10x faster for bulk loading
-- 3. The order_products_prior table has no primary key due to
--    its size (3M-32M rows) - composite PK would slow queries
-- ============================================================
