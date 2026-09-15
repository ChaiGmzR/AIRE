# Manejo de Errores y Mensajes en Pantalla

Este documento describe los casos de validacion del sistema de empaque AIRE, el mensaje que recibe el usuario en pantalla y la respuesta esperada del backend cuando aplica.

## Flujo General

1. Al iniciar la app, el foco debe quedar en `Box Id`.
2. Mientras no exista un `Box Id` escaneado, el foco siempre vuelve a `Box Id`.
3. Antes de escanear `Box Id`, el operador puede elegir tipo de flujo y linea.
4. Para `MAIN PCB`, las lineas validas son `M1`, `M2`, `M3`, `M4`.
5. Para `DISPLAY`, las lineas validas son `D1`, `D2`, `D3`.
6. La seleccion de flujo y linea se guarda localmente en `%APPDATA%\IlsanPackingSystem\settings.json`.
7. Al abrir la app se valida la version contra `GET /api/version`.
8. Despues de escanear `Box Id`, el campo queda bloqueado, la app limpia piezas pendientes anteriores de esa caja en backend y el foco pasa a `BarCode`.
9. Mientras la caja esta activa, el foco siempre vuelve a `BarCode` despues de cada scan, error o validacion.
10. `Send` envia directo, sin confirmacion.
11. `Clear Screen` es la unica accion que pide confirmacion.
12. `Delete 1 Item` elimina directo la fila seleccionada, sin confirmacion.
13. Despues de `Send` exitoso o `Clear Screen` confirmado, la pantalla se limpia y el foco vuelve a `Box Id`.

## Indicadores de Estado

| Indicador | Condicion | Texto en pantalla | Color |
|---|---|---|---|
| Scanner | Estado normal del scanner | `Scanner: Normal` | Azul |
| Scanner | Estado de error del scanner | `Scanner: Error` | Rojo |
| Network | El backend responde HTTP 200 en `/api/scans/status` | `Network: Connect` | Azul |
| Network | El backend no responde o hay error de red | `Network: Disconnect` | Rojo |

Nota: `Network` indica comunicacion con el backend. El detalle interno de DB/carpeta compartida se valida en backend con `/health` y `/ready`.

## Captura de Box Id

| Caso | Accion del usuario | Solicitud al backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| App recien abierta | Ninguna | No aplica | Ninguno | Foco en `Box Id` |
| Validacion de version correcta | Abrir app | `GET /api/version` | Ninguno | Foco en `Box Id` |
| Backend sin endpoint de version o version incompatible | Abrir app | `GET /api/version` | `No se pudo validar la version del backend. Actualiza/reinicia el servidor.` o `Version incompatible. App <actual>, requerida <requerida>.` | Foco en `Box Id` |
| Cambio de tipo/linea | Seleccionar `MAIN PCB`/`DISPLAY` y linea antes de escanear caja | No se envia request | Ninguno | Foco vuelve a `Box Id` |
| `Box Id` vacio | Enter en `Box Id` vacio | No se envia request | Ninguno | Foco permanece/vuelve a `Box Id` |
| `Box Id` capturado | Enter despues de capturar `Box Id` | `DELETE /api/scans/box/:boxCode` para descartar pendientes anteriores | Ninguno | `Box Id` se bloquea, inicia lista vacia y foco pasa a `BarCode` |
| `Box Id` capturado tras cerrar/reabrir app | Enter despues de capturar un `Box Id` que tenia piezas pendientes en backend | `DELETE /api/scans/box/:boxCode` | Ninguno | Borra el trabajo anterior, mantiene contador en 0 y foco pasa a `BarCode` |
| `Box Id` con formato invalido | Se intenta registrar un `BarCode` con `Box Id` invalido | `POST /api/scans` | `Formato de Box Id invalido` | Foco vuelve a `BarCode` |

## Selector de Linea

| Tipo | Lineas permitidas | Validacion backend |
|---|---|---|
| `MAIN PCB` | `M1`, `M2`, `M3`, `M4` | Valida ICT en `history_ict` y FCT en `fct_test_results` |
| `DISPLAY` | `D1`, `D2`, `D3` | Valida prueba electrica en `history_prueba_electrica` |

