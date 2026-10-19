# Entrega práctica 5 — MLOps con MLflow

- **Nombre:** Tomas Fernandez Addoumie
- **student_id:** tfernandezaddoumie
- **Escala:** small

## Mis runs

| run | modelo | features | class_weight | umbral | hiperparametros | train_pr_auc | pr_auc | accuracy | precision | recall | f1 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| gb_completas_u02 | gradient_boosting | completas | ninguno | 0.2 | learning_rate=0.03, max_depth=5 | 0.63 | 0.583 | 0.883 | 0.457 | 0.674 | 0.544 |
| gb_completas_u03 | gradient_boosting | completas | ninguno | 0.3 | learning_rate=0.03, max_depth=5 | 0.63 | 0.583 | 0.906 | 0.545 | 0.57 | 0.557 |
| gb_completas | gradient_boosting | completas | ninguno | 0.5 | learning_rate=0.03, max_depth=5 | 0.63 | 0.583 | 0.919 | 0.733 | 0.345 | 0.469 |
| gb_completas_balanced | gradient_boosting | completas | balanced | 0.5 | learning_rate=0.03, max_depth=5 | 0.613 | 0.581 | 0.801 | 0.318 | 0.804 | 0.456 |
| max_depth=8 | random_forest | completas | ninguno | 0.5 | n_estimators=100, max_depth=8 | 0.643 | 0.568 | 0.914 | 0.799 | 0.226 | 0.352 |
| lr_completas | logistic_regression | completas | ninguno | 0.5 | C=1.0 | 0.531 | 0.545 | 0.917 | 0.758 | 0.288 | 0.417 |
| max_depth=5 | random_forest | completas | ninguno | 0.5 | n_estimators=100, max_depth=5 | 0.561 | 0.541 | 0.903 | 0.906 | 0.078 | 0.144 |
| max_depth=sin_limite | random_forest | completas | ninguno | 0.5 | n_estimators=100, max_depth=sin_limite | 1.0 | 0.537 | 0.916 | 0.689 | 0.341 | 0.456 |
| max_depth=3 | random_forest | completas | ninguno | 0.5 | n_estimators=100, max_depth=3 | 0.535 | 0.525 | 0.896 | 0.0 | 0.0 | 0.0 |
| gb_cliente | gradient_boosting | cliente | ninguno | 0.5 | learning_rate=0.03, max_depth=5 | 0.563 | 0.511 | 0.912 | 0.678 | 0.288 | 0.404 |
| 01_repro_b | random_forest | cliente | ninguno | 0.5 | n_estimators=100, max_depth=8 | 0.594 | 0.51 | 0.909 | 0.722 | 0.207 | 0.321 |
| 01_repro_a | random_forest | cliente | ninguno | 0.5 | n_estimators=100, max_depth=8 | 0.594 | 0.51 | 0.909 | 0.722 | 0.207 | 0.321 |
| 01_manual_logistica | logistic_regression | basicas | ninguno | 0.5 | C=1.0 | 0.341 | 0.339 | 0.896 | 0.493 | 0.045 | 0.082 |
| gb_basicas | gradient_boosting | basicas | ninguno | 0.5 | learning_rate=0.03, max_depth=5 | 0.363 | 0.326 | 0.896 | 0.0 | 0.0 | 0.0 |
| lr_solo_regla | logistic_regression | solo_regla | ninguno | 0.5 | C=1.0 | 0.179 | 0.17 | 0.896 | 0.0 | 0.0 | 0.0 |

Quedó como champion el gb_completas_u02 que es un gradient boosting con features completas, learning rate = 0.03, max_depth = 5 y class weight ninguno. 

**Run registrado:**

## Datos y tracking

**1.** train tiene 35.654 filas con 11,05 % de contracargos (1 al 5 de marzo), test 7.129 filas con 10,38 % (6 de marzo) y nuevas 7.165 filas con 11,05 % (7 de marzo).

Se separa por fecha porque en producción el modelo siempre va a predecir compras futuras con lo aprendido del pasado; si se partiera al azar, el entrenamiento incluiría compras de los mismos días (o posteriores) que el test, el modelo aprendería patrones que en la realidad todavía no conocería. Eso es data leakage.

**2.** Un modelo que siempre dice “no hay contracargo” obtiene 89,6 % de accuracy en test (la proporción de compras sin contracargo) sin detectar ninguno, por eso con clases desbalanceadas la accuracy engaña. Se usa PR-AUC porque mide qué tan bien el modelo ordena el riesgo sin depender del umbral.

**3.** . En 01_manual_logistica quedaron como parámetros la configuración del entrenamiento: 
  - model_type = logistic_regression
  - feature_set = basicas
  - C = 1.0,
  - class_weight = ninguno
  - threshold = 0.5
  - data_table = ml_features y
  - data_version = 1

Como métricas, los resultados sobre test:
- PR-AUC 0,339
- ROC-AUC 0,794
- accuracy 0,896
- precision 0,493
- recall 0,045
- F1 0,082
- 67 alertas
- train_pr_auc 0,341

