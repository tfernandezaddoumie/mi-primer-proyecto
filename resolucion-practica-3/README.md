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

**12.**

**13.**

**14.**

**15.**

## Vectorial

**16.**

**17.**

**18.**

## Columnar

**19.**

**20.**