Mientras hay una caja activa, el selector queda bloqueado para evitar mezclar flujos o lineas dentro de la misma caja.

Formato esperado por backend para `Box Id`:

```text
2 a 4 letras mayusculas + 10 a 15 digitos
```

Ejemplo valido:

```text
LGB922609091234
```

## Captura de BarCode

| Caso | Accion del usuario | Respuesta backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| No hay `Box Id` activo | Intentar capturar `BarCode` sin caja bloqueada | No se envia request | Ninguno | Foco vuelve a `Box Id` |
| `BarCode` vacio | Enter/TAB con campo vacio | No se envia request | Ninguno | Foco permanece/vuelve a `BarCode` si la caja esta activa |
| `BarCode` menor a 11 caracteres | Capturar barcode corto | HTTP 400 | `BarCode demasiado corto (minimo 11 caracteres)` | Limpia `BarCode` y foco vuelve a `BarCode` |
| No se puede extraer NP | Capturar barcode con formato no interpretable | HTTP 400 | `No se pudo extraer el numero de parte del BarCode` | Limpia `BarCode` y foco vuelve a `BarCode` |
| Barcode duplicado en la misma caja | Capturar un serial ya escaneado en la caja activa | HTTP 409 | `Este BarCode ya fue escaneado en esta caja` | Limpia `BarCode` y foco vuelve a `BarCode` |
| Barcode valido | Capturar barcode aceptado | HTTP 200 | Ninguno | Agrega fila a `Boxing List`, limpia `BarCode` y foco vuelve a `BarCode` |
| Tipo de produccion invalido | App o cliente externo envia tipo no permitido | HTTP 400 | `Tipo de produccion invalido. Valores permitidos: MAIN PCB, DISPLAY` | Limpia `BarCode` y foco vuelve a `BarCode` |
| Linea invalida para el tipo | App o cliente externo envia `M*` en `DISPLAY` o `D*` en `MAIN PCB` | HTTP 400 | `Linea invalida para <tipo>. Lineas permitidas: <lista>` | Limpia `BarCode` y foco vuelve a `BarCode` |
| Se intenta mezclar linea en una caja | Cliente externo registra otro flujo/linea en la misma caja pendiente | HTTP 409 | `La linea de produccion no coincide. Esperado <tipo linea>, recibido <tipo linea>` | Limpia `BarCode` y foco vuelve a `BarCode` |
| Error de red/API | Backend no responde o request falla | Sin respuesta HTTP valida | `Error de conexion: <detalle>` | Foco vuelve al campo esperado |

## Regla de Numero de Parte

El primer `BarCode` aceptado en una caja define el numero de parte permitido para esa caja. Todos los siguientes barcodes deben tener el mismo NP.

| Caso | Ejemplo | Respuesta backend | Mensaje en pantalla |
|---|---|---|---|
| Primer scan de la caja | `EBR23966209922609070564` | HTTP 200 | Ninguno |
| Siguiente scan con mismo NP | `EBR23966209922609070569` | HTTP 200 | Ninguno |
| Siguiente scan con NP distinto | Esperado `EBR23966209`, recibido `EBR30299355` | HTTP 409 | `Numero de parte distinto. Esperado EBR23966209, recibido EBR30299355` |

## Validacion ICT

La validacion ICT consulta la tabla:

```text
history_ict
```

Campos usados:

| Campo | Uso |
|---|---|
| `barcode` | Serial escaneado |
| `resultado` | Debe ser `OK` |
| `ts` | Fecha/hora del resultado; se usa el registro mas reciente |

| Caso | Respuesta backend | Mensaje en pantalla |
|---|---|---|
| ICT encontrado y `resultado = OK` | Continua validacion | Ninguno |
| No existe registro ICT para el barcode | HTTP 409 | `No se encontro estatus ICT para este BarCode` |
| Ultimo ICT no es `OK` | HTTP 409 | `El estatus ICT debe ser OK. Estatus actual: NG` |

