# AIRE 1.2.5

- DISPLAY acepta Barcode de produccion y QR SMD.
- Los QR SMD con separadores `ñ`, apostrofe o `;` se normalizan al formato con `;`.
- El numero de parte del QR SMD se obtiene del campo posterior a `MAIN`.
- Los Barcodes de produccion se comparan sin distinguir mayusculas y minusculas.
- MAIN PCB continua aceptando unicamente Barcodes de produccion.
- Se incluyen el instalador wizard y el archivo ZIP para Windows.