Como artefactos, la imagen de la matriz de confusion y el modelo serializado con su firma.

Un experimento es el contenedor que agrupa todos los intentos sobre un mismo problema, mientras que un run es una ejecución puntual de entrenamiento dentro de él, con sus propios parámetros, métricas y artefactos.

**4.** Autolog registró 46 parámetros (todos los del Pipeline de scikit-learn), incluidos muchos que no elegimos. No registra lo propio del problema que sí registramos a mano: las métricas sobre test (que son las que estiman el rendimiento real), el PR-AUC, el umbral, la cantidad de alertas ni la versión de los datos (data_version). 

**5.** Sí, 01_repro_a y 01_repro_b dieron métricas idénticas (PR-AUC 0,5099, ROC-AUC 0,8693, recall 0,2068, 212 alertas y la celda devolvió True). Para que un run sea reproducible hay que fijar cuatro cosas: 
- los mismos datos (data_version guarda la versión Delta de ml_features)
- el mismo código (modelo, features e hiperparámetros),
- la misma semilla (random_state = 42, porque el bosque elige filas y columnas al azar)
- el mismo entorno (las versiones de librerías que MLflow guarda en requirements.txt junto al modelo).

**6.** Al llamar al modelo sin la columna amount, MLflow rechazó la predicción con el error Failed to enforce schema of data, sin llegar a ejecutar el modelo. La firma registrada declara que el modelo espera amount (double, obligatoria) y payment_channel (string, obligatoria) y devuelve un entero por fila. Sirve como contrato entre quien entrena y quien usa el modelo.

## Tus experimentos

**7.** Mi mejor run fue gb_completas_u02: 
- gradient boosting con el conjunto completas
- learning_rate = 0.03
- max_depth = 5
- sin class_weight
- umbral 0,2
- con PR-AUC de test 0,583 (empatado con gb_completas y gb_completas_u03, que son el mismo modelo con otro umbral).

Usando sólo rule_alert (lr_solo_regla) el PR-AUC fue 0,170, apenas por encima del de un modelo al azar (0,104), y con umbral 0,5 no generó ninguna alerta. El mejor modelo mejora el PR-AUC en 0,41 puntos, unas 3,4 veces el de la regla sola.

**8.** Con gradient boosting y los mismos hiperparámetros, el PR-AUC pasó de 0,326 con basicas a 0,511 con cliente y a 0,583 con completas: el salto más grande lo dio sumar las variables del cliente. 

En mi mejor run las variables más importantes según la importancia por permutación fueron amount (0,333), payment_channel (0,181), hour (0,133), category (0,082), account_age_days (0,053) y device_customers (0,039); is_night, amount_to_price, price y country quedaron prácticamente en cero.

**9.** Con completas, el mejor fue gradient boosting (PR-AUC 0,583), seguido por el bosque con max_depth = 8 (0,568) y la logística (0,545). El contracargo no depende de una variable sola sino de combinaciones de señales; un modelo de árboles puede separar primero un grupo (por ejemplo, las compras de noche) y dentro de él otro (las hechas por transferencia), asignándole riesgo alto sólo a esa combinación, mientras que la logística le da a cada variable un peso propio y no ve el efecto conjunto.

**10.** Con class_weight = balanced (comparado con gb_completas, mismo modelo y umbral 0,5), la precision bajó de 0,733 a 0,318, el recall subió de 0,345 a 0,804 y la accuracy cayó de 0,919 a 0,801 porque el modelo pasó a generar muchas más alertas. El PR-AUC casi no cambió (0,583 → 0,581) ya que hacer que los contracargos pesen más al entrenar no mejora cómo el modelo ordena el riesgo, sólo cambia cuántas transacciones termina marcando.

**11.** Al bajar el umbral de 0,5 a 0,3 y a 0,2, el recall subió (0,345 → 0,570 → 0,674), la precision bajó (0,733 → 0,545 → 0,457) y con 0,2 el modelo generó 1.093 alertas en test, mientras el PR-AUC se mantuvo en 0,583. 

El PR-AUC no depende del umbral porque resume qué tan bien el modelo ordena las transacciones de más a menos riesgosas; el umbral sólo mueve el punto de trabajo entre precision y recall. El F1, en cambio, es la media armónica de la precision y el recall de un umbral puntual, por eso cambia (0,469 → 0,557 → 0,544).

**12.** Barrí max_depth en un random forest con completas. El mejor PR-AUC de test fue con max_depth = 8 (0,568; train 0,643). Con sin_limite el PR-AUC de train llegó a 1,000 mientras el de test cayó a 0,537 indicando un claro overfitting.

## Comparar y elegir

**13.** No coincidieron: el mejor por PR-AUC fue gb_completas_u02 (PR-AUC 0,583, accuracy 0,883) y el mejor por accuracy fue gb_completas (accuracy 0,919), que es el mismo modelo con umbral 0,5 y por eso tiene el mismo PR-AUC. 

