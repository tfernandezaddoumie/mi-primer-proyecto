# Resolución Práctica 1 — Ingesta y capa Bronze

- **Nombre:** Tomás Fernández Addoumie
- **Namespace:** workspace.bigdata_tfernandezaddoumie
- **Volumen:**    /Volumes/workspace/bigdata_tfernandezaddoumie/landing
- **Filas:**   {'customers': 100, 'products': 30, 'transactions': 1000, 'events': 3000}

## 1) Formatos

** CSV: transactions y customers
El csv no guarda tipos de dato: trae a todos como string. Cuando activamos el inferschema = true, spark recorre los datos para inferir el tipo y cambia cofrectamente el tipo de dato de los que son integer y timestamp, pero vemos que amount sigue como string. Con el preview de transactions.csv se ve que hay valores N/A. Esto es inestable porque si en el proximo lote no viene ningun N/A y usamos el iferrschema, lo va a detectar numérico. 

Cuando lo ejecuto con inferschema veo 8s de demora en comparacion a 7s, es decir es poco. Pero ahora estamos trabajando con pocos datos, entiendo que en un entorno productivo real esto sí es significativo. 

** JSON: events
El JSON conserva estructuras anidadas, lo vemos en context que es un struct con platform y session_id (semiestructurado). Aca veo que event_ts queda como string y no como timestamp (porque el formato JSON no lo va a permitir nunca).

** Parquet: products
El archivo products se lee con los tipos de dato correctos sin inferir nada. 
Cuando se le pide al final del notebook hacer un select * group by payment_channel, el explain muestra que solo lee esta columna. Es una ventaja de los archivos parquet que con columnares, si fuese csv por ejemplo no podria. 

**3. Delta: 
Cuando pasamos los 4 archivos a delta vemos algunas cosas, por ejemplo en transactions vemos la descripcion con DESCRIBE_DETAIL y los logs con DESCRIBE_HISTORY.


## Las cinco V en este caso

Estamos trabajando para una plataforma ficticia de comercio electrónico que necesita detectar operaciones potencialmente fraudulentas. Entonces:

- **Volumen:** se genera una transacción por cada operación que ocurra en el ecommerce. Por ejemplo imaginemos el marketplace de mercadolibre, son miles de compras por hora.
- **Velocidad:** si el objetivo es detectar operaciones de fraude, la velocidad es clave para actuar al instante. 
- **Variedad:** lo vemos como ejemplo en los tres formatos (CSV, JSON y Parquet), con datos estructurados y semiestructurados
- **Veracidad:** sería grave no detectar operaciones fraudulentas por lo cual necesitamos data certera. Tambien sería grave identificar erroneamente una operación legal como fraudulenta
- **Valor:** mitigar perdidas economicas por fraude.


## Reflexión final desafío

Detectar una evolución de esquema es darse cuenta de que algo cambió. En este caso fue ver que apareció la columna app_version y un tipo de evento nuevo, refund.

Aceptarla técnicamente es lo que hicimos con bronze_events_v2. Es decir logramos que el pipeline absorba el cambio sin romperse. En Bronze guardamos todo lo que llega y todavia no me pregunto si nos va a servir o no.

 Un cambio puede ser técnicamente aceptable y aun así no ser válido para el negocio. Por ejemplo, este evento de tipo refund, es un evento? no sería una transacción que reversa una compra? Tal vez nos sirve para entender el ingreso efectivo de dinero por ventas pero no para analizar fraude. Esa decisión se debería aplicar en Silver o Gold.
