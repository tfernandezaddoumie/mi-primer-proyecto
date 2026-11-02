# TP Final — Big Data y MLOps

- **Nombre:** Tomás Fernández Addoumie
- **student_id:** tfernandezaddoumie
- **Variante:** 2 — Ejecución · **Opción B:** Experimentación y comparación de modelos con MLflow

## Objetivo

Estimar la probabilidad de que un cliente de tarjeta de crédito caiga en mora el mes siguiente, comparando tres algoritmos con MLflow, y traducir el modelo elegido en una herramienta de gestión preventiva para el área de cobranzas.

## Contenido de la carpeta

| Archivo | Contenido |
|---|---|
| `README.md` | Este informe |
| `01_datos_y_exploracion.ipynb` | Lectura del CSV, preparación, controles de calidad, partición train/test, tabla Delta y exploración |
| `02_modelos.ipynb` | Entrenamiento de los tres modelos, registro en MLflow, comparación, elección y lectura de negocio |
| `img/` | Gráficos y capturas usados en este README |

Los notebooks están exportados con sus salidas.

## 1. Problema, datos y variable objetivo

### Problema

Un banco que emite tarjetas de crédito quiere anticipar qué clientes van a caer en mora el mes siguiente para actuar antes: un contacto preventivo, una oferta de refinanciación o un ajuste de límite. El área de cobranzas no puede gestionar a todos los clientes, así que necesita **ordenarlos por riesgo** y concentrar el esfuerzo donde más impacta.

### Datos

Usé el dataset público **Default of Credit Card Clients** (UCI Machine Learning Repository, licencia CC BY 4.0). Tiene 30.000 clientes de un banco de Taiwán, con datos de abril a septiembre de 2005. Lo elegí porque plantea el mismo problema que el caso de negocio (mora a nivel cliente), es público, no tiene datos identificatorios y tiene un tamaño que me permitió iterar rápido en Databricks Free Edition.

Cada fila es un cliente, con 6 meses de historia (sufijo 1 = septiembre, el mes más reciente; sufijo 6 = abril):

| Variables | Descripción |
|---|---|
| `limit_bal` | Límite de crédito otorgado (NT$, incluye adicionales) |
| `sex`, `education`, `marriage`, `age` | Datos demográficos del titular |
| `pay_1` … `pay_6` | Estado de pago de cada mes: -1 = pagó a tiempo; 1 a 8 = meses de atraso |
| `bill_amt1` … `bill_amt6` | Monto del resumen de cada mes (negativo = saldo a favor) |
| `pay_amt1` … `pay_amt6` | Monto pagado en cada mes |

### Variable objetivo

`default_next_month`: 1 si el cliente cayó en mora en octubre de 2005. El **22,1%** de los clientes cayó en mora, así que las clases están desbalanceadas.

### Preparación (notebook 01)

1. El archivo original viene en Excel: lo convertí a CSV sin modificar su contenido y lo subí al volumen `landing`.
2. Lo leí sin inferir tipos y casteé todas las columnas a entero con `try_cast`.
3. Renombré dos columnas: `default payment next month` (Delta no admite espacios) y `PAY_0`, que pasó a `pay_1` porque la secuencia original salta de `PAY_0` a `PAY_2`.
4. Controles de calidad: 30.000 filas, 30.000 IDs distintos, 0 valores nulos.
5. Agrupé como "otros" los valores no documentados de `education` (0, 5 y 6; 468 clientes en total en esa categoría) y de `marriage` (0; 377 clientes en total en esa categoría).
6. Guardé la tabla Delta `tp_credit_default`.

Los valores -2 y 0 de `pay_*` no están documentados. Asumí la interpretación habitual (-2 = sin consumo, 0 = pago mínimo) y los mantuve como numéricos.

### Exploración (sólo con train)

![Exploración](img/exploracion.png)

- **Estado de pago del último mes:** es la señal más fuerte. Los clientes al día (-2, -1, 0) caen en mora entre 13% y 17%; con un mes de atraso, 34%; con dos o más, entre 60% y 78%. La relación no es lineal: es plana y después salta.
- **Límite de crédito:** a mayor límite, menos mora (30% en el tramo más bajo contra 12% en el más alto). El límite ya refleja la evaluación de riesgo que hizo el banco al otorgarlo.
- **Edad:** efecto chico (entre 20,5% y 26,5% según el tramo).

## 2. Modelos y estrategia de evaluación

