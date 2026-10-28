-- =====================================================
-- LAB-09 
-- 02_mart.sql 
-- Capa mart (modelo dimensional)
-- Autor: Joe Concha
-- Destino: DWHDEV · Origen: vistas stg en DSADEV
-- Idempotente: CREATE TABLE IF NOT EXISTS + ON DUPLICATE KEY UPDATE
-- =====================================================
USE DWHDEV;
 
-- ---------- DIM_CUSTOMER ----------
CREATE TABLE IF NOT EXISTS DWHDEV.mart_dim_customer_joe_concha (
    customer_id        VARCHAR(64) NOT NULL,
    customer_unique_id VARCHAR(64),
    zip_code           INT,
    city               VARCHAR(128),
    state              VARCHAR(8),
    _scd_start         DATETIME(6),
    _scd_end           DATETIME(6),
    is_current         TINYINT,
    PRIMARY KEY (customer_id),
    SHARD KEY (customer_id)
);
 
INSERT INTO DWHDEV.mart_dim_customer_joe_concha
SELECT
    customer_id, customer_unique_id, zip_code, city, state,
    NOW(), '9999-12-31', 1
FROM DSADEV.stg_v_customers_joe_concha
ON DUPLICATE KEY UPDATE
    city       = VALUES(city),
    state      = VALUES(state),
    _scd_start = NOW();
 
-- ---------- FACT_ORDERS (1 fila por order) ----------
CREATE TABLE IF NOT EXISTS DWHDEV.mart_fact_orders_joe_concha (
    order_id             VARCHAR(64) NOT NULL,
    customer_id          VARCHAR(64),
    order_status         VARCHAR(32),
    purchase_ts          DATETIME(6),
    approved_ts          DATETIME(6),
    deliv_customer_ts    DATETIME(6),
    est_deliv_ts         DATETIME(6),
    total_items          INT,
    total_price          DECIMAL(12,2),
    total_freight        DECIMAL(12,2),
    total_amount         DECIMAL(12,2),
    payment_type         VARCHAR(32),
    payment_installments INT,
    is_late              TINYINT,
    PRIMARY KEY (order_id),
    SHARD KEY (order_id)
);
 
INSERT INTO DWHDEV.mart_fact_orders_joe_concha
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.purchase_ts,
    o.approved_ts,
    o.deliv_customer_ts,
    o.est_deliv_ts,
    COALESCE(i.total_items, 0)                         AS total_items,
    i.total_price,
    i.total_freight,
    i.total_price + i.total_freight                    AS total_amount,
    p.payment_type,
    p.payment_installments,
    -- NULL si no se entregó; tardío solo si llegó un DÍA después del estimado
    -- (la fecha estimada viene siempre a las 00:00:00, así que se compara por fecha)
    CASE
        WHEN o.deliv_customer_ts IS NULL THEN NULL
        WHEN DATE(o.deliv_customer_ts) > DATE(o.est_deliv_ts) THEN 1
        ELSE 0
    END AS is_late
FROM DSADEV.stg_v_orders_joe_concha o
-- items agregados por order (evita multiplicar filas)
LEFT JOIN (
    SELECT order_id,
           COUNT(item_id) AS total_items,
           SUM(price)     AS total_price,
           SUM(freight)   AS total_freight
    FROM DSADEV.stg_v_order_items_joe_concha
    GROUP BY order_id
) i ON i.order_id = o.order_id
-- payments agregados por order (solo la última carga)
LEFT JOIN (
    SELECT order_id,
           MAX(payment_type)                        AS payment_type,
           MAX(CAST(payment_installments AS SIGNED)) AS payment_installments
    FROM DSADEV.raw_olist_order_payments_joe_concha
    WHERE _load_run = (SELECT MAX(_load_run) FROM DSADEV.raw_olist_order_payments_joe_concha)
    GROUP BY order_id
) p ON p.order_id = o.order_id
ON DUPLICATE KEY UPDATE
    order_status         = VALUES(order_status),
    approved_ts          = VALUES(approved_ts),
    deliv_customer_ts    = VALUES(deliv_customer_ts),
    est_deliv_ts         = VALUES(est_deliv_ts),
    total_items          = VALUES(total_items),
    total_price          = VALUES(total_price),
    total_freight        = VALUES(total_freight),
    total_amount         = VALUES(total_amount),
    payment_type         = VALUES(payment_type),
    payment_installments = VALUES(payment_installments),
    is_late              = VALUES(is_late);
 
-- Verificación
SELECT 'dim_customer' t, COUNT(*) n FROM DWHDEV.mart_dim_customer_joe_concha
UNION ALL SELECT 'fact_orders', COUNT(*) FROM DWHDEV.mart_fact_orders_joe_concha;
 
-- Control: la suma de precios del fact debe igualar la de stg (sin duplicados)
SELECT
    (SELECT SUM(total_price) FROM DWHDEV.mart_fact_orders_joe_concha) AS fact_price,
    (SELECT SUM(price)       FROM DSADEV.stg_v_order_items_joe_concha) AS stg_price;