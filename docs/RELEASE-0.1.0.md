# VAPULA 0.1.0 — versión preliminar

Un laboratorio nativo para preparar datos, conectar análisis y compartir evidencia desde tu Mac.

- Escritorio de cajas conectadas, inspector, vistas previas y ejecución por ramas.
- CSV/TSV/Parquet; versiones inmutables y corrección explícita de celdas, filas y columnas.
- Ausentes: media, mediana, moda, valor indicado o retirada de filas/columnas afectadas, con vista previa del impacto.
- Diez métodos generales: descriptivos, t de una muestra/pareada/Welch, Pearson, Spearman, ANOVA de un factor, Mann–Whitney, chi-cuadrado y regresión simple.
- Ocho formas de gráfico, colores editables y controles de títulos, ejes y marcas.
- Informes PDF con texto vectorial y figuras PNG, Markdown con imágenes locales y CSV de resultados.

**Descarga:** `VAPULA-0.1.0-macos-arm64.zip`. Descomprime y abre `VAPULA.app`. `SHA256SUMS.txt` permite comprobar el archivo. La ejecución no necesita Python, R, Homebrew ni Xcode.

**Compatibilidad y estado:** Apple Silicon; macOS 14 como mínimo de compilación. Ejecución local comprobada en M1 de 8 GB con macOS 27.2. Firma ad hoc, sin Developer ID ni notarización; otras versiones de macOS y equipos siguen pendientes de validación. Es una versión preliminar. Consulta [VALIDATION.md](VALIDATION.md) y [LIMITATIONS.md](LIMITATIONS.md).

53 pruebas optimizadas en nueve suites, referencias estadísticas independientes y revisión real del flujo de edición, análisis, gráfico, exportación y reapertura con datos sintéticos. El ZIP se comprobó mediante SHA-256, extracción limpia, firma estricta ad hoc y comparación de todos sus archivos con el bundle local.

[Conocer el proyecto](https://github.com/AD0441/VAPULA) · [Apoyar en Ko-fi](https://ko-fi.com/C0C51WQ1T0)

Creado por Sebastián Pastén F. · MIT
