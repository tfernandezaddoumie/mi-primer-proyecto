# Resolución Práctica 2 — Silver, Gold y orquestación

- **Nombre:** Tomás Fernández Addoumie
- **`student_id`:** `tfernandezaddoumie`
- **Escala:** `small`

## 1. Job

**Nombre del Job:** `bigdata_tfernandezaddoumie_silver_gold`

![DAG del Job](img/dag.png)

## 2. Resultados de la primera y segunda ejecución

```sql
SELECT * FROM workspace.bigdata_tfernandezaddoumie.pipeline_run_audit ORDER BY recorded_at;
```

| Ejecución | job_run_id | expected_batch_id | silver_rows | quarantine_rows | gold_rows | gold_total_amount | idempotence_compared |
|---|---|---|---:|---:|---:|---:|---|
| 1ª | 1112651856493980 | batch_002 | 50149 | 53 | 598 | 50286183.33 | false |
| 2ª | 789021784344547 | batch_002 | 50149 | 53 | 598 | 50286183.33 | true |

## 3. Aceptadas y rechazadas de `batch_002`

```sql
SELECT source_batch_id, accepted_transactions, rejected_transactions
FROM workspace.bigdata_tfernandezaddoumie.gold_batch_summary
WHERE source_batch_id = 'batch_002';
```

| source_batch_id | accepted_transactions | rejected_transactions |
|---|---:|---:|
| batch_002 | 200 | 2 |

## 4. `COPY INTO` y `MERGE`: problemas diferentes

_Pendiente._

## 5. Grano de las tablas Gold

| Tabla | Grano (una fila es…) |
|---|---|
| `gold_daily_sales` | un día × país × categoría × canal de pago |
| `gold_customer_risk` | un cliente con al menos una transacción |
| `gold_batch_summary` | un lote (`initial`, `batch_002`, `batch_003`) |

## 6. Visualizaciones

El código y las salidas completas están en `05_visualizacion.ipynb`.

### Consigna 1 — Evolución temporal

![Consigna 1](img/consigna1_temporal.png)

El día de mayor monto vendido y de mayor cantidad de transacciones es el mismo: 2026-03-01 ($7.310.840 en 7.236 transacciones). Esto implica un ticket promedio estable entre días, porque si el día de mayor monto vendido hubiera tenido menos transacciones que otro, sería porque ese día el ticket subió por algún motivo. Esto lo vemos en el último gráfico de líneas, donde para los primeros 7 días se mantiene alrededor de los $1.000.

### Consigna 2 — Canal y fraude

![Consigna 2](img/consigna2_canal_fraude.png)

El canal con mayor tasa de fraude son las transferencias, con un 13,91% sobre el total de transacciones de ese canal, aproximadamente 1 punto por encima de wallet (12,97%) y card (12,54%). La tasa la calculé como fraudes sobre transacciones de cada canal y no promediando `fraud_rate`, porque cada fila de Gold tiene un volumen distinto.

Es útil el gráfico de la derecha sobre el volumen por canal porque nos permite entender si la tasa que informamos es representativa. En este caso vemos que lo es: los 3 canales tienen volúmenes similares y grandes (~16.700 transacciones cada uno). Si, por ejemplo, transfer tuviera solo 100 transacciones, una tasa del 30% sería poco confiable, porque unos pocos casos de más o de menos la moverían mucho; con 16.000 transacciones por canal eso no pasa.

### Consigna 3 — Concentración geográfica y de producto

![Consigna 3](img/consigna3_pais_categoria.png)

Elegí un heatmap porque permite comparar una métrica en dos dimensiones simultáneamente: en este caso las categorías y los países, donde la intensidad del azul indica el monto en millones de $ y además cada celda tiene el valor escrito. La combinación de país y categoría que genera el mayor monto es la venta de artículos para el hogar en Brasil ($2,36 M).

No hay una categoría dominante en todos los países: home lidera en Brasil, Chile y Uruguay, y books en Argentina y México (en Chile la diferencia entre ambas es mínima: $2,17 M contra $2,16 M). Lo que sí se mantiene es que home y books son las dos categorías que más monto generan, primeras o segundas en todos los países.

Si bien creo que este dato es valioso, lo complementaría con la cantidad de transacciones por país para entender el market share entre categorías. Con este gráfico vemos que Brasil es el país con más monto en hogar, pero no nos dice si es el mercado donde más gente nos usa para comprar cosas para el hogar o si simplemente más cantidad de transacciones (lo que sería lógico en un mercado más grande como BR)

### Consigna 4 — Calidad del pipeline

![Consigna 4](img/consigna4_calidad_lotes.png)

