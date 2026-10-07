# Publicacion de Releases en GitHub

Esta guia describe el procedimiento para publicar una version distribuible de AIRE en GitHub.

## Reglas de version

- La version debe usar formato `MAJOR.MINOR.PATCH`, por ejemplo `1.2.4`.
- GitHub conserva los releases publicos y sus assets como respaldo de distribucion.
- La app cliente valida y descarga directamente desde `\\192.168.1.10\updates\CALIDAD\AIRE`.
- La version del backend no se usa para validar la version del cliente.
- El `build-number` de Flutter debe incrementarse en cada compilacion de Windows.
- No se deben publicar archivos `.env`, contrasenas ni configuraciones de base de datos.
- El nombre del instalador debe coincidir con la version: `AIRE_Setup_<version>.exe`.

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

- `pubspec.yaml`: `version: 1.2.4+8`
- `lib/app_info.dart`: version por defecto `1.2.4`

En el backend actualizar:

- `package.json`
- `package-lock.json`

El endpoint `GET /api/version` y los endpoints de actualizacion del backend pueden conservarse para compatibilidad, pero no participan en la validacion de version de la app cliente.

La app solicita las credenciales SMB cuando no existe acceso disponible, las conserva unicamente en memoria mientras permanece abierta y usa `net use` con `/persistent:no`. Las credenciales no se escriben en archivos ni se incluyen en el instalador. La verificacion tambien puede repetirse con el boton pequeno junto a la marca de version en el encabezado.

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
flutter build windows --release --build-name=1.2.4 --build-number=8
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
  -DestinationPath release/AIRE_1.2.4_windows.zip `
  -CompressionLevel Optimal `
  -Force
```

## Generar el instalador EXE con Inno Setup

El instalador se genera con Inno Setup y debe:

1. Extraer el ZIP en `%LOCALAPPDATA%\IlsanPackingSystem`.
2. Crear el acceso directo del Escritorio.
3. Crear el acceso directo del Menu Inicio.
4. Apuntar ambos accesos a `pcb_boxing_system.exe`.
5. Usar el icono embebido del ejecutable.
6. Registrar la aplicacion en `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall`.
7. Incluir un desinstalador funcional en la entrada de Windows.
8. Iniciar la app al terminar una instalacion manual.
9. Registrar `pcb_boxing_system.exe` directamente en `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run`.

El script `release/installer/AIRE_Setup.iss` usa el contenido de `build/windows/x64/runner/Release`, no requiere PowerShell para instalar y produce un wizard grafico sin consola. La compilacion debe ejecutarse con Inno Setup Compiler (`ISCC.exe`):

```powershell
iscc.exe /DAppVersion=1.2.4 release/installer/AIRE_Setup.iss
```

El resultado debe llamarse exactamente:

```text
release/AIRE_Setup_1.2.4.exe
```

La app ejecuta el instalador descargado desde `%TEMP%` con los parametros silenciosos de Inno Setup (`/VERYSILENT`, `/SUPPRESSMSGBOXES`, `/NORESTART`) para actualizar y reiniciar AIRE. No se debe iniciar ningun watchdog ni reiniciar la app despues de que el usuario la cierre.

## Verificar antes de publicar

- El ZIP abre correctamente y contiene el ejecutable y `data`.
- El instalador EXE es generado por Inno Setup, no requiere PowerShell y no abre consola.
- La entrada de AIRE aparece en Aplicaciones instaladas y ejecuta el desinstalador.
- El acceso directo del Escritorio se crea correctamente.
- El acceso directo del Menu Inicio se crea correctamente.
- El icono corresponde a `assets/AIRE.png` convertido a `app_icon.ico`.
- La entrada de inicio automatico apunta directamente a `pcb_boxing_system.exe`.
- Al cerrar la app, no vuelve a iniciarse automaticamente.
- La app muestra `v1.2.4`.
- El release de GitHub publica el tag y los assets antes de distribuir la app.
- El mismo instalador debe copiarse al recurso compartido con el nombre exacto `AIRE_Setup_<version>.exe`.

## Commit y tag

Publicar primero los cambios del backend y del cliente:

```powershell
git add .
git commit -m "Agregar watchdog y modo maximizado AIRE 1.2.4"
git push origin main
```

Crear el tag de la app:

```powershell
git tag -a v1.2.4 -m "AIRE 1.2.4"
git push origin v1.2.4
```

## Crear el release

Desde el repositorio de la app:

```powershell
gh release create v1.2.4 `
  release/AIRE_Setup_1.2.4.exe `
  release/AIRE_1.2.4_windows.zip `
  --repo ChaiGmzR/AIRE `
  --title "AIRE 1.2.4" `
  --notes-file RELEASE_NOTES_1.2.4.md
```

El release debe contener como minimo:

- `AIRE_Setup_1.2.4.exe`
- `AIRE_1.2.4_windows.zip`

## Verificar el release publicado

```powershell
gh release view v1.2.4 --repo ChaiGmzR/AIRE
gh release verify-asset v1.2.4 release/AIRE_Setup_1.2.4.exe --repo ChaiGmzR/AIRE
```

Tambien se pueden comprobar las descargas directas:

```text
https://github.com/ChaiGmzR/AIRE/releases/download/v1.2.4/AIRE_Setup_1.2.4.exe
https://github.com/ChaiGmzR/AIRE/releases/download/v1.2.4/AIRE_1.2.4_windows.zip
```

## Actualizacion automatica

La app consulta directamente `\\192.168.1.10\updates\CALIDAD\AIRE` al abrirse. Lista los archivos `AIRE_Setup_<version>.exe`, selecciona la version mayor y, si es superior a la instalada, muestra un modal y copia el instalador a `%TEMP%`.

```text
\\192.168.1.10\updates\CALIDAD\AIRE\AIRE_Setup_<version>.exe
```

Si el recurso compartido no esta disponible o no puede autenticarse, la app muestra el error y no usa GitHub como fallback. Despues de copiarlo a `%TEMP%`, ejecuta el instalador local, cierra la app actual y el instalador reemplaza los archivos, recrea los accesos directos y reinicia la app.

La primera version que contiene este mecanismo debe instalarse manualmente; una version anterior no puede actualizarse a si misma porque no contiene el codigo del actualizador.

## Orden de despliegue

1. Confirmar que el backend desplegado responde `GET /ready` y tiene configurado el recurso compartido.
2. Publicar el release de la app cliente en GitHub.
3. Copiar `AIRE_Setup_<version>.exe` al recurso compartido de actualizaciones.
4. Instalar en una PC de prueba.
5. Validar linea, flujo, escaneo, `Send`, actualizacion, desinstalacion, accesos directos e icono.