Pueden no coincidir porque la accuracy, (TP + TN) / total, depende del umbral y está dominada por las compras sin contracargo: con pocos contracargos, alertar menos acierta casi siempre, aunque se detecten menos (el recall bajó de 0,674 a 0,345). El PR-AUC, en cambio, no depende del umbral y mide qué tan bien el modelo ordena las transacciones de más a menos riesgosas.

**14.** El run más alejado de la diagonal es el random forest con max_depth = sin_limite (PR-AUC 1,000 en train contra 0,537 en test). Lo siguen, con una brecha mucho menor, los bosques con max_depth = 8 (01_repro_a/b con cliente: 0,594 vs. 0,510, y el de completas: 0,643 vs. 0,568) y los gradient boosting (alrededor de 0,05). Las regresiones logísticas quedan prácticamente sobre la diagonal. 

Estar lejos de la diagonal indica overfitting: el modelo rinde mucho mejor sobre los datos con los que se entrenó que sobre datos nuevos, porque memorizó el entrenamiento en lugar de aprender patrones que se repitan.

**15.** mlflow.search_runs convierte el experimento en una tabla que se puede consultar, filtrar y ordenar desde código como cualquier dato. Entiendo que esto es util para escalar cuando hay muchos runs porque permite automatizar comparaciones y la selección del modelo, en lugar de revisarlos uno por uno en la interfaz. 

Para traer sólo los bosques con PR-AUC de test mayor a 0,55 usaría filter_string="params.model_type = 'random_forest' AND metrics.test_pr_auc > 0.55".

**16.** En mi opinion, en fraude es peor contracargo no detectado. Pero una alerta falsa también tiene costo: alguien tiene que revisarla y se molesta o se pierde a un cliente bueno, por lo que no tiene sentido marcar todo como fraudulento. 

Si el equipo de riesgo sólo puede revisar una cantidad fija de alertas por día, usaría el umbral para ajustarme a esa capacidad: como el modelo ordena las transacciones de más a menos riesgosas, elegiría el umbral que genere aproximadamente esa cantidad de alertas, de modo que se revisen las más riesgosas.

## Registro, uso y monitoreo

**17.** Sí, se registró en Unity Catalog como workspace.bigdata_tfernandezaddoumie.fraud_model, versión 2, con alias champion. Tiene version 2 porque en clase hice 7 u 8 corridas de prueba pero me faltaron algunas combinaciones que iba a necesitar para la entrega, por lo que borré y corrí de 0 todo.

Cargar models:/...@champion tiene la ventaja de que el proceso que usa el modelo pide “el champion” y no un run_id puntual, por lo que para cambiar de modelo alcanza con mover el alias a otra versión, sin tocar el código que lo consume, y el registro mantiene nombre estable, versiones numeradas y el vínculo con el run que generó cada una.

**18.** Se puntuaron 7.165 transacciones nuevas (7 de marzo) y 1.143 generaron alerta (16 %). Las columnas de ml_predictions que permiten auditar cada decisión son model_name, model_version y run_id (qué modelo, qué versión y qué entrenamiento la produjo), threshold (con qué umbral se decidió) y scored_at (cuándo), además de score y alerta. 

El umbral se guarda fuera del modelo porque es una decisión de negocio que puede cambiar sin reentrenar.

**19.** Sí, el desempeño en nuevas fue parecido al de test: 
- PR-AUC 0,568 contra 0,583
- ROC-AUC 0,886 contra 0,887
- precision 0,465 contra 0,457
- recall 0,672 contra 0,674

En la campaña simulada (importe promedio de 989 a 1.218 y transferencias del 33 % al 61 %), el porcentaje de alertas pasó de 16,0 % a 30,5 %, prácticamente el doble. El drift es el cambio en las propiedades estadísticas de los datos a lo largo del tiempo. Se puede detectar antes de tener las etiquetas porque las distribuciones de las variables de entrada y de los scores se pueden vigilar en el momento, mientras que las métricas recién se conocen cuando llegan los contracargos confirmados (como vimos el caso de evitently)

## Cierre

**20.** 
- Datos: armamos ml_features con split temporal.
- Entrenamiento: probamos modelos, variables e hiperparámetros.
- Tracking: cada entrenamiento quedó registrado en MLflow con parámetros, métricas, artefactos y modelo.
- Registro: el mejor modelo quedó en Unity Catalog con versión y alias champion.
- Despliegue: lo usamos en inferencia batch para puntuar las transacciones nuevas y guardar ml_predictions.
- Monitoreo: comparamos sus métricas en producción con las de test y analicé el drif.

Para tenerlo en producción real faltaría, por ejemplo, orquestar el scoring y el reentrenamiento como un job programado, un pipeline de CI/CD que valide y despliegue nuevas versiones automáticamente, y monitoreo continuo con alertas de drift que disparen el reentrenamiento. 

Tambien entiendo que algo muy importante es hablar con el equipo de fraude para ver sus necesidades y capacidad. 
