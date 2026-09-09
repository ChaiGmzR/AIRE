# 📊 Simulación Gráfica - Tabla MySQL `box_scans`

## 📋 Estructura Real de la Tabla MySQL

```
+-------------+---------------------------+------+-----+-------------------+-----------------------------+
| Field       | Type                      | Null | Key | Default           | Extra                       |
+-------------+---------------------------+------+-----+-------------------+-----------------------------+
| id          | bigint unsigned           | NO   | PRI | NULL              | auto_increment              |
| serial      | varchar(64)               | NO   | MUL | NULL              |                             |
| box_code    | varchar(64)               | NO   | MUL | NULL              |                             |
| first_scan  | datetime                  | NO   |     | NULL              |                             |
| last_scan   | datetime                  | NO   | MUL | NULL              |                             |
| source_file | varchar(255)              | NO   |     | NULL              |                             |
| folder_date | date                      | NO   | MUL | NULL              |                             |
| status      | enum('Unico','Duplicado') | NO   |     | Unico             |                             |
| lot_no      | varchar(64)               | YES  | MUL | NULL              |                             |
| created_at  | timestamp                 | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED           |
+-------------+---------------------------+------+-----+-------------------+-----------------------------+
```

### Índices (MUL):
- `serial`, `box_code`, `last_scan`, `folder_date`, `lot_no`

---

## 🎯 Datos de Ejemplo (Ficticios con Formato Real)

**Box ID (Código de Caja):** `LGB922602035972`

**Código de Barras (Serial de Pieza):**
1. `EBR80757422922602040001`

> ⚠️ **IMPORTANTE:** El BoxID NO se captura como serial. El BoxID identifica la caja y se almacena en la columna `box_code`. Solo los códigos de barras de las piezas se registran en la columna `serial`.

---

## 📊 TABLA MYSQL - Estado Después de Captura

**Nota sobre timestamps:**
- `first_scan`, `last_scan` = Hora del equipo donde corre el **backend Node.js** (`new Date()` en JavaScript)
- `created_at` = Hora del **servidor MySQL** (`CURRENT_TIMESTAMP`)

Si backend y MySQL están en el mismo equipo, las horas coincidirán.

```
mysql> SELECT * FROM box_scans WHERE box_code = 'LGB922602035972';

+----+---------------------------+------------------+---------------------+---------------------+--------------------+-------------+--------+--------+---------------------+
| id | serial                    | box_code         | first_scan          | last_scan           | source_file        | folder_date | status | lot_no | created_at          |
+----+---------------------------+------------------+---------------------+---------------------+--------------------+-------------+--------+--------+---------------------+
|  1 | EBR80757422922602040001   | LGB922602035972  | [HORA_BACKEND]      | [HORA_BACKEND]      | IlsanPackingSystem | 2026-02-04  | Unico  | NULL   | [HORA_MYSQL]        |
+----+---------------------------+------------------+---------------------+---------------------+--------------------+-------------+--------+--------+---------------------+

1 row in set (0.02 sec)
```

---

## 🔍 Detalle de Cada Columna por Fila

### Fila 1: Captura de Pieza (`EBR80757422922602040001`)

| Campo | Valor | Origen |
|-------|-------|--------|
| `id` | 1 | AUTO_INCREMENT por MySQL |
| `serial` | `EBR80757422922602040001` | Código de barras de la **pieza** (parámetro `barcode`) |
| `box_code` | `LGB922602035972` | Código de la **caja** (parámetro `boxCode`) |
| `first_scan` | `[HORA_BACKEND]` | `formatDateTime(new Date())` en backend Node.js |
| `last_scan` | `[HORA_BACKEND]` | `formatDateTime(new Date())` en backend Node.js |
| `source_file` | `IlsanPackingSystem` | Valor fijo en código (línea 31 de scans.js) |
| `folder_date` | `2026-02-04` | `getCurrentDateStr(now)` en backend |
| `status` | `Unico` | Valor DEFAULT de MySQL (no se envía en INSERT) |
| `lot_no` | `NULL` | No se envía en INSERT, lógica pendiente |
| `created_at` | `[HORA_MYSQL]` | CURRENT_TIMESTAMP del servidor MySQL |

> **Nota:** El BoxID (`LGB922602035972`) NO genera una fila. Solo identifica en qué caja se está empacando la pieza.

---

## 💾 SQL INSERT Ejecutado por el Backend

El código en `backend/routes/scans.js` (líneas 34-41) ejecuta:

```sql
INSERT INTO box_scans (serial, box_code, first_scan, last_scan, source_file, folder_date)
VALUES (?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
  last_scan = GREATEST(box_scans.last_scan, VALUES(last_scan)),
  source_file = VALUES(source_file),
  folder_date = COALESCE(box_scans.folder_date, VALUES(folder_date))
```

