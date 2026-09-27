# Resolución Práctica 1 — Ingesta y capa Bronze

- **Nombre:** Tomás Fernández Addoumie
- **`student_id`:** `tfernandezaddoumie`
- **Namespace:** `workspace.bigdata_tfernandezaddoumie` (escala `small`)

## Resultados

| Tabla Bronze | Filas |
|---|---:|
| `bronze_customers` | 5.000 |
| `bronze_products` | 500 |
| `bronze_transactions` | 50.011 |
| `bronze_events` | 200.000 |

Diagnóstico de calidad sobre `bronze_transactions`: **50.011 filas**, **50.000 `transaction_id` distintos** (11 duplicados) y **52 importes no convertibles** a número (`"N/A"`). En Bronze se conservan tal como llegaron; se corrigen en Silver.

## Observaciones sobre formatos

**1. CSV y JSON: el esquema se pierde o se adivina.**
El CSV no guarda tipos: leído sin opciones, todas las columnas de `transactions` son `string`. Con `inferSchema=true` Spark hace una pasada extra sobre los datos y detecta `integer` y `timestamp`, pero `amount` sigue como `string` porque alcanzan unos pocos `"N/A"` para invalidar el tipo numérico. Es una decisión inestable: un lote sin `N/A` produciría otro esquema. El JSON conserva estructuras anidadas (`context` es un `struct` con `platform` y `session_id`) e infiere números como `long`, pero `event_ts` queda como `string` porque JSON no tiene tipo fecha.

**2. Parquet: el esquema viaja con el archivo y el almacenamiento es columnar.**
`products` se lee con tipos correctos (`long`, `decimal(12,2)`) sin inferir nada. Además, al ser columnar, el `EXPLAIN` de un `GROUP BY payment_channel` muestra `ReadSchema: struct<payment_channel:string>`: Spark lee solo la columna que necesita, no la fila completa.

**3. Delta: Parquet más un log de transacciones.**
`DESCRIBE DETAIL` muestra formato `delta`, 1 archivo de ~687 KB comprimido con zstd y features como *deletion vectors*. `DESCRIBE HISTORY` registra la versión 0 (`CREATE OR REPLACE TABLE AS SELECT`) con usuario, notebook, fecha y métricas (`numOutputRows = 50011`). Un directorio Parquet no tiene historial, versiones ni garantías transaccionales; Delta habilita auditoría, Time Travel y operaciones como `MERGE`.

## Las cinco V en este caso

- **Volumen:** 50.000 transacciones y 200.000 eventos en escala `small`, y un millón de eventos en `demo`. Una plataforma real genera ese volumen en horas, lo que justifica un motor distribuido como Spark.
- **Velocidad:** los eventos de navegación (`view`, `search`, `add_to_cart`, `checkout`) se generan de forma continua, y el fraude debe detectarse mientras ocurre, no al día siguiente. `_ingested_at` permite medir la latencia de ingesta.
- **Variedad:** tres formatos (CSV, JSON y Parquet), con datos estructurados y semiestructurados (el `struct` anidado `context` en eventos).
- **Veracidad:** importes `"N/A"`, transacciones duplicadas, tipos perdidos en el CSV y, en el desafío, un esquema que cambia sin aviso. Por eso Bronze agrega `_source`, `_source_file` y `_ingested_at`: para poder rastrear cada dato hasta su origen.
- **Valor:** el objetivo es detectar operaciones fraudulentas (`is_fraud`) para reducir pérdidas. El valor aparece recién en Silver/Gold y en el modelo de la clase 4, pero depende de una ingesta trazable.

## Reflexión final del desafío

_Pendiente: completar después de resolver `02_desafio.ipynb` (máximo 150 palabras)._
