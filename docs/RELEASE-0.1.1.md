# VAPULA 0.1.1 — versión preliminar

**De los datos a la evidencia.** Esta entrega consolida el primer lote de integridad y decisiones visibles.

- **Proyectos protegidos:** bloqueo de escritura entre instancias, detección de sesión interrumpida y verificación de las versiones guardadas. Los datos sin referencia se conservan.
- **Conversiones con impacto visible:** nuevos NULL, ejemplos y aceptación explícita vinculada a la entrada. Una rama no reutiliza una aceptación de otra versión.
- **Borradores del inspector:** se conservan al cambiar de caja durante la sesión; ejecutar o cerrar exige resolverlos.
- **Exportación con alcance claro:** caja, resultado o proyecto completo, con resumen previo y una ruta común para PDF/Markdown/CSV.
- **Errores de lectura accionables:** contexto disponible del archivo y opciones para reintentar, sin consultas internas.

Mantiene los diez métodos generales, ocho formas de gráfico, personalización y procesamiento local de la versión anterior. **69 pruebas optimizadas en 15 suites**, más dos repeticiones completas; revisión nativa de borradores, conversiones, recuperación visible y exportaciones reales. [Evidencia y alcance](INTEGRITY-STAGE.md).

**Descarga:** `VAPULA-0.1.1-macos-arm64.zip`, acompañado de `SHA256SUMS.txt`. Descomprime y abre `VAPULA.app`. No necesita Python, R, Homebrew ni Xcode para ejecutarse.

**Plataforma:** Apple Silicon; macOS 14 como mínimo de compilación. Ejecución comprobada en M1/8 GB/macOS 27.2. Firma ad hoc, sin Developer ID ni notarización; otro Mac y macOS 14 siguen pendientes de calificación. Consulta [límites](LIMITATIONS.md) y [estado de requisitos](STATUS.md).

Los borradores son de sesión; un cierre forzado puede perder formularios aún no aplicados. La recuperación no reconstruye bases físicamente corruptas. Las conversiones cuentan nuevos NULL, sin prometer detectar todo redondeo o pérdida de precisión. Las figuras PDF siguen siendo PNG; los archivos de imagen deben viajar con el MD. No se incorpora XLSX, joins ni métodos propuestos en esta entrega.

[Conocer el proyecto](https://github.com/AD0441/VAPULA) · [Apoyar en Ko-fi](https://ko-fi.com/C0C51WQ1T0)

Creado por Sebastián Pastén F. · MIT