## Validacion FCT

La validacion FCT consulta la tabla:

```text
fct_test_results
```

Campos usados:

| Campo | Uso |
|---|---|
| `serial_number` | Serial escaneado |
| `final_result` | Debe ser `PASS`; el backend lo interpreta como `OK` |
| `end_at`, `start_at`, `file_modified_at`, `created_at` | Orden para tomar el resultado mas reciente |

| Caso | Respuesta backend | Mensaje en pantalla |
|---|---|---|
| FCT encontrado y `final_result = PASS` | Continua y acepta scan | Ninguno |
| No existe registro FCT para el barcode | HTTP 409 | `No se encontro estatus FCT para este BarCode` |
| Ultimo FCT es `FAIL` | HTTP 409 | `El estatus FCT debe ser OK. Estatus actual: FAIL` |
| Ultimo FCT es `UNKNOWN` | HTTP 409 | `El estatus FCT debe ser OK. Estatus actual: UNKNOWN` |

## Validacion Prueba Electrica DISPLAY

La validacion de `DISPLAY` consulta la tabla:

```text
history_prueba_electrica
```

Campos usados:

| Campo | Uso |
|---|---|
| `raw` | Serial escaneado |
| `event_id` | Busqueda alternativa del identificador del evento electrico |
| `lot_no` | Busqueda alternativa del serial escaneado |
| `nparte` | Busqueda alternativa por numero de parte extraido del barcode |
| `display_verificado` | Debe indicar OK/verificado |
| `linea` | Si viene informada, debe coincidir con la linea seleccionada `D1`, `D2` o `D3` |
| `ts` | Fecha/hora del resultado; se usa el registro mas reciente |

Para `DISPLAY`, el backend acepta tanto el barcode completo como los segmentos de un formato compuesto separado por `ñ`. Ejemplo:

```text
I20260910'004'00133ñMAINñEBR76683912ñ1ñ
```

Con ese formato se buscan valores como el raw completo, `I20260910'004'00133` y el numero de parte `EBR76683912` dentro de `history_prueba_electrica`.

| Caso | Respuesta backend | Mensaje en pantalla |
|---|---|---|
| Registro encontrado y `display_verificado = 1` | Acepta scan | Ninguno |
| No existe registro de prueba electrica para el barcode | HTTP 409 | `No se encontro prueba electrica para este BarCode` |
| Registro encontrado pero no verificado | HTTP 409 | `La prueba electrica debe estar OK. Estatus actual: NG` |
| Registro encontrado en otra linea | HTTP 409 | `La linea de prueba electrica no coincide. Esperado D1, recibido D2` |
| Backend remoto sin flujo DISPLAY desplegado | HTTP 409 con error ICT/FCT heredado | `El flujo DISPLAY no esta desplegado en el backend. Actualiza/reinicia el servidor.` |

## Send

`Send` genera el archivo BOX DATA de la caja activa. No pide confirmacion.

| Caso | Solicitud al backend | Respuesta backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| Sin caja activa o sin piezas | No se envia request | No aplica | `Escanee al menos una pieza antes de enviar` | Foco vuelve al campo esperado |
| Caja con piezas | `POST /api/scans/box/:boxCode/send` | HTTP 200 | `Archivo generado: <fileName>` | Limpia pantalla y foco vuelve a `Box Id` |
| Backend no tiene piezas pendientes para esa caja | `POST /api/scans/box/:boxCode/send` | HTTP 400 | `No hay escaneos pendientes para esta caja` | Foco vuelve a `BarCode` |
| `Box Id` invalido | `POST /api/scans/box/:boxCode/send` | HTTP 400 | `Formato de Box Id invalido` | Foco vuelve a `BarCode` |
| Error escribiendo archivo BOX DATA | `POST /api/scans/box/:boxCode/send` | HTTP 500 | `Error al generar el archivo BOX` | Foco vuelve a `BarCode` |
| Error de red/API | `POST /api/scans/box/:boxCode/send` | Sin respuesta HTTP valida | `Error de conexion: <detalle>` | Foco vuelve a `BarCode` |

