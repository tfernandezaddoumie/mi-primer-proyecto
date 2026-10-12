-- =====================================================================
-- Práctica 2 — Silver, Gold y orquestación
-- Consultas utilizadas en el README.md
-- Alumno: Tomás Fernández Addoumie | student_id: tfernandezaddoumie | escala: small
-- Namespace: workspace.bigdata_tfernandezaddoumie
-- =====================================================================


-- ---------------------------------------------------------------------
-- Sección 2. Resultados de la primera y segunda ejecución
-- ---------------------------------------------------------------------
SELECT *
FROM workspace.bigdata_tfernandezaddoumie.pipeline_run_audit
ORDER BY recorded_at;


-- ---------------------------------------------------------------------
-- Sección 3. Aceptadas y rechazadas de batch_002
-- ---------------------------------------------------------------------
SELECT source_batch_id, accepted_transactions, rejected_transactions
FROM workspace.bigdata_tfernandezaddoumie.gold_batch_summary
WHERE source_batch_id = 'batch_002';


-- =====================================================================
-- Preguntas de análisis
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Filas físicas por lote en bronze_transactions_incremental
-- ---------------------------------------------------------------------
SELECT source_batch_id, count(*) AS filas_fisicas
FROM workspace.bigdata_tfernandezaddoumie.bronze_transactions_incremental
GROUP BY source_batch_id
ORDER BY source_batch_id;


-- ---------------------------------------------------------------------
-- 2. Aceptadas y rechazadas por lote, reconciliadas con gold_batch_summary
-- ---------------------------------------------------------------------
WITH aceptadas AS (
  SELECT source_batch_id, count(*) AS aceptadas_silver
  FROM workspace.bigdata_tfernandezaddoumie.silver_transactions
  GROUP BY source_batch_id
),
rechazadas AS (
  SELECT source_batch_id, count(*) AS rechazadas_cuarentena
  FROM workspace.bigdata_tfernandezaddoumie.silver_transactions_quarantine
  GROUP BY source_batch_id
)
SELECT g.source_batch_id,
       a.aceptadas_silver,      g.accepted_transactions,
       r.rechazadas_cuarentena, g.rejected_transactions
FROM workspace.bigdata_tfernandezaddoumie.gold_batch_summary g
LEFT JOIN aceptadas  a ON g.source_batch_id = a.source_batch_id
LEFT JOIN rechazadas r ON g.source_batch_id = r.source_batch_id
ORDER BY g.source_batch_id;


-- ---------------------------------------------------------------------
-- 3. Motivos de rechazo por lote
-- ---------------------------------------------------------------------
SELECT source_batch_id, quality_reason, count(*) AS registros
FROM workspace.bigdata_tfernandezaddoumie.silver_transactions_quarantine
WHERE source_batch_id IN ('batch_002', 'batch_003')
GROUP BY source_batch_id, quality_reason
ORDER BY source_batch_id, quality_reason;


-- ---------------------------------------------------------------------
-- 4. Transacción 42: versiones en Bronze y versión vigente en Silver
-- ---------------------------------------------------------------------
-- 4a) Bronze (todas las columnas son texto: el id va entre comillas)
SELECT transaction_id, source_batch_id, updated_at, amount, customer_id, product_id
FROM workspace.bigdata_tfernandezaddoumie.bronze_transactions_all
WHERE transaction_id = '42'
ORDER BY updated_at;

-- 4b) Silver (columnas tipadas: el id es numérico)
SELECT transaction_id, source_batch_id, updated_at, amount, customer_id, product_id
FROM workspace.bigdata_tfernandezaddoumie.silver_transactions
WHERE transaction_id = 42;


-- ---------------------------------------------------------------------
-- 5. Una sola fila por transaction_id en silver_transactions
-- ---------------------------------------------------------------------
SELECT count(*) AS filas,
       count(DISTINCT transaction_id) AS ids_distintos
FROM workspace.bigdata_tfernandezaddoumie.silver_transactions;


-- ---------------------------------------------------------------------
-- 6. Tasa de rechazo por lote
-- ---------------------------------------------------------------------
SELECT source_batch_id,
       accepted_transactions AS aceptadas,
       rejected_transactions AS rechazadas,
       accepted_transactions + rejected_transactions AS total,
       round(100 * rejected_transactions / (accepted_transactions + rejected_transactions), 2) AS tasa_rechazo_pct
FROM workspace.bigdata_tfernandezaddoumie.gold_batch_summary
ORDER BY source_batch_id;


-- ---------------------------------------------------------------------
-- 7. Día de mayor monto y día de más transacciones
-- ---------------------------------------------------------------------
WITH diario AS (
  SELECT sale_date,
         SUM(total_amount)      AS monto_total,
         SUM(transaction_count) AS transacciones
  FROM workspace.bigdata_tfernandezaddoumie.gold_daily_sales
  GROUP BY sale_date
)
(SELECT 'Mayor monto' AS criterio, * FROM diario ORDER BY monto_total DESC LIMIT 1)
UNION ALL
(SELECT 'Más transacciones' AS criterio, * FROM diario ORDER BY transacciones DESC LIMIT 1);


-- ---------------------------------------------------------------------
-- 8. Tasa global de fraude por canal (correcta vs. promedio simple)
-- ---------------------------------------------------------------------
SELECT payment_channel,
       SUM(transaction_count)  AS transacciones,
       SUM(fraud_transactions) AS fraudes,
       round(100 * SUM(fraud_transactions) / SUM(transaction_count), 2) AS tasa_fraude_pct,
       round(100 * AVG(fraud_rate), 2) AS promedio_simple_pct
FROM workspace.bigdata_tfernandezaddoumie.gold_daily_sales
GROUP BY payment_channel
ORDER BY tasa_fraude_pct DESC;


-- ---------------------------------------------------------------------
-- 9. Combinación país × categoría líder (global y por país)
-- ---------------------------------------------------------------------
WITH pais_categoria AS (
  SELECT country, category, SUM(total_amount) AS monto_total
  FROM workspace.bigdata_tfernandezaddoumie.gold_daily_sales
  GROUP BY country, category
),
ranking AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY country ORDER BY monto_total DESC) AS rn
  FROM pais_categoria
)
SELECT country, category, monto_total
FROM ranking
WHERE rn = 1
ORDER BY monto_total DESC;


-- ---------------------------------------------------------------------
-- 10. Primeras dos filas de pipeline_run_audit (reejecución de batch_002)
-- ---------------------------------------------------------------------
SELECT *
FROM workspace.bigdata_tfernandezaddoumie.pipeline_run_audit
ORDER BY recorded_at
LIMIT 2;
