# Publicacion de Releases en GitHub

Esta guia describe el procedimiento para publicar una version distribuible de AIRE en GitHub.

## Reglas de version

- La version debe usar formato `MAJOR.MINOR.PATCH`, por ejemplo `1.2.0`.
- La version de la app cliente y la version del backend deben coincidir cuando esta activa la validacion de compatibilidad.
- El `build-number` de Flutter debe incrementarse en cada compilacion de Windows.
- No se deben publicar archivos `.env`, contrasenas ni configuraciones de base de datos.

## Prerequisitos

Ejecutar desde PowerShell:

```powershell
flutter --version
dotnet --version
gh auth status
```

El repositorio de la app es `ChaiGmzR/AIRE`. El repositorio del backend es `ChaiGmzR/AIRE_API_SERVER`.

## Actualizar versiones

En la app cliente actualizar:

- `pubspec.yaml`: `version: 1.2.0+4`
- `lib/app_info.dart`: version por defecto `1.2.0`

En el backend actualizar:

- `package.json`
- `package-lock.json`

El endpoint `GET /api/version` toma la version del backend desde `package.json`, salvo que `APP_VERSION` este configurada en el entorno.

## Validar el codigo

```powershell
flutter analyze
flutter test
```

```powershell
node --check server.js
node --check db.js
node --check routes/scans.js
npm ci --dry-run --ignore-scripts
```

## Compilar el cliente

```powershell
flutter build windows --release --build-name=1.2.0 --build-number=4
```

La salida queda en:

```text
build/windows/x64/runner/Release
```

## Generar el ZIP

El ZIP debe contener el contenido de `Release`, incluyendo `pcb_boxing_system.exe`, `flutter_windows.dll` y `data`.

```powershell
Compress-Archive `
  -Path build/windows/x64/runner/Release/* `
  -DestinationPath release/AIRE_1.2.0_windows.zip `
  -CompressionLevel Optimal `
  -Force
```

## Generar el instalador EXE

El instalador es autocontenido con .NET y debe:

1. Extraer el ZIP en `%LOCALAPPDATA%\IlsanPackingSystem`.
2. Crear el acceso directo del Escritorio.
3. Crear el acceso directo del Menu Inicio.
4. Apuntar ambos accesos a `pcb_boxing_system.exe`.
5. Usar el icono embebido del ejecutable.
6. Iniciar la app al terminar.

El proyecto del instalador debe incluir como recurso el ZIP de la misma version. Publicar con:

```powershell
dotnet publish release/installer_1_2_0/Installer.csproj `
  --configuration Release `
  --self-contained true `
  --runtime win-x64 `
  --output release/installer_1_2_0/publish
```

Copiar el resultado como:

```text
release/pcb_boxing_system_1.2.0_installer.exe
```

## Verificar antes de publicar

- El ZIP abre correctamente y contiene el ejecutable y `data`.
- El instalador EXE es autocontenido y no requiere PowerShell.
- El acceso directo del Escritorio se crea correctamente.
- El acceso directo del Menu Inicio se crea correctamente.
- El icono corresponde a `ImagenLogo1.png` convertido a `app_icon.ico`.
- La app muestra `v1.2.0`.
- El backend desplegado responde `version: 1.2.0` antes de distribuir la app.

## Commit y tag

Publicar primero los cambios del backend y del cliente:

```powershell
git add .
git commit -m "Preparar release AIRE 1.2.0"
git push origin main
```

Crear el tag de la app:

```powershell
git tag -a v1.2.0 -m "AIRE 1.2.0"
git push origin v1.2.0
```

## Crear el release

Desde el repositorio de la app:

```powershell
gh release create v1.2.0 `
  release/pcb_boxing_system_1.2.0_installer.exe `
  release/AIRE_1.2.0_windows.zip `
  --repo ChaiGmzR/AIRE `
  --title "AIRE 1.2.0" `
  --notes-file RELEASE_NOTES_1.2.0.md
```

El release debe contener como minimo:

- `pcb_boxing_system_1.2.0_installer.exe`
- `AIRE_1.2.0_windows.zip`

## Verificar el release publicado

```powershell
gh release view v1.2.0 --repo ChaiGmzR/AIRE
gh release verify-asset v1.2.0 release/pcb_boxing_system_1.2.0_installer.exe --repo ChaiGmzR/AIRE
```

Tambien se pueden comprobar las descargas directas:

```text
https://github.com/ChaiGmzR/AIRE/releases/download/v1.2.0/pcb_boxing_system_1.2.0_installer.exe
https://github.com/ChaiGmzR/AIRE/releases/download/v1.2.0/AIRE_1.2.0_windows.zip
```

## Orden de despliegue

1. Publicar y reiniciar el backend con `1.2.0`.
2. Confirmar `GET /api/version` y `GET /ready`.
3. Publicar el release de la app cliente.
4. Instalar en una PC de prueba.
5. Validar linea, flujo, escaneo, `Send`, accesos directos e icono.

Si el backend aun responde una version diferente, la app debe detener el flujo y mostrar el error de incompatibilidad. No se debe distribuir el instalador hasta corregir esa diferencia.