## Delete 1 Item

`Delete 1 Item` elimina una pieza pendiente de la caja activa antes de `Send`. No pide confirmacion.

| Caso | Accion del usuario | Solicitud al backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| Sin fila seleccionada | Presionar boton deshabilitado | No aplica | Ninguno | Foco vuelve al campo esperado |
| Seleccionar fila | Click en una fila de `Boxing List` | No se envia request | Ninguno | La fila queda resaltada y el foco vuelve a `BarCode` |
| Presionar `Delete 1 Item` con fila seleccionada | Click en boton habilitado | `DELETE /api/scans/box/:boxCode/scan/:barcode` | Ninguno si elimina correctamente | Quita la fila, actualiza contadores y foco vuelve a `BarCode` |
| Backend no tiene piezas para esa caja | Click en boton habilitado, pero backend ya no tiene la caja pendiente | HTTP 200 en backend actualizado o HTTP 404 en backend anterior | Ninguno | Limpia filas locales de esa caja y foco vuelve a `BarCode` |
| Barcode no existe en la caja pendiente | Click en boton habilitado, pero el barcode no esta en backend | HTTP 200 en backend actualizado o HTTP 404 en backend anterior | Ninguno | Quita la fila local seleccionada y foco vuelve a `BarCode` |
| Endpoint no desplegado en backend | El servidor devuelve HTML `Cannot DELETE ...` | HTTP 404 HTML | `El endpoint para eliminar no esta desplegado en el backend. Actualiza/reinicia el servidor.` | Foco vuelve a `BarCode` |
| `Box Id` o `BarCode` invalido | Request de eliminacion con datos invalidos | HTTP 400 | Mensaje de validacion del backend | Foco vuelve a `BarCode` |
| Error interno | Falla el backend al eliminar | HTTP 500 | `Error al eliminar el escaneo` | Foco vuelve a `BarCode` |

## Clear Screen

`Clear Screen` es la unica accion que pide confirmacion cuando hay piezas escaneadas.

| Caso | Solicitud en pantalla | Accion backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| No hay caja ni piezas | Ninguna | No se envia request | Ninguno | Foco vuelve a `Box Id` |
| Caja activa sin filas visibles | Click en `Clear Screen` despues de desincronizacion local | `DELETE /api/scans/box/:boxCode` | Ninguno si limpia correctamente | Limpia pantalla y foco vuelve a `Box Id` |
| Hay piezas escaneadas | Modal `Limpiar pantalla` con texto `Limpiar <N> piezas escaneadas? Esta accion no se puede deshacer.` | Espera decision del usuario | Ninguno | Autofoco se pausa mientras el modal esta abierto |
| Usuario presiona `Cancelar` | Cierra modal | No limpia backend | Ninguno | Foco vuelve a `BarCode` |
| Usuario presiona `Limpiar` | Cierra modal | `DELETE /api/scans/box/:boxCode` | Ninguno | Limpia pantalla y foco vuelve a `Box Id` |
| Error al limpiar backend | `DELETE /api/scans/box/:boxCode` falla | La app muestra error | `Error al limpiar los escaneos pendientes de la caja` | Limpia pantalla local y foco vuelve a `Box Id` |

## Respuestas Backend

### `POST /api/scans`

