# Manejo de Errores y Mensajes en Pantalla

Este documento describe los casos de validacion del sistema de empaque AIRE, el mensaje que recibe el usuario en pantalla y la respuesta esperada del backend cuando aplica.

## Flujo General

1. Al iniciar la app, el foco debe quedar en `Box Id`.
2. Mientras no exista un `Box Id` escaneado, el foco siempre vuelve a `Box Id`.
3. Despues de escanear `Box Id`, el campo queda bloqueado y el foco pasa a `BarCode`.
4. Mientras la caja esta activa, el foco siempre vuelve a `BarCode` despues de cada scan, error o validacion.
5. `Send` envia directo, sin confirmacion.
6. `Clear Screen` es la unica accion que pide confirmacion.
7. `Delete 1 Item` elimina directo la fila seleccionada, sin confirmacion.
8. Despues de `Send` exitoso o `Clear Screen` confirmado, la pantalla se limpia y el foco vuelve a `Box Id`.

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
| `Box Id` vacio | Enter en `Box Id` vacio | No se envia request | Ninguno | Foco permanece/vuelve a `Box Id` |
| `Box Id` capturado | Enter despues de capturar `Box Id` | No se valida aun contra backend | Ninguno | `Box Id` se bloquea y foco pasa a `BarCode` |
| `Box Id` con formato invalido | Se intenta registrar un `BarCode` con `Box Id` invalido | `POST /api/scans` | `Invalid Box ID format` | Foco vuelve a `BarCode` |

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
| `BarCode` menor a 11 caracteres | Capturar barcode corto | HTTP 400 | `BarCode too short (minimum 11 characters)` | Limpia `BarCode` y foco vuelve a `BarCode` |
| No se puede extraer NP | Capturar barcode con formato no interpretable | HTTP 400 | `Could not extract part number from BarCode` | Limpia `BarCode` y foco vuelve a `BarCode` |
| Barcode duplicado en la misma caja | Capturar un serial ya escaneado en la caja activa | HTTP 409 | `Barcode already scanned in this box` | Limpia `BarCode` y foco vuelve a `BarCode` |
| Barcode valido | Capturar barcode aceptado | HTTP 200 | Ninguno | Agrega fila a `Boxing List`, limpia `BarCode` y foco vuelve a `BarCode` |
| Error de red/API | Backend no responde o request falla | Sin respuesta HTTP valida | `Connection error: <detalle>` | Foco vuelve al campo esperado |

## Regla de Numero de Parte

El primer `BarCode` aceptado en una caja define el numero de parte permitido para esa caja. Todos los siguientes barcodes deben tener el mismo NP.

| Caso | Ejemplo | Respuesta backend | Mensaje en pantalla |
|---|---|---|---|
| Primer scan de la caja | `EBR23966209922609070564` | HTTP 200 | Ninguno |
| Siguiente scan con mismo NP | `EBR23966209922609070569` | HTTP 200 | Ninguno |
| Siguiente scan con NP distinto | Esperado `EBR23966209`, recibido `EBR30299355` | HTTP 409 | `Part number mismatch. Expected EBR23966209, got EBR30299355` |

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
| No existe registro ICT para el barcode | HTTP 409 | `ICT status not found for this barcode` |
| Ultimo ICT no es `OK` | HTTP 409 | `ICT status must be OK. Current status: NG` |

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
| No existe registro FCT para el barcode | HTTP 409 | `FCT status not found for this barcode` |
| Ultimo FCT es `FAIL` | HTTP 409 | `FCT status must be OK. Current status: FAIL` |
| Ultimo FCT es `UNKNOWN` | HTTP 409 | `FCT status must be OK. Current status: UNKNOWN` |

## Send

`Send` genera el archivo BOX DATA de la caja activa. No pide confirmacion.

| Caso | Solicitud al backend | Respuesta backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| Sin caja activa o sin piezas | No se envia request | No aplica | `Please scan at least one piece before sending` | Foco vuelve al campo esperado |
| Caja con piezas | `POST /api/scans/box/:boxCode/send` | HTTP 200 | `Generated <fileName>` | Limpia pantalla y foco vuelve a `Box Id` |
| Backend no tiene piezas pendientes para esa caja | `POST /api/scans/box/:boxCode/send` | HTTP 400 | `No pending scans for this box` | Foco vuelve a `BarCode` |
| `Box Id` invalido | `POST /api/scans/box/:boxCode/send` | HTTP 400 | `Invalid Box ID format` | Foco vuelve a `BarCode` |
| Error escribiendo archivo BOX DATA | `POST /api/scans/box/:boxCode/send` | HTTP 500 | `Failed to send box file` | Foco vuelve a `BarCode` |
| Error de red/API | `POST /api/scans/box/:boxCode/send` | Sin respuesta HTTP valida | `Connection error: <detalle>` | Foco vuelve a `BarCode` |

## Delete 1 Item

`Delete 1 Item` elimina una pieza pendiente de la caja activa antes de `Send`. No pide confirmacion.