**Partición:** 80% train (24.021 clientes, 22,3% en mora) y 20% test (5.979 clientes, 21,3% en mora). Como todos los clientes comparten el mismo período, no es posible una partición temporal. Asigné cada cliente con un hash de su `id` (`pmod(xxhash64(id, 2026), 100) < 80`): es determinístico y da el mismo resultado en cada ejecución. Cada cliente aparece una sola vez, las variables son anteriores al mes que se predice y el preprocesamiento se ajusta sólo con train, dentro del pipeline, así que no hay fuga de información de test.

**Métrica principal:** PR-AUC en test. Con 21% de clientes en mora, un modelo que dice siempre "paga" tiene 78,7% de accuracy sin detectar a nadie. El PR-AUC mide qué tan bien el modelo ordena el riesgo y no depende del umbral. Como referencia, un modelo al azar tiene un PR-AUC igual a la tasa de mora (0,213).

**Modelos:** los tres usan las 23 variables y el mismo preprocesamiento (estandarización de las numéricas y one-hot de las categóricas).

| Modelo | Hiperparámetros |
|---|---|
| Regresión logística | `C = 1.0` |
| Random forest | `n_estimators = 200`, `max_depth = 8` |
| Gradient boosting | `learning_rate = 0.1`, `max_depth = 5`, `max_iter = 150` |

Limité la profundidad de los árboles para controlar el sobreajuste.

## 3. Registro en MLflow

Experimento: `/Users/tfernandezaddoumie@itba.edu.ar/bigdata_tfernandezaddoumie_tp_final`, con un run por modelo.

| Tipo | Qué registré |
|---|---|
| Parámetros | Modelo, hiperparámetros, umbral, cantidad de variables, filas de train y test, tabla y versión Delta de los datos |
| Métricas | En test: PR-AUC, ROC-AUC, accuracy, precision, recall, F1 y cantidad de alertas. En train: PR-AUC |
| Artefactos | Matriz de confusión, curva precision-recall y el modelo (pipeline completo) con su firma y un ejemplo de entrada |

Al run elegido le agregué además las tablas y gráficos del análisis de negocio (carpeta `negocio/`) y el tag `elegido = si`.

![Runs en MLflow](img/mlflow_runs.png)

## 4. Resultados, selección y limitaciones

### 4.1 Comparación

| Modelo | PR-AUC test | PR-AUC train | ROC-AUC | Accuracy | Precision | Recall | F1 | Alertas |
|---|---|---|---|---|---|---|---|---|
| **Gradient boosting** | **0,550** | 0,628 | 0,782 | 0,824 | 0,664 | 0,355 | 0,462 | 681 |
| Random forest | 0,544 | 0,648 | 0,780 | 0,825 | 0,670 | 0,351 | 0,461 | 667 |
| Regresión logística | 0,487 | 0,511 | 0,721 | 0,817 | 0,703 | 0,241 | 0,359 | 437 |

*Precision, recall, F1, accuracy y alertas corresponden al umbral 0,5.*

![Comparación](img/comparacion.png)

- Los tres modelos superan ampliamente al azar (0,213). El mejor es unas 2,6 veces mejor.
- La accuracy casi no distingue a los modelos entre sí ni de la estrategia de "decir siempre paga" (78,7%). Confirma que no sirve para este problema.
- Los modelos de árboles superan a la logística. La relación entre el atraso y la mora tiene saltos que una suma ponderada no capta.
- La logística casi no tiene brecha entre train y test (0,023): no sobreajusta, pero aprende menos. El random forest tiene la brecha más grande (0,104).

### 4.2 Selección

**Criterio:** el mayor PR-AUC en test; ante un empate práctico (menos de 0,005 de diferencia), el de menor brecha entre train y test.

**Elegí gradient boosting.** Tiene el mejor PR-AUC en test (0,550 contra 0,544 del random forest) y además sobreajusta menos (brecha de 0,078 contra 0,104).

### 4.3 Lectura de negocio

El modelo no responde "este cliente va a caer en mora": da una probabilidad. Su valor está en **ordenar** a los clientes para que cobranzas actúe primero donde hay más riesgo.

**Deciles de riesgo.** Ordené los 5.979 clientes de test de mayor a menor probabilidad y los dividí en 10 grupos iguales:

![Deciles](img/deciles.png)

- El **10% más riesgoso** tiene una tasa de mora del **68,9%**, 3,2 veces el promedio (lift = 3,2).
- El **10% menos riesgoso** tiene 3,7%.
- Gestionando sólo al **20% más riesgoso** se llega al **52%** de todos los clientes que caen en mora; con el 30%, al 64%. Eligiendo al azar, el 20% de los clientes cubriría el 20% de las moras.