| Validacion | HTTP | JSON |
|---|---:|---|
| `Box ID` requerido | 400 | `{ "error": "El Box Id es requerido" }` |
| Formato de `Box ID` invalido | 400 | `{ "error": "Formato de Box Id invalido" }` |
| `BarCode` requerido | 400 | `{ "error": "El BarCode es requerido" }` |
| `BarCode` corto | 400 | `{ "error": "BarCode demasiado corto (minimo 11 caracteres)" }` |
| NP no extraible | 400 | `{ "error": "No se pudo extraer el numero de parte del BarCode" }` |
| Tipo de produccion invalido | 400 | `{ "error": "Tipo de produccion invalido. Valores permitidos: MAIN PCB, DISPLAY" }` |
| Linea invalida para el tipo | 400 | `{ "error": "Linea invalida para <tipo>. Lineas permitidas: <lista>" }` |
| Barcode duplicado | 409 | `{ "error": "Este BarCode ya fue escaneado en esta caja" }` |
| Flujo/linea distinta en la misma caja | 409 | `{ "error": "La linea de produccion no coincide. Esperado <tipo linea>, recibido <tipo linea>" }` |
| NP distinto al de la caja | 409 | `{ "error": "Numero de parte distinto. Esperado <expected>, recibido <received>" }` |
| ICT no encontrado | 409 | `{ "error": "No se encontro estatus ICT para este BarCode", "quality": { ... } }` |
| ICT no OK | 409 | `{ "error": "El estatus ICT debe ser OK. Estatus actual: <status>", "quality": { ... } }` |
| FCT no encontrado | 409 | `{ "error": "No se encontro estatus FCT para este BarCode", "quality": { ... } }` |
| FCT no OK | 409 | `{ "error": "El estatus FCT debe ser OK. Estatus actual: <status>", "quality": { ... } }` |
| Prueba electrica DISPLAY no encontrada | 409 | `{ "error": "No se encontro prueba electrica para este BarCode", "quality": { ... } }` |
| Prueba electrica DISPLAY no OK | 409 | `{ "error": "La prueba electrica debe estar OK. Estatus actual: <status>", "quality": { ... } }` |
| Prueba electrica DISPLAY en otra linea | 409 | `{ "error": "La linea de prueba electrica no coincide. Esperado <linea>, recibido <linea>", "quality": { ... } }` |
| Cliente DISPLAY contra backend anterior | 409 | Backend devuelve ICT/FCT, la app lo presenta como `El flujo DISPLAY no esta desplegado en el backend. Actualiza/reinicia el servidor.` |
| Error interno | 500 | `{ "error": "Error al registrar el escaneo", "details": "<detalle>" }` |

### `GET /api/version`

| Validacion | HTTP | JSON |
|---|---:|---|
| Version compatible | 200 | `{ "version": "1.0.0", "requiredClientVersion": "1.0.0", "minimumClientVersion": "1.0.0" }` |
| Endpoint no disponible | 404 | La app muestra `No se pudo validar la version del backend. Actualiza/reinicia el servidor.` |
| Version incompatible | 200 con otra version requerida | La app muestra `Version incompatible. App <actual>, requerida <requerida>.` |

### `POST /api/scans/box/:boxCode/send`

| Validacion | HTTP | JSON |
|---|---:|---|
| `Box ID` invalido | 400 | `{ "error": "Formato de Box Id invalido" }` |
| Sin scans pendientes | 400 | `{ "error": "No hay escaneos pendientes para esta caja" }` |
| Envio exitoso | 200 | `{ "success": true, "boxCode": "<box>", "file": { "name": "<archivo>", "path": "<ruta>", "rows": <n>, "lastScan": "<fecha>" } }` |
| Error interno | 500 | `{ "error": "Error al generar el archivo BOX", "details": "<detalle>" }` |

### `DELETE /api/scans/box/:boxCode/scan/:barcode`

| Validacion | HTTP | JSON |
|---|---:|---|
| `Box ID` invalido | 400 | `{ "error": "Formato de Box Id invalido" }` |
| `BarCode` invalido | 400 | `{ "error": "<mensaje de validacion BarCode>" }` |
| Sin scans pendientes | 200 | `{ "success": true, "alreadyDeleted": true, "boxCode": "<box>", "deleted": null, "currentPartNumber": null, "counts": { "box": 0, "shift": <n> } }` |
| Barcode no encontrado en la caja | 200 | `{ "success": true, "alreadyDeleted": true, "boxCode": "<box>", "deleted": { "serial": "<barcode>", "partNumber": "<np>" }, "currentPartNumber": "<np|null>", "counts": { "box": <n>, "shift": <n> } }` |
| Eliminacion exitosa | 200 | `{ "success": true, "boxCode": "<box>", "deleted": { "serial": "<barcode>", "partNumber": "<np>" }, "currentPartNumber": "<np|null>", "counts": { "box": <n>, "shift": <n> } }` |
| Error interno | 500 | `{ "error": "Error al eliminar el escaneo", "details": "<detalle>" }` |

