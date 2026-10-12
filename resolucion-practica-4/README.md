# Resolución práctica 4 — Streaming

- **Nombre:** Tomás Fernández Addoumie
- **student_id:** tfernandezaddoumie
- **Escala:** small

## Log y offsets

**1.** Después de leer tres mensajes, en la cola quedan 2 (`pago_4` y `pago_5`) y en el log siguen los 5, con el offset del consumidor en 3. En una cola leer un mensaje lo borra y lo procesa un solo consumidor; en un log como Kafka los mensajes se retienen y cada consumidor solo avanza su offset, lo que permite que varios lean lo mismo y releer el pasado.

**2.** Tras la llegada 2, `antifraude` leyó 180 mensajes y `reportes` 0. El atraso no afectó a `antifraude`: cada consumidor tiene su propio checkpoint y leer no borra ni bloquea el topic, así que `reportes` solo se atrasó a sí mismo y en la llegada 3 se puso al día leyendo 220 de una vez.

**3.** El offset es la posición de un consumidor en el log, es decir, hasta dónde leyó; acá es la próxima versión de la tabla Delta a leer (6, con el topic en la versión 5). Cada consumidor lo guarda en su propio checkpoint (`checkpoints/antifraude` y `checkpoints/reportes`), no en el topic.

**4.** El replay leyó 280 mensajes, todo el topic. Kappa propone reprocesar con el mismo código de streaming, lanzando una consulta nueva con otro checkpoint que relee el log desde el principio; Lambda, en cambio, mantiene una capa batch y otra de streaming en paralelo, con la misma lógica escrita dos veces.

## Ingesta y enriquecimiento

**5.** Bronze procesó 60, 120, 40, 40 y 20 filas nuevas en las llegadas 1 a 5 (las mismas que tenía cada archivo), y 0 al reejecutar sin archivos nuevos. Lo que evita leer dos veces un archivo es el checkpoint de Auto Loader (`cloudFiles`), que registra qué archivos ya se procesaron y funciona como un offset pero a nivel de archivo.

**6.** Aparecieron dos motivos, ambos en la llegada 2 (`stream_002`): `INVALID_AMOUNT` (20 eventos, por el monto "N/A" de `bad_amount`) y `UNKNOWN_CUSTOMER` (20 eventos, por el `customer_id` inexistente de `bad_customer`). Siguiendo el mismo razonamiento que en la practica 2 sobre batch, Bronze guarda el texto original para no perder datos ni fallar en la ingesta, poder auditar qué llegó y de qué archivo, y reprocesar Silver desde el crudo si cambia una regla o el contrato.

**7.** El join agregó `country` desde `silver_customers` y `category` desde `silver_products`, ya que los eventos llegan solo con `customer_id` y `product_id`. Es un join stream-tabla: cada evento del stream de Bronze se enriquece con tablas de referencia estáticas, y como es un left join, un cliente inexistente no se pierde sino que queda en cuarentena.

## Tiempo y ventanas

**8.** El event time es cuándo ocurrió la compra y el processing time es cuándo llega al sistema. `late_ok` ocurrió a las 12:03 pero recién se procesó en la llegada 2, después de eventos de las 12:04; igual se sumó a la ventana [12:00, 12:05), porque las ventanas se calculan por event time y no por el momento de llegada.

**9.** Al terminar cada llegada el watermark valió 11:54, 11:58, 12:16, 12:17 y 12:35. Se calcula como el máximo event time visto hasta ese momento menos 10 minutos (por ejemplo, en la llegada 3 el máximo fue 12:26, entonces 12:26 − 10 = 12:16), y solo avanza cuando llegan eventos más nuevos.

**10.** Las primeras ventanas tumbling en append aparecen en la llegada 3, cuando el total de emitidas pasa de 0 a 4: son las ventanas [12:00, 12:05) y [12:05, 12:10), cada una para los canales card y wallet, porque la consulta agrupa por ventana y canal. Antes no se emitió ninguna porque el watermark (11:54 y 11:58) todavía no había superado el fin de ninguna ventana; en la llegada 3 los eventos de 12:25–12:26 lo llevaron a 12:16 y esas ventanas se cerraron.

