# 📊 Análisis de Captura de Datos - PCB Boxing System

## 📥 Datos de Prueba Ingresados

**Simulación de captura:**
```
Box ID:     [A ser ingresado por el usuario]
Barcode 1:  LGB922602035972
Barcode 2:  EBR80757422922602040001
```

---

## 🔄 Flujo de Captura

### Paso 1: Ingreso de Box ID
- **Campo**: `boxIdInput` (TextEditingController)
- **Estado**: Se espera que el usuario ingrese un ID de caja
- **Acción**: Al presionar Enter, se bloquea el campo y se mueve el foco al campo de código de barras

### Paso 2: Captura de Códigos de Barras
- **Campo**: `barCodeInput` (TextEditingController)
- **Proceso para cada código de barras**:

#### Barcode 1: `LGB922602035972`
1. Usuario escanea/ingresa: `LGB922602035972`
2. Al presionar Enter, se envía al backend:
   ```json
   POST http://localhost:3000/api/scans
   {
     "boxCode": "[BOX_ID_INGRESADO]",
     "barcode": "LGB922602035972"
   }
   ```
3. Backend retorna (ejemplo):
   ```json
   {
     "success": true,
     "scan": {
       "serial": "LGB922602035972",
       "partNumber": "PCB-PART-001",
       "scanTime": "2026-02-04 14:30:45"
     },
     "counts": {
       "box": 1,
       "shift": 45
     }
   }
   ```

#### Barcode 2: `EBR80757422922602040001`
1. Usuario escanea/ingresa: `EBR80757422922602040001`
2. Se envía al backend:
   ```json
   POST http://localhost:3000/api/scans
   {
     "boxCode": "[BOX_ID_INGRESADO]",
     "barcode": "EBR80757422922602040001"
   }
   ```
3. Backend retorna (ejemplo):
   ```json
   {
     "success": true,
     "scan": {
       "serial": "EBR80757422922602040001",
       "partNumber": "PCB-PART-001",
       "scanTime": "2026-02-04 14:30:46"
     },
     "counts": {
       "box": 2,
       "shift": 46
     }
   }
   ```

---

## 📋 Estructura de Datos en la Tabla (BoxingList)

### Modelo de Datos Interno (BoxScan)
```dart
class BoxScan {
  final int no;              // Número secuencial (1, 2, ...)
  final String boxId;        // ID de la caja
  final String barCode;      // Código de barras (serial)
  final DateTime readTime;   // Timestamp de lectura
}
```

### Vista en Tabla - Esperada

| No  | Box Id    | BarCode                    | Read Time                |
|-----|-----------|----------------------------|--------------------------|
| 1   | [BOX_ID]  | LGB922602035972            | 2026-02-04 14:30:45      |
| 2   | [BOX_ID]  | EBR80757422922602040001    | 2026-02-04 14:30:46      |

---

## 🔌 Estructura de Datos Enviados al Backend

### Request POST: `/api/scans`

**Header:**
```
Content-Type: application/json
```

**Body - Captura 1:**
```json
{
  "boxCode": "[ID_CAJA_USUARIO]",
  "barcode": "LGB922602035972"
}
```

**Body - Captura 2:**
```json
{
  "boxCode": "[ID_CAJA_USUARIO]",
  "barcode": "EBR80757422922602040001"
}
```

---

## 💾 Estructura de Respuesta del Backend

### Response Status: 200 OK

**Captura 1:**
```json
{
  "scan": {
    "id": 1001,
    "serial": "LGB922602035972",
    "partNumber": "PCB-PART-001",
    "scanTime": "2026-02-04 14:30:45"
  },
  "counts": {
    "box": 1,
    "shift": 45
  }
}
```

**Captura 2:**
```json
{
  "scan": {
    "id": 1002,
    "serial": "EBR80757422922602040001",
    "partNumber": "PCB-PART-001",
    "scanTime": "2026-02-04 14:30:46"
  },
  "counts": {
    "box": 2,
    "shift": 46
  }
}
```

---

## 📊 Parámetros de Respuesta

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `scan.id` | int | ID único en BD |
| `scan.serial` | string | Número de serie extraído del código de barras |
| `scan.partNumber` | string | Número de parte (parte del barcode) |
| `scan.scanTime` | string | Timestamp del servidor |
| `counts.box` | int | Contador de piezas en esta caja |
| `counts.shift` | int | Contador total del turno |

---

## 🎯 Casos de Uso

### Caso 1: Captura Normal
```
1. Usuario ingresa Box ID: "BOX-001"
   → Se bloquea el campo
   
2. Usuario escanea: "LGB922602035972"
   → Se guarda localmente en la tabla
   → Count box = 1
   
3. Usuario escanea: "EBR80757422922602040001"
   → Se guarda localmente en la tabla
   → Count box = 2
```

### Caso 2: Error de Conexión
```
Si el backend no responde:
→ Se muestra error: "Connection error: [error_message]"
→ No se agrega a la tabla local
→ El foco permanece en el campo de barcode para reintentar
```

### Caso 3: Desbloquear/Cambiar Caja
```
Usuario presiona botón "Clear & New Box"
→ boxIdLocked = false
→ Se limpia boxIdController
→ Se limpia barCodeController
→ Foco regresa a boxIdInput
→ Tabla se vacía (o se guarda si hay opción de "Send")
```

---

## 🔍 Validaciones en la App

✅ **Box ID**: No puede estar vacío  
✅ **Barcode**: No puede estar vacío  
✅ **Secuencia**: No se puede capturar barcodes sin Box ID  
✅ **Procesamiento**: Solo se procesa uno a la vez (`isProcessing` flag)  

---

## 📝 Notas Importantes

1. **Sin Persistencia en BD**: Como solicitaste, estos datos NO se guardarían en la base de datos en esta simulación
2. **Almacenamiento Local**: Solo en la lista `boxScans` de la pantalla (en memoria)
3. **Estructura Consistente**: Cada escaneo mantiene:
   - Número secuencial
   - ID de caja
   - Serial/Barcode
   - Timestamp con precisión de segundos
4. **Formato de Hora**: YYYY-MM-DD HH:MM:SS

---

## 🚀 Para Ejecutar la Simulación

1. **App Flutter**: Ya está corriendo en modo debug
2. **Backend**: Debe estar en `http://localhost:3000` (actualmente no necesario para ver la estructura)
3. **Entrada Manual**: Puedes escribir directamente en los campos de la app
4. **O Escaneo Real**: Si tienes un escáner conectado, puede capturar automáticamente

