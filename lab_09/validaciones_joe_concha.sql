-- =====================================================
-- LAB-09 
-- validaciones.sql 
-- Validaciones de negocio
-- Autor: Joe Concha
-- Tabla: DWHDEV.mart_fact_orders_joe_concha
-- =====================================================
USE DWHDEV;

-- 1. Total de órdenes por estado
SELECT order_status, COUNT(*) AS n
FROM DWHDEV.mart_fact_orders_joe_concha
GROUP BY order_status
ORDER BY n DESC;

-- 2. Revenue por mes (solo entregadas)
SELECT DATE_FORMAT(purchase_ts, '%Y-%m') AS m,
       SUM(total_amount)                AS revenue
FROM DWHDEV.mart_fact_orders_joe_concha
WHERE order_status = 'delivered'
GROUP BY m
ORDER BY m;

-- 3. % de envíos tardíos (sobre todas las órdenes, como en el enunciado)
SELECT 100.0 * SUM(is_late) / COUNT(*) AS pct_late
FROM DWHDEV.mart_fact_orders_joe_concha;

-- 3b. % de envíos tardíos solo sobre órdenes entregadas (referencia)
SELECT 100.0 * SUM(is_late) / COUNT(*) AS pct_late_delivered
FROM DWHDEV.mart_fact_orders_joe_concha
WHERE order_status = 'delivered';