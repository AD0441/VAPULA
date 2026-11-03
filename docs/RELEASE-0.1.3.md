# VAPULA 0.1.3 — cierre técnico de V2

Los informes Markdown y PDF indican la versión y el build reales de la aplicación que los exporta. Se elimina el identificador genérico `0.1 development`; PDF Creator utiliza la misma identidad. Los resultados históricos conservan sus fechas e identificadores. SwiftPM declara expresamente si la versión del bundle no está disponible.

**Verificación:** 79 funciones Swift Testing en 17 suites release, incluidos cuatro SIGKILL de recuperación y una nueva aceptación con 31 filas: importar, corregir, imputar, analizar, revisar/aceptar conversiones, mover/reabrir y exportar una selección. La app produjo MD+8 PNG y PDF de diez páginas con `VAPULA 0.1.3 (build 4)`. [Cierre y archivos reales](ACCEPTANCE-V2.md).

**Descarga:** `VAPULA-0.1.3-macos-arm64.zip` y `SHA256SUMS.txt`. Apple Silicon; macOS 14 como mínimo de compilación. Host probado: M1/8 GB/macOS 27.2. Firma ad hoc; Developer ID, notarización y otro Mac continúan pendientes. [Alcance y límites](LIMITATIONS.md).

V2 se cierra en el alcance técnico de muestras sintéticas controladas. La versión sigue siendo preliminar y no cierra la auditoría universal de accesibilidad, temas/idiomas ni la matriz global. [Estado](STATUS.md).

Creado por Sebastián Pastén F. · MIT · [Apoyar en Ko-fi](https://ko-fi.com/C0C51WQ1T0)