### Valores para la Captura:
```sql
INSERT INTO box_scans (serial, box_code, first_scan, last_scan, source_file, folder_date)
VALUES ('EBR80757422922602040001', 'LGB922602035972', '[HORA_BACKEND]', '[HORA_BACKEND]', 'IlsanPackingSystem', '2026-02-04')
```

**Donde:**
- `serial` = Código de barras de la **pieza** (lo que se escanea)
- `box_code` = Código de la **caja** (el BoxID ingresado al inicio)

> ⚠️ El BoxID NO se inserta como serial. Solo se usa para identificar la caja en `box_code`.

---

## 📤 Request/Response API

### POST Request (Captura de Pieza)
```json
POST /api/scans
Content-Type: application/json

{
  "boxCode": "LGB922602035972",
  "barcode": "EBR80757422922602040001"
}
```

**Donde:**
- `boxCode` = Código de la **caja** (ingresado al inicio, campo bloqueado)
- `barcode` = Código de barras de la **pieza** (lo que se escanea)

### POST Response
```json
{
  "success": true,
  "scan": {
    "serial": "EBR80757422922602040001",
    "boxCode": "LGB922602035972",
    "partNumber": "EBR8075742",
    "scanTime": "[HORA_BACKEND]"
  },
  "counts": {
    "box": 1,
    "shift": 1
  }
}
```

---

## 🎨 Visualización en Frontend (Boxing List Table)

La tabla en la app Flutter muestra:

```
╔════╦═══════════════════════╦═════════════════════════╦═════════════════════════╗
║ No ║ Box Id                ║ BarCode                 ║ Read Time               ║
╠════╬═══════════════════════╬═════════════════════════╬═════════════════════════╣
║ 1  ║ LGB922602035972       ║ EBR80757422922602040001 ║ [HORA_BACKEND]          ║
╚════╩═══════════════════════╩═════════════════════════╩═════════════════════════╝
```

**Notas:**
- La tabla solo muestra 4 columnas: `No`, `Box Id`, `BarCode`, `Read Time`
- El BoxID aparece en cada fila como referencia, pero NO se captura como serial
- Solo se muestran las piezas escaneadas, no el BoxID como registro separado

---

## 📊 Columnas NO Utilizadas Actualmente por el Backend

| Columna | Estado | Motivo |
|---------|--------|--------|
| `status` | Usa DEFAULT `Unico` | Lógica de duplicados pendiente de definir |
| `lot_no` | Siempre `NULL` | Lógica de lotes pendiente de definir |

---

## 🔐 Comportamiento UPSERT

Si se escanea el mismo `serial` dos veces:

1. **Primera vez**: INSERT normal
2. **Segunda vez**: UPDATE solo de `last_scan`, `source_file`, `folder_date`

```sql
ON DUPLICATE KEY UPDATE
  last_scan = GREATEST(box_scans.last_scan, VALUES(last_scan)),
  source_file = VALUES(source_file),
  folder_date = COALESCE(box_scans.folder_date, VALUES(folder_date))
```

---

## 📈 Extracción de Part Number

El backend extrae el Part Number de los primeros 11 caracteres del barcode de la **pieza**:

| Barcode (Serial de Pieza) | Part Number Extraído |
|---------------------------|---------------------|
| `EBR80757422922602040001` | `EBR8075742` |

> **Nota:** El BoxID (`LGB922602035972`) NO se procesa para extraer Part Number porque no es un serial de pieza.

Código en `backend/utils/partNumber.js` línea 32:
```javascript
if (trimmed.length >= 11) {
    return trimmed.substring(0, 11);
}
```

---

## ✅ Resumen

| Aspecto | Valor |
|---------|-------|
| Total de filas insertadas | 1 |
| Box ID (código de caja) | `LGB922602035972` |
| Serial capturado (código de pieza) | `EBR80757422922602040001` |
| Status | `Unico` (default) |
| lot_no | `NULL` |
| source_file | `IlsanPackingSystem` |
| folder_date | `2026-02-04` |

---

## 📌 Aclaraciones Importantes

### Diferencia entre BoxID y Serial:
- **BoxID** (`LGB922602035972`): Identifica la **caja**. Se almacena en `box_code`. NO genera una fila en la tabla.
- **Serial** (`EBR80757422922602040001`): Identifica la **pieza**. Se almacena en `serial`. Cada pieza genera una fila.

### Origen de los Timestamps:
- `first_scan`, `last_scan`: Hora del equipo donde corre el **backend Node.js** (`new Date()` en JavaScript)
- `created_at`: Hora del **servidor MySQL** (`CURRENT_TIMESTAMP`)