### `GET /api/scans/status`

| Caso | HTTP | Efecto en pantalla |
|---|---:|---|
| Backend responde | 200 | `Network: Connect` |
| Backend no responde | Error de conexion | `Network: Disconnect` |

## Pruebas Manuales Sugeridas

### Verificar conectividad

```powershell
Invoke-WebRequest http://192.168.1.10:3001/health -UseBasicParsing
Invoke-WebRequest http://192.168.1.10:3001/ready -UseBasicParsing
Invoke-WebRequest http://192.168.1.10:3001/api/scans/status -UseBasicParsing
```

Resultado esperado:

```text
ready: true
database.connected: true
share.connected: true
```

### Probar rechazo por NP distinto

1. Escanear `Box Id` valido.
2. Escanear un `BarCode` con ICT OK y FCT PASS.
3. Escanear otro `BarCode` con diferente NP.
4. La app debe mostrar:

```text
Numero de parte distinto. Esperado <expected>, recibido <received>
```

### Probar rechazo por ICT/FCT

1. Escanear `Box Id` valido.
2. Escanear un barcode cuyo ultimo ICT no sea `OK` o cuyo ultimo FCT no sea `PASS`.
3. La app debe mostrar uno de estos mensajes:

```text
No se encontro estatus ICT para este BarCode
El estatus ICT debe ser OK. Estatus actual: NG
No se encontro estatus FCT para este BarCode
El estatus FCT debe ser OK. Estatus actual: FAIL
```

### Probar flujo DISPLAY

1. Seleccionar `DISPLAY`.
2. Seleccionar linea `D1`, `D2` o `D3`.
3. Escanear `Box Id` valido.
4. Escanear un barcode existente en `history_prueba_electrica` con `display_verificado = 1`.
5. La app debe aceptar el scan sin consultar ICT/FCT.
6. Probar tambien el formato compuesto `I20260910'004'00133ñMAINñEBR76683912ñ1ñ`; el backend debe buscarlo en `raw`, `event_id`, `lot_no` y `nparte`.
7. Escanear un barcode inexistente en `history_prueba_electrica`.
8. La app debe mostrar:

```text
No se encontro prueba electrica para este BarCode
```

### Probar selector MAIN PCB

1. Seleccionar `MAIN PCB`.
2. Confirmar que las lineas disponibles son `M1`, `M2`, `M3`, `M4`.
3. Escanear una pieza valida de MAIN PCB.
4. La app debe mantener la validacion actual de ICT y FCT.

### Probar Send sin confirmacion

1. Escanear `Box Id`.
2. Escanear uno o mas barcodes validos.
3. Presionar `Send`.
4. No debe aparecer modal de confirmacion.
5. Si el envio es exitoso, debe mostrarse:

```text
Archivo generado: <fileName>
```

### Probar Delete 1 Item

1. Escanear `Box Id`.
2. Escanear dos o mas barcodes validos.
3. Seleccionar una fila en `Boxing List`.
4. Confirmar que `Delete 1 Item` se habilita.
5. Presionar `Delete 1 Item`.
6. La fila seleccionada debe desaparecer y el contador de caja debe bajar en 1.
7. El foco debe volver a `BarCode`.

### Probar Clear Screen con confirmacion

1. Escanear `Box Id`.
2. Escanear uno o mas barcodes validos.
3. Presionar `Clear Screen`.
4. Debe aparecer el modal:

```text
Limpiar <N> piezas escaneadas? Esta accion no se puede deshacer.
```

5. `Cancelar` conserva la caja actual y regresa foco a `BarCode`.
6. `Limpiar` limpia la pantalla y regresa foco a `Box Id`.
