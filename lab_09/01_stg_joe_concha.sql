-- =====================================================
-- LAB-09 
-- 01_stg.sql 
-- Capa stg (vistas sobre raw)
-- Autor: Joe Concha
-- Idempotente: DROP VIEW IF EXISTS + CREATE VIEW
-- (SingleStore no soporta CREATE OR REPLACE VIEW)
-- Lee solo la última corrida de carga (MAX(_load_run))
-- =====================================================
USE DSADEV;

-- stg_v_customers
DROP VIEW IF EXISTS DSADEV.stg_v_customers_joe_concha;
CREATE VIEW DSADEV.stg_v_customers_joe_concha AS
SELECT
    customer_id,
    customer_unique_id,
    CAST(customer_zip_code_prefix AS SIGNED) AS zip_code,
    UPPER(TRIM(customer_city))               AS city,
    UPPER(TRIM(customer_state))              AS state,
    _load_ts                                 AS source_load_ts
FROM DSADEV.raw_olist_customers_joe_concha
WHERE customer_id IS NOT NULL
  AND _load_run = (SELECT MAX(_load_run) FROM DSADEV.raw_olist_customers_joe_concha);

-- stg_v_orders
DROP VIEW IF EXISTS DSADEV.stg_v_orders_joe_concha;
CREATE VIEW DSADEV.stg_v_orders_joe_concha AS
SELECT
    order_id,
    customer_id,
    order_status,
    CAST(NULLIF(TRIM(order_purchase_timestamp), '')      AS DATETIME(6)) AS purchase_ts,
    CAST(NULLIF(TRIM(order_approved_at), '')             AS DATETIME(6)) AS approved_ts,
    CAST(NULLIF(TRIM(order_delivered_carrier_date), '')  AS DATETIME(6)) AS deliv_carrier_ts,
    CAST(NULLIF(TRIM(order_delivered_customer_date), '') AS DATETIME(6)) AS deliv_customer_ts,
    CAST(NULLIF(TRIM(order_estimated_delivery_date), '') AS DATETIME(6)) AS est_deliv_ts
FROM DSADEV.raw_olist_orders_joe_concha
WHERE order_id IS NOT NULL
  AND order_status IN ('delivered','shipped','canceled','unavailable',
                       'invoiced','processing','approved','created')
  AND _load_run = (SELECT MAX(_load_run) FROM DSADEV.raw_olist_orders_joe_concha);

-- stg_v_order_items
DROP VIEW IF EXISTS DSADEV.stg_v_order_items_joe_concha;
CREATE VIEW DSADEV.stg_v_order_items_joe_concha AS
SELECT
    order_id,
    CAST(order_item_id AS SIGNED)          AS item_id,
    product_id,
    seller_id,
    CAST(price AS DECIMAL(10,2))           AS price,
    CAST(freight_value AS DECIMAL(10,2))   AS freight,
    CAST(NULLIF(TRIM(shipping_limit_date), '') AS DATETIME(6)) AS shipping_limit
FROM DSADEV.raw_olist_order_items_joe_concha
WHERE order_id IS NOT NULL
  AND CAST(price AS DECIMAL(10,2)) > 0
  AND _load_run = (SELECT MAX(_load_run) FROM DSADEV.raw_olist_order_items_joe_concha);

-- Verificación
SELECT 'customers' v, COUNT(*) n FROM DSADEV.stg_v_customers_joe_concha
UNION ALL SELECT 'orders', COUNT(*) FROM DSADEV.stg_v_orders_joe_concha
UNION ALL SELECT 'order_items', COUNT(*) FROM DSADEV.stg_v_order_items_joe_concha;