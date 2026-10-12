# Entrega práctica 4 — Streaming

- **Nombre:** Tomás Fernández Addoumie
- **student_id:** tfernandezaddoumie
- **Escala:** small

Respondé cada pregunta en una a tres oraciones. Cuando se pide un dato, copiá el valor que te dio el notebook.

## Log y offsets

**1.** Después de leer tres mensajes, en la cola quedan 2 (`pago_4` y `pago_5`) y en el log siguen los 5, con el offset del consumidor en 3. En una cola leer un mensaje lo borra y lo procesa un solo consumidor; en un log como Kafka los mensajes se retienen y cada consumidor solo avanza su offset, lo que permite que varios lean lo mismo y releer el pasado.

**2.** Tras la llegada 2, `antifraude` leyó 180 mensajes y `reportes` 0. El atraso no afectó a `antifraude`: cada consumidor tiene su propio checkpoint y leer no borra ni bloquea el topic, así que `reportes` solo se atrasó a sí mismo y en la llegada 3 se puso al día leyendo 220 de una vez.

**3.** El offset es la posición de un consumidor en el log, es decir, hasta dónde leyó; acá es la próxima versión de la tabla Delta a leer (6, con el topic en la versión 5). Cada consumidor lo guarda en su propio checkpoint (`checkpoints/antifraude` y `checkpoints/reportes`), no en el topic.

**4.** El replay leyó 280 mensajes, todo el topic. Kappa propone reprocesar con el mismo código de streaming, lanzando una consulta nueva con otro checkpoint que relee el log desde el principio; Lambda, en cambio, mantiene una capa batch y otra de streaming en paralelo, con la misma lógica escrita dos veces.

## Ingesta y enriquecimiento

**5.**

**6.**

**7.**

## Tiempo y ventanas

**8.**

**9.**

**10.**

**11.**

**12.**

**13.**

**14.**

## Garantías y fallas

**15.**

**16.**

**17.**

## CDC

**18.**

**19.**

## Cierre

**20.**
