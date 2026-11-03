# VAPULA — Cierre de V2 de la Gantt

**Corte:** 3 de noviembre de 2026, America/Santiago. **Entrega:** 0.1.3 preliminar, build 4, sobre `db6f682`. **Estado:** V2 cerrado en el alcance técnico de muestras sintéticas controladas. V1 permanece cerrado con la entrega pública 0.1.1.

V2 es el lote de aceptación de integridad de la planificación semanal; no significa cerrar toda la matriz de requisitos ni el lote 2 de usabilidad de 0.1.2. No se incorporan nuevas familias, métodos o formatos.

## Observación resuelta

El Markdown conservaba el identificador fijo «VAPULA 0.1 development». MD y PDF ahora identifican la versión y el build de la app que **exporta** el informe, tomados de su Info.plist. El PDF los incorpora también a Creator. El modelo de proyecto, las fechas y los identificadores de resultados históricos no se reescriben.

Fuera del bundle oficial —por ejemplo, SwiftPM— se declara que la versión no está disponible. No se toma la versión de un ejecutor de tests u otra app ni se inventa una versión pública. El valor puede inyectarse en pruebas sin alterar el entorno.

## Aceptación de integridad

| Criterio de V2 | Comprobación de cierre |
| --- | --- |
| Importar → corregir → tratar ausentes → analizar | Nueva prueba de integración con la base de laboratorio de 31 filas: n=30 y 1 excluido en la entrada; relleno por media y corrección X=4→4,5 crean versiones nuevas; el análisis final usa 31 válidos. Media esperada independiente: `(644 + 644/30 + 0,5)/31`. |
| Conversiones con pérdidas visibles | Vista previa de id→DATE: 31 nuevos NULL, 0 previos; la ejecución sin aceptación falla sin añadir versión. La aceptación crea una rama de 31 filas que no entra en el informe elegido. Las pruebas anteriores conservan los casos de NULL previos, ejemplos y consentimiento ligado a otra entrada. |
| Exportar y reabrir sin modificar la fuente | El paquete de la prueba se mueve/reabre: 4 versiones y 2 resultados; la entrada sigue X=4 y la corregida X=4,5. MD/PDF conservan SHA y el resultado seleccionado; excluyen histórico y rama de conversión. El CSV mantiene sus bytes. |
| Recuperación | La suite final repite los cuatro SIGKILL reales y la verificación de versiones/transacciones comprometidas, bloqueo entre escritores y apertura fallida. El aviso nativo del lote anterior sigue siendo una comprobación con marcador sintético; no se presenta como otro cierre forzado gráfico. |
| Versión del informe | Regresión automatizada en dos pares de versión/build, PDF Creator y MD escrito a disco. El caso sin versión declara su ausencia. |
| Exportación nativa final | La app 0.1.3 reabrió el paquete de ocho filas/12 cajas/2 versiones/2 resultados. El selector indicó 1 resultado, 0 hallazgos y 8 gráficos. Se exportaron MD+8 PNG y PDF por los paneles nativos. Ambos muestran `VAPULA 0.1.3 (build 4)` y excluyen el histórico. |
| Archivo utilizable y cierre | El PDF final tiene 10 páginas y pies; la primera se renderizó y revisó con el nuevo identificador legible. Los 8 enlaces MD resuelven; al cerrar no quedó marcador de sesión. CSV original con SHA-256 intacto. |

**79 funciones Swift Testing en 17 suites**, configuración release: [salida final](evidence/test-v2-release.txt). Incluye las referencias estadísticas y las pruebas de recuperación existentes; no se confunde su número de valores de referencia con un recuento de pruebas visuales.

Archivos reales: [PDF](evidence/v2-final.pdf), [Markdown y figuras](evidence/v2-final.md), [registro y sumas](evidence/v2-acceptance.json). Las muestras previas de 31/4/8 filas conservan sus registros fechados en [integridad](INTEGRITY-STAGE.md), [usabilidad](USABILITY-STAGE.md) y [validación](VALIDATION.md).

La herramienta visual devolvió dos timeouts después de guardar MD y guardas por cambio de usuario. Una nueva lectura de la app recuperó la ventana; el archivo ya estaba generado. Se verificaron los archivos reales y no se repitió Guardar sobre ellos ni se fabricaron capturas.

## Alcance del cierre

Se cierra el circuito y la observación acordados de V2 con casos sintéticos de ausentes, duplicados, atípicos, conversiones e históricos. No certifica la representatividad estadística de datos de producción de un sector, corrupción física, cortes de energía, todos los idiomas/temas/VoiceOver, otro Mac o ejecución real en macOS 14. Developer ID y notarización permanecen pendientes. Los demás estados parciales conservan su alcance en [STATUS.md](STATUS.md).