| Caso | Accion del usuario | Solicitud al backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| Sin fila seleccionada | Presionar boton deshabilitado | No aplica | Ninguno | Foco vuelve al campo esperado |
| Seleccionar fila | Click en una fila de `Boxing List` | No se envia request | Ninguno | La fila queda resaltada y el foco vuelve a `BarCode` |
| Presionar `Delete 1 Item` con fila seleccionada | Click en boton habilitado | `DELETE /api/scans/box/:boxCode/scan/:barcode` | Ninguno si elimina correctamente | Quita la fila, actualiza contadores y foco vuelve a `BarCode` |
| Backend no tiene piezas para esa caja | Click en boton habilitado, pero backend ya no tiene la caja pendiente | HTTP 404 | `No pending scans for this box` | Foco vuelve a `BarCode` |
| Barcode no existe en la caja pendiente | Click en boton habilitado, pero el barcode no esta en backend | HTTP 404 | `Barcode not found in this box` | Foco vuelve a `BarCode` |
| `Box Id` o `BarCode` invalido | Request de eliminacion con datos invalidos | HTTP 400 | Mensaje de validacion del backend | Foco vuelve a `BarCode` |
| Error interno | Falla el backend al eliminar | HTTP 500 | `Failed to delete scan` | Foco vuelve a `BarCode` |

## Clear Screen

`Clear Screen` es la unica accion que pide confirmacion cuando hay piezas escaneadas.

| Caso | Solicitud en pantalla | Accion backend | Mensaje en pantalla | Comportamiento de foco |
|---|---|---|---|---|
| No hay caja ni piezas | Ninguna | No se envia request | Ninguno | Foco vuelve a `Box Id` |
| Hay piezas escaneadas | Modal `Clear Screen` con texto `Clear <N> scanned pieces? This action cannot be undone.` | Espera decision del usuario | Ninguno | Autofoco se pausa mientras el modal esta abierto |
| Usuario presiona `Cancel` | Cierra modal | No limpia backend | Ninguno | Foco vuelve a `BarCode` |
| Usuario presiona `Clear` | Cierra modal | `DELETE /api/scans/box/:boxCode` | Ninguno | Limpia pantalla y foco vuelve a `Box Id` |
| Error al limpiar backend | `DELETE /api/scans/box/:boxCode` falla | La app no muestra error actualmente | Ninguno | Limpia pantalla local y foco vuelve a `Box Id` |

## Respuestas Backend

### `POST /api/scans`

| Validacion | HTTP | JSON |
|---|---:|---|
| `Box ID` requerido | 400 | `{ "error": "Box ID is required" }` |
| Formato de `Box ID` invalido | 400 | `{ "error": "Invalid Box ID format" }` |
| `BarCode` requerido | 400 | `{ "error": "BarCode is required" }` |
| `BarCode` corto | 400 | `{ "error": "BarCode too short (minimum 11 characters)" }` |
| NP no extraible | 400 | `{ "error": "Could not extract part number from BarCode" }` |
| Barcode duplicado | 409 | `{ "error": "Barcode already scanned in this box" }` |
| NP distinto al de la caja | 409 | `{ "error": "Part number mismatch. Expected <expected>, got <received>" }` |
| ICT no encontrado | 409 | `{ "error": "ICT status not found for this barcode", "quality": { ... } }` |
| ICT no OK | 409 | `{ "error": "ICT status must be OK. Current status: <status>", "quality": { ... } }` |
| FCT no encontrado | 409 | `{ "error": "FCT status not found for this barcode", "quality": { ... } }` |
| FCT no OK | 409 | `{ "error": "FCT status must be OK. Current status: <status>", "quality": { ... } }` |
| Error interno | 500 | `{ "error": "Failed to register scan", "details": "<detalle>" }` |

### `POST /api/scans/box/:boxCode/send`

| Validacion | HTTP | JSON |
|---|---:|---|
| `Box ID` invalido | 400 | `{ "error": "Invalid Box ID format" }` |
| Sin scans pendientes | 400 | `{ "error": "No pending scans for this box" }` |
| Envio exitoso | 200 | `{ "success": true, "boxCode": "<box>", "file": { "name": "<archivo>", "path": "<ruta>", "rows": <n>, "lastScan": "<fecha>" } }` |
| Error interno | 500 | `{ "error": "Failed to send box file", "details": "<detalle>" }` |

### `DELETE /api/scans/box/:boxCode/scan/:barcode`

| Validacion | HTTP | JSON |
|---|---:|---|
| `Box ID` invalido | 400 | `{ "error": "Invalid Box ID format" }` |
| `BarCode` invalido | 400 | `{ "error": "<mensaje de validacion BarCode>" }` |
| Sin scans pendientes | 404 | `{ "error": "No pending scans for this box" }` |
| Barcode no encontrado en la caja | 404 | `{ "error": "Barcode not found in this box" }` |
| Eliminacion exitosa | 200 | `{ "success": true, "boxCode": "<box>", "deleted": { "serial": "<barcode>", "partNumber": "<np>" }, "currentPartNumber": "<np|null>", "counts": { "box": <n>, "shift": <n> } }` |
| Error interno | 500 | `{ "error": "Failed to delete scan", "details": "<detalle>" }` |

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
Part number mismatch. Expected <expected>, got <received>
```

### Probar rechazo por ICT/FCT

1. Escanear `Box Id` valido.
2. Escanear un barcode cuyo ultimo ICT no sea `OK` o cuyo ultimo FCT no sea `PASS`.
3. La app debe mostrar uno de estos mensajes:

```text
ICT status not found for this barcode
ICT status must be OK. Current status: NG
FCT status not found for this barcode
FCT status must be OK. Current status: FAIL
```

### Probar Send sin confirmacion

1. Escanear `Box Id`.
2. Escanear uno o mas barcodes validos.
3. Presionar `Send`.
4. No debe aparecer modal de confirmacion.
5. Si el envio es exitoso, debe mostrarse:

```text
Generated <fileName>
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
Clear <N> scanned pieces? This action cannot be undone.
```

5. `Cancel` conserva la caja actual y regresa foco a `BarCode`.
6. `Clear` limpia la pantalla y regresa foco a `Box Id`.