**Elección del umbral.** El umbral define a cuántos clientes se alerta:

| Umbral | Clientes alertados | Precision | Recall | Alertas falsas | Moras no detectadas |
|---|---|---|---|---|---|
| 0,2 | 1.993 (33%) | 0,433 | 0,677 | 1.130 | 411 |
| 0,3 | 1.288 (21,5%) | 0,540 | 0,546 | 593 | 579 |
| 0,4 | 892 (15%) | 0,620 | 0,434 | 339 | 721 |
| 0,5 | 681 (11%) | 0,664 | 0,355 | 229 | 822 |
| 0,6 | 537 (9%) | 0,704 | 0,297 | 159 | 896 |

La elección es de negocio, no del modelo. Una alerta falsa cuesta poco: un contacto a un cliente que iba a pagar. Una mora no detectada cuesta mucho más: una deuda que se vuelve más difícil de recuperar. Por eso conviene un umbral bajo, limitado por la capacidad del área de cobranzas. Por ejemplo, con un umbral de 0,3 se gestiona a 1 de cada 5 clientes y se detecta a más de la mitad de los que caen en mora.

**Qué variables usa el modelo.** Importancia por permutación: cuánto cae el PR-AUC al desordenar cada variable.

![Importancia](img/importancia.png)

- El **estado de pago del último mes (`pay_1`)** domina: al desordenarlo, el PR-AUC cae 0,172, más de 10 veces que con cualquier otra variable. El mejor predictor de la mora es el atraso reciente.
- Le siguen, muy por detrás, el monto del último resumen y los estados de pago de meses anteriores.
- **Variables demográficas:** `education` y `age` aportan muy poco (≈ 0,007), y `sex` y `marriage` no aportan nada (≈ 0 o negativo). Se podrían excluir sin perder capacidad predictiva, lo que además evita el riesgo de discriminar por atributos sensibles.
- La importancia muestra qué usa el modelo para predecir, no qué causa la mora.

### 4.4 Limitaciones

- **Partición no temporal:** test evalúa a otros clientes del mismo período, no a meses futuros. En producción, el comportamiento de los clientes o la economía pueden cambiar (deriva de datos), así que el resultado probablemente sea optimista.
- **Contexto de los datos:** son de Taiwán, de 2005. Los patrones no se trasladan directamente a otro mercado o período.
- **Una sola partición y hiperparámetros fijos:** no exploré otras particiones ni optimicé hiperparámetros. La diferencia entre gradient boosting y random forest es chica y podría cambiar con otra partición.
- **Costos no cuantificados:** la elección del umbral depende de costos de negocio que el dataset no tiene.
- **Valores no documentados:** interpreté -2 y 0 en `pay_*` con un supuesto.
- **Escala:** usé Spark para la preparación, pero el entrenamiento se hace en memoria con scikit-learn. Para millones de clientes habría que entrenar de forma distribuida.

## 5. Cómo reproducir

1. Descargar el dataset de [UCI](https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients) y convertir el `.xls` a CSV sin modificaciones:
   ```python
   import pandas as pd
   pd.read_excel("default of credit card clients.xls", header=1).to_csv("credit_default.csv", index=False)
   ```
2. En Databricks Free Edition, subir `credit_default.csv` a `/Volumes/<catálogo>/bigdata_<student_id>/landing/tp_final/`.
3. Importar los dos notebooks en una carpeta del workspace y ejecutarlos completos y en orden, con el widget `student_id` correspondiente:
   - `01_datos_y_exploracion.ipynb` crea la tabla `tp_credit_default`;
   - `02_modelos.ipynb` crea el experimento, los tres runs y el análisis de negocio.

La partición es determinística (hash del `id`) y los modelos usan `random_state = 42`, así que una nueva ejecución da los mismos resultados. No se requieren librerías adicionales: Spark, scikit-learn y MLflow vienen con la plataforma.

## Fuentes y referencias

- Yeh, I. C. (2009). *Default of Credit Card Clients* [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C55S3H
- Yeh, I. C. y Lien, C. H. (2009). The comparisons of data mining techniques for the predictive accuracy of probability of default of credit card clients. *Expert Systems with Applications*, 36(2), 2473–2480.
- Material de la materia: clases 1 a 5 y prácticas (en particular, la práctica 5 de MLOps con MLflow).
