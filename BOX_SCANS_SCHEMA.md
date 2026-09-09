# 📊 Estructura de Datos - Tabla `box_scans`

## Descripción General
La tabla `box_scans` almacena los registros de escaneos de cajas/PCBs en el proceso de empaque (packing). Cada registro representa un escaneo único de un serial dentro de una caja en un momento específico.

---

## Esquema de la Tabla

| Campo | Tipo | Nullable | Default | Descripción |
|-------|------|----------|---------|-------------|
| `id` | `BIGINT UNSIGNED` | NO | AUTO_INCREMENT | Identificador único del registro |
| `serial` | `VARCHAR(64)` | NO | - | Número de serie del PCB/producto escaneado |
| `box_code` | `VARCHAR(64)` | NO | - | Código identificador de la caja |
| `first_scan` | `DATETIME` | NO | - | Fecha/hora del primer escaneo del serial |
| `last_scan` | `DATETIME` | NO | - | Fecha/hora del último escaneo del serial |
| `source_file` | `VARCHAR(255)` | NO | - | Nombre del archivo fuente de donde se extrajo el registro |
| `folder_date` | `DATE` | NO | - | Fecha de la carpeta contenedora (formato ISO) |
| `created_at` | `TIMESTAMP` | NO | CURRENT_TIMESTAMP | Fecha de creación del registro |

---

## Índices

| Nombre | Tipo | Campos | Propósito |
|--------|------|--------|-----------|
| `PRIMARY` | Primary Key | `id` | Identificador único |
| `uk_serial_box_time` | UNIQUE | `serial`, `box_code`, `first_scan` | Evita duplicados del mismo escaneo |
| `idx_box_time` | INDEX | `box_code`, `first_scan` | Búsquedas por caja y tiempo |
| `idx_folder_date` | INDEX | `folder_date` | Filtrado por fecha de carpeta |
| `idx_serial` | INDEX | `serial` | Búsquedas por número de serie |

---

## Formato de Datos de Entrada

Los datos se extraen de archivos de texto con **formato delimitado por pipes** (`|`):

```
SERIAL|BOX_CODE|FIRST_SCAN|LAST_SCAN
```

### Ejemplo de línea de archivo fuente:
```
ABC123456789012|BOX2024001|2026-01-15 14:30:22|2026-01-15 14:30:45
```

### Parsing de cada campo:
| Campo | Posición | Procesamiento |
|-------|----------|---------------|
| `serial` | `parts[0]` | `.strip()` |
| `box_code` | `parts[1]` | `.strip()` |
| `first_scan` | `parts[2]` | `.strip()[:19]` (primeros 19 caracteres) |
| `last_scan` | `parts[3]` | `.strip()[:19]` (primeros 19 caracteres) |

---

## Formato de Fechas

| Campo | Formato | Ejemplo |
|-------|---------|---------|
| `first_scan` | `YYYY-MM-DD HH:MM:SS` | `2026-01-15 14:30:22` |
| `last_scan` | `YYYY-MM-DD HH:MM:SS` | `2026-01-15 14:30:45` |
| `folder_date` | `YYYY-MM-DD` | `2026-01-15` |

---

## SQL para Inserción (UPSERT)

```sql
INSERT INTO box_scans (serial, box_code, first_scan, last_scan, source_file, folder_date)
VALUES (%s, %s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  last_scan   = GREATEST(box_scans.last_scan, VALUES(last_scan)),
  source_file = VALUES(source_file),
  folder_date = COALESCE(box_scans.folder_date, VALUES(folder_date));
```

### Orden de parámetros para inserción:
1. `serial` (VARCHAR 64)
2. `box_code` (VARCHAR 64)
3. `first_scan` (DATETIME)
4. `last_scan` (DATETIME)
5. `source_file` (VARCHAR 255)
6. `folder_date` (DATE)

---

## DDL Completo para Crear la Tabla

```sql
CREATE TABLE IF NOT EXISTS box_scans (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  serial         VARCHAR(64)  NOT NULL,
  box_code       VARCHAR(64)  NOT NULL,
  first_scan     DATETIME     NOT NULL,
  last_scan      DATETIME     NOT NULL,
  source_file    VARCHAR(255) NOT NULL,
  folder_date    DATE         NOT NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_serial_box_time (serial, box_code, first_scan),
  KEY idx_box_time (box_code, first_scan),
  KEY idx_folder_date (folder_date),
  KEY idx_serial (serial)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## Notas para Integración

> [!IMPORTANT]
> La clave única `uk_serial_box_time` (`serial`, `box_code`, `first_scan`) determina que un registro es un duplicado. Si se intenta insertar un registro con la misma combinación, se actualizará el `last_scan` al valor más reciente.

> [!TIP]
> Para extraer el número de parte del serial, usa los primeros 11 caracteres: `serial[:11]`