La calidad de los dos lotes nuevos es la misma: 99,01% de registros aceptados (2 rechazos sobre 202 y 203 transacciones). En proporción, estos lotes tienen una tasa de rechazo mayor que la carga inicial, donde se aceptó el 99,90% (51 rechazos sobre casi 50.000). Es indispensable hacer la evaluación por proporciones y no con valores absolutos, porque eso nos podría llevar a pensar que “solo dos transacciones rechazadas no es grave”, cuando comparado con el estándar inicial la tasa de rechazo es casi 10 veces mayor.

De todas formas hay que tener en cuenta el tamaño de los lotes nuevos. Con ~200 registros, un solo rechazo de más o de menos mueve la tasa medio punto, mientras que en la carga inicial harían falta cientos.

## 7. Preguntas de análisis y comprensión

### Análisis de las tablas

### 1. ¿Cuántas filas físicas recibió cada lote en `bronze_transactions_incremental`? Escribí una consulta que muestre el resultado por `source_batch_id`.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 2. Para cada lote, ¿cuántas transacciones fueron aceptadas y cuántas quedaron en `silver_transactions_quarantine`? Reconciliá tus resultados con `gold_batch_summary`.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 3. ¿Qué motivos de rechazo aparecen en la cuarentena y cuántos registros tiene cada uno por lote? ¿Los rechazos observados coinciden con los casos introducidos por el generador?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 4. Seguí la transacción `42` desde `bronze_transactions_all` hasta `silver_transactions`. ¿Cuántas versiones existen en Bronze y cuál quedó vigente en Silver? Mostrá las columnas que justifican la elección.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 5. Comprobá mediante una consulta que `silver_transactions` tiene una sola fila por `transaction_id`. ¿Qué resultado indicaría que la deduplicación falló?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 6. Calculá la tasa de rechazo de cada lote como `rechazadas / (aceptadas + rechazadas)` en `gold_batch_summary`. ¿Es correcto comparar solamente las cantidades absolutas si los lotes tienen tamaños diferentes?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 7. ¿Qué día presenta el mayor monto total y cuál presenta la mayor cantidad de transacciones? Consultá `gold_daily_sales` y explicá si ambos máximos coinciden.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 8. ¿Qué canal de pago tiene la mayor tasa global de fraude? Calculala como `SUM(fraud_transactions) / SUM(transaction_count)` y explicá por qué no corresponde promediar directamente `fraud_rate`.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 9. ¿Qué combinación de país y categoría concentra el mayor monto vendido? Mostrá también la combinación líder dentro de cada país.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 10. Compará las dos primeras filas de `pipeline_run_audit` correspondientes a la reejecución de `batch_002`. ¿Qué métricas permanecen iguales y qué columna demuestra que se realizó la comparación de idempotencia?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### Interpretación del código y del pipeline

### 11. En `01_ingest_bronze_incremental.ipynb`, ¿qué problema resuelve `COPY INTO` y qué información utiliza para evitar cargar dos veces el mismo archivo físico?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 12. ¿Por qué la vista `bronze_transactions_all` usa `UNION ALL` en lugar de eliminar duplicados? ¿En qué capa se resuelven los duplicados de negocio y por qué?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 13. ¿Por qué las transacciones iniciales reciben `source_batch_id='initial'` y usan `event_ts` como `updated_at`? ¿Cómo afecta eso a la corrección de la transacción `42`?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 14. En `quality_rules.py`, ¿qué ventaja ofrece `try_cast` frente a un `cast` convencional cuando llega un importe como `N/A`?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 15. Las reglas de calidad asignan una única `quality_reason`. ¿Qué sucede si un registro viola más de una regla y por qué importa el orden de las condiciones?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 16. Explicá cómo se construye `_record_key` y cómo se usa junto con `row_number`. ¿Qué caso cubre el hash cuando `transaction_id` no puede convertirse a un número?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 17. Interpretá las dos cláusulas principales del `MERGE` de `silver_transactions`. ¿Cuándo se actualiza una fila existente y cuándo se inserta una nueva?

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 18. ¿Por qué las tablas Gold se reconstruyen completamente en esta práctica mientras Silver se actualiza con `MERGE`? Mencioná una ventaja y una limitación de cada estrategia.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 19. ¿Por qué `expected_batch_id` no participa en la detección del archivo nuevo? Indicá qué parte del pipeline descubre `batch_003` y qué parte utiliza el parámetro.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._

### 20. Si la tarea `build_silver` falla, ¿qué ocurre con `build_gold` y `validate` en el Job? Explicá cómo las dependencias del DAG evitan publicar o validar resultados incompletos.

**Consulta / referencia:**

_Pendiente._

**Resultado:**

_Pendiente._

**Respuesta:**

_Pendiente._
