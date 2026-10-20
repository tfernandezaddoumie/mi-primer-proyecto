# Resolucion práctica 3 — Bases de datos NoSQL

- **Nombre:** Tomas Fernandez Addoumie
- **student_id:** tfernandezaddoumie
- **Escala:** small

## CAP y PACELC

**1.** En modo CP, la réplica C, (aislada de A y B) no pudo responder. La lectura devolvió ERROR: no disponible y la escritura saldo=50 dio ERROR: sin quórum. 

CP sacrifica disponibilidad. En modo AP, C respondió saldo = 100 aunque del otro lado ya se había escrito 80, y además aceptó la escritura de 50. AP sacrifica consistencia.

**2.** Después de la reparación, las tres réplicas quedaron con saldo = 50. Se perdió la escritura saldo = 80, que se había hecho por A durante la partición. Al reconciliar con last-write-wins ganó la versión más nueva, la de 50 escrita en C, y pisó la de 80.

**3.** Con W=1 la p99 fue 9,6 ms y con W=3, 55,6 ms. A cambio de esperar a las tres réplicas se gana consistencia: la escritura queda confirmada en todas, así que cualquier lectura posterior ve el valor nuevo.

Aca se ve el PACELC: en operación normal hay un trade-off de latencia vs. consistencia.

**4.** Pudo seguir escribiendo el lado ABC, porque tiene 3 replicas y cumple con el quorum. El lado DE, con solo 2 réplicas, no tiene quórum y por eso la escritura por D dio ERROR y la lectura por E también dio ERROR.

## Clave-valor

**5.** El GET en memoria tardó unos 0,0002 ms contra unos 774 ms por consulta, lo que es unas 3,6 millones de veces más rápido que el GET con Spark. Redis guarda los datos en memoria porque su trabajo es encontrar un valor por clave en microsegundos. La RAM es órdenes de magnitud más rápida que leer archivos en disco, y una tabla hash en memoria va directo a la posición de la clave. 

**6.** Porque el país está dentro del valor, que para el almacén clave-valor es un JSON opaco ya que la base solo conoce la clave. Esto implica que para encontrar los 992 clientes de AR hubo que parsear los 5.000 valores. La ventaja del modelo es el acceso por clave directo y rapidísimo (O(1)), que además se reparte fácil entre nodos. La desventaja es que no se puede consultar por el contenido del valor sin recorrer todo.

**7.** Al pasar de 4 a 5 nodos, con hash mod N se movió el 79,6% de las claves y con hashing consistente el 21,2%.

Conviene el hashing consistente porque al agregar un nodo solo se mueven las claves del tramo del anillo que ocupa el nodo nuevo, cerca de 1/(N+1). Con mod N cambia el destino de casi todas las claves, y eso es mover casi todo el dato por la red.

## Documental

**8.** La consulta relacional del cliente 42 devolvió 11 filas (una por transacción, con los datos del cliente repetidos en cada una) y la documental devolvió 1 documento. Dentro del documento quedaron embebidos:
- el perfil (country, segment, created_date, email);
- las estadísticas (tx_count, total_amount, fraud_transactions);
- el array de transacciones (fecha, id, monto, canal, dispositivo, is_fraud), donde cada una lleva además una copia del producto (product_id, category, price).

**9.** Spark armó un esquema que es la unión de todos los campos de los cuatro documentos (loyalty, phones, preferences, profile, schema_version) y completó con null los que faltaban en cada uno.

El modelo tiene esquema flexible porque los documentos de una misma colección no necesitan tener los mismos campos ya que la estructura no se define antes de escribir.

**10.** El documento más grande pesa 5,2 KB, a unos 225 bytes por transacción. El problema de un documento que crece sin límite es que choca con el tope de 16 MB de MongoDB: a ese ritmo, un cliente llegaría con unas 74.599 transacciones. Además, cada lectura o actualización del documento arrastra todo el historial embebido, aunque solo necesites el perfil. Por eso las listas que crecen indefinidamente conviene referenciarlas en lugar de embeberlas.

**11.** El modelo documental resuelve bien las consultas por entidad: todo lo que se pregunta sobre un cliente y su historial se responde dentro de su documento, sin joins. Le cuestan más las consultas transversales, que agregan a través de muchos documentos, como el monto por categoría: hay que desarmar los arrays con explode y volver a trabajar con filas, que es lo que el relacional o el columnar hacen naturalmente.

## Grafos

**12.** El grafo tiene 5.000 nodos Customer (738 marcados), 2.361 nodos Device y 5.400 aristas USES.

**13.** El SQL necesitó 3 joins para el patrón de 2 saltos y 5 joins para el de 4: cada flecha del patrón agrega un join contra la tabla de aristas. Neo4j recorre relaciones más eficientemente gracias a la index-free adjacency. 

**14.** La propagación de etiquetas convergió en la iteración 14. El componente más grande tiene 23 nodos (c:122).

**15.** Al repartir los nodos con hash(id) mod 4, el 74,4% de las aristas quedó entre máquinas distintas, contra 0% al repartir por componente. Es difícil distribuir una base de grafos porque su valor está en las relaciones: cada arista cuyos extremos quedan en máquinas distintas obliga a un salto por la red. Agrupar por componente deja todas las aristas dentro de cada máquina.

## Vectorial

**16.** El vector de cada cliente resume su comportamiento en 10 números:

5 son la proporción de su gasto en cada categoría (electronics, home, books, sports, fashion)
3 son la proporción de sus pagos por canal (card, wallet, transfer)
2 son su ticket promedio (dividido por 2.000) y la proporción de compras de más de 1.500

La similitud coseno mide qué tan parecida es la dirección de dos vectores (1 = misma dirección), es decir qué tan parecido es el comportamiento de dos clientes.

**17.** Entre los 10 vecinos de los clientes marcados hay un 31,6% de marcados, contra una tasa base de 14,8% (y 13,2% entre los vecinos de no marcados). Buscar “vecinos parecidos” sirve para encontrar, dado un cliente marcado, otros clientes que se comportan parecido, y para clasificar a un cliente según sus vecinos.

**18.** Con nprobe=4 se obtiene un recall de 0,872 escaneando el 5,985% de los vectores. La búsqueda aproximada (ANN) gana velocidad, porque compara contra una fracción de los vectores en vez de contra todos como el k-NN exacto. Pierde exactitud porque puede no encontrar algunos de los vecinos verdaderos.

## Columnar

**19.** Los datos ocupan 50,0 MB en CSV, 121,1 MB en JSON y 5,3 MB en Parquet. Para la consulta de amount sobre Parquet, Spark leyó solo la columna amount. Con los datos ordenados por amount se pueden saltear 7 de 8 archivos, contra 0 de 8 escritos al azar.

**20.** El formato columnar es bueno para analítica porque permite:

- leer solo las columnas que pide la consulta
- comprimir mejor, porque guarda juntos valores del mismo tipo
- saltear bloques enteros usando estadísticas min/max

Es poco conveniente para modificar una fila por vez porque los valores de esa fila no están juntos: quedan repartidos entre los bloques de cada columna. En cambio, el formato orientado a filas, el de las bases OLTP, guarda cada fila completa en un solo lugar.