**11.** `late_bad` (12:02) llegó en la llegada 4, cuando el watermark ya estaba en 12:16, así que se descartó: aparecen 20 eventos más viejos que el watermark y no suma en ninguna ventana. `late_ok` (12:03) se aceptó porque llegó en la llegada 2 con el watermark en 11:54, es decir, dentro del margen de 10 minutos.

**12.** Tumbling corta en bloques fijos de 5 minutos sin solaparse, y cada compra cae en una sola ventana (80, 40 y 60 compras), útil para reportar el TPV cada 5 minutos por medio de pago. Hopping usa ventanas de 10 minutos que avanzan cada 5, así que se solapan y cada compra cuenta en dos ventanas (por ejemplo, [12:00, 12:10) suma 120 = 80 + 40), útil para una tasa de aprobación de los últimos 10 minutos actualizada seguido. Session agrupa por cliente y se cierra tras 5 minutos sin compras, con largos distintos (el cliente 0 tiene dos sesiones, de 4 y 3 compras, y el cliente 1 una de 2), útil para analizar sesiones de compra o detectar patrones de fraude dentro de una misma sesión.

**13.** En update, la ventana [12:00, 12:05) de card se emitió dos veces: en la llegada 1 con 40 compras y $6.000, y en la llegada 2, corregida por `late_ok`, con 60 compras y $8.400. En append se emitió una sola vez, en la llegada 3, con el valor final (60 compras y $8.400). Update da resultados antes pero obliga al consumidor a tolerar la misma ventana varias veces; append es más simple y predecible, pero tarda más en emitir.

**14.** Con un watermark de 1 minuto se gana latencia y se usa menos estado: las ventanas se cierran antes (por ejemplo, [12:00, 12:05) se habría emitido en la llegada 2 y no en la 3). Lo que se pierde es completitud: se descartaría todo evento que llegue con más de 1 minuto de atraso respecto del máximo visto, y `late_ok`, que llegó con 1 minuto de atraso, quedaría justo en el límite.

## Garantías y fallas

**15.** Sin deduplicar, el destino terminó con 220 filas, y deduplicando por `event_id` quedaron 200 (los 20 sobrantes son las copias de `e002`). El productor puede enviar un evento dos veces porque trabaja en modo at-least-once: si no recibe la confirmación del envío reintenta ante la duda, y el evento queda repetido en la entrada.

**16.** Al reiniciar con el mismo checkpoint, la consulta no volvió a escribir nada y el destino siguió en 200 filas, porque el checkpoint sabe hasta dónde procesó (comportamiento exactly-once dentro de Spark). Al perder el checkpoint, la consulta empezó de nuevo desde el principio y, como el destino es un append común, escribió todo otra vez y quedaron 400 filas: un comportamiento at-least-once, donde no se pierde nada pero se duplican los resultados.

**17.** Con `MERGE` el resultado quedó en 200 filas aunque se perdiera el checkpoint, porque cada microbatch se escribe con un `MERGE` por `event_id` que solo inserta los eventos que todavía no existen en el destino; al reprocesar, todos ya estaban y no se insertó nada. Que una operación sea idempotente significa que aplicarla una o varias veces deja el mismo resultado.

## CDC

**18.** Se leyeron 13 eventos de cambio: 6 `insert` (los 5 clientes iniciales y el alta del cliente 100), 3 `update_preimage`, 3 `update_postimage` y 1 `delete`. Un `UPDATE` genera dos eventos porque el log guarda la fila antes del cambio (`update_preimage`) y la fila después del cambio (`update_postimage`), así queda registrado qué valor había y cuál quedó.

**19.** Sí: quedándose con el último cambio de cada `customer_id` y descartando los que terminan en `delete`, la tabla reconstruida resultó igual a la original. El log tiene información que la tabla perdió, porque la tabla solo muestra el estado actual: por ejemplo, que el cliente 2 pasó de UY a CL antes de mudarse a BR, o que existió el cliente 3 y fue eliminado.


