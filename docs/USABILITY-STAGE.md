# VAPULA — Lote 2: uso real y presentación

**Corte:** 2 de noviembre de 2026, America/Santiago. **Versión:** 0.1.2 preliminar, build 3, sobre `d77da2e`.

Esta entrega mejora el uso local del escritorio aceptado. Conserva las siete familias, diez métodos, ocho formas, versiones inmutables y procesamiento local. No incorpora las ampliaciones propuestas ni califica todos los requisitos del lote 2.

## Cambios revisables

| Antes | Después | Motivo |
| --- | --- | --- |
| Navegación centrada en las cajas del lienzo | Lista nativa de pasos, selección y desplazamiento al paso activo; ⌘⌥↑/↓ | Mantener acceso cuando el grafo crece o se usa teclado. |
| Conexiones mediante puertos | Menú contextual de entradas compatibles en el inspector, además de los puertos | Poder elegir una entrada sin arrastrar. Excluye descendientes/ciclos; el motor sigue validando. |
| Cajas llamadas «Gráfico» | Tipo de gráfico visible cuando no hay título propio | Distinguir barras, línea, área y caja en lista e inspector. Los títulos del usuario se conservan. |
| Algunos iconos sin nombre accesible | Nombres, estado de paneles, selección explícita y etiquetas de tamaño/trazo | Mejorar la lectura AX y la orientación. No equivale a certificación completa con VoiceOver. |
| Paneles de anchura fija y vista inferior alta | Inspector de 320 puntos, biblioteca de 180 y altura de vista previa proporcional; mínimo declarado 1060×700 con restricción nativa | Conservar espacio de trabajo y controles. La matriz completa de tamaños sigue pendiente. |
| HEX incorrecto normalizado silenciosamente | Mensaje junto al campo, texto conservado y aplicación desactivada | Corregir sin perder la entrada ni aplicar un color distinto. La lectura defensiva de proyectos antiguos se mantiene. |
| Marcas oscuras en temas oscuros | Paletas integradas aclaradas en oscuro y acento adaptativo | Mejorar visibilidad. El RGB personalizado permanece exacto y recibe aviso de bajo contraste en pantalla/PDF claro. |
| Textos fijos y mensajes dinámicos mezclados | Catálogo de presentación ES/EN, interpolaciones separadas del texto y cambio en vivo | Traducir controles y mensajes sin cambiar nombres, valores o documentos guardados. |
| Título de figura al final de una página | Reserva del bloque de título, procedencia, leyenda e imagen PDF | Mantener juntas las figuras acotadas de la app. Textos externos que exceden una página conservan paginación normal. |

Atajos añadidos: ⌘⌥1 biblioteca, ⌘⌥2 vista previa, ⌘⌥3 inspector. Los comandos anteriores de guardar, ejecutar y exportar continúan disponibles. Los dos enlaces de apoyo de la app apuntan al mismo Ko-fi canónico del README; no se abrieron ni se enviaron datos por esos enlaces durante el recorrido.

## Verificación automatizada

[76 funciones Swift Testing en 16 suites](evidence/test-polish-release.txt), configuración release. Se mantienen las referencias estadísticas y los cuatro cierres SIGKILL del lote anterior. Los casos nuevos cubren RGB válido/inválido, contraste, integridad de sustituciones, contenido interpolado, traducción reversible de diagnósticos conocidos y candidatos de conexión sin ciclos.

Una revisión estática encontró 401 claves literales L/T usadas en la app, todas presentes en un catálogo de 758 entradas. Incluye entradas de identidad y etiquetas heredadas; esas cantidades no son una certificación lingüística de cada pantalla o artefacto. Los mensajes desconocidos se conservan y los diagnósticos guardados se traducen únicamente en presentación. La prueba comprueba que las plantillas no añadan ni pierdan argumentos, incluidos porcentajes, acentos y texto que contiene `%@`.

La [regresión de paginación](evidence/test-polish-pagination-before.txt) reprodujo cuatro discrepancias entre títulos e imágenes por página antes del arreglo. La suite final pasa y comprueba ocho figuras con sus títulos en la misma página. Los recursos del catálogo están incluidos en el bundle y comprobados en la extracción limpia.

## Recorrido nativo observado

Se usaron ocho filas sintéticas, dos medidas numéricas, una categoría larga y valores ausentes; no hubo datos personales. La fuente original mantuvo SHA-256 `06fc1299abef1df68eb2fce48f8a40b125c679100b3ca34da0823edf6d1d5226`.

1. Crear un proyecto e importar CSV. Un archivo de formato incorrecto mostró un diagnóstico con la acción de elegir CSV/TSV/Parquet; se canceló y se importó la fuente correcta.
2. Completar un ausente de `medida` con media: 1 celda de 8 filas, valor resultante 10. La versión original siguió incorporada.
3. Ejecutar descriptiva de `medida`: n=8, media=10, mediana=10, DE muestral=4. Un primer análisis de `id` quedó como histórico; el informe selecciona sólo el resultado actual.
4. Cambiar de paso con ⌘⌥↑/↓ y regresar al análisis. La lista nativa conserva selección; al seleccionar Informe se desplaza hasta él.
5. Cambiar a inglés y revisar escritorio, resultados, inspector y ajustes. Los nombres `medida`, `grupo` y el título español del gráfico permanecieron intactos. Revisar oscuro; después restaurar español y claro.
6. Escribir `#GG1234`: texto conservado, diagnóstico visible y dos acciones de aplicar desactivadas. Escribir `#FFFFFF`: aviso de contraste. Restablecer y aplicar `#256A8A`.
7. Ejecutar histograma, barras verticales/horizontales, dispersión, línea, área, boxplot y puntos con tallos. Las formas por pares usan `medida`/`comparacion`; las categóricas usan `grupo`, con recuentos 4/4. La lectura AX agrupa marcas y no se presenta como recuento de observaciones.
8. Conectar un análisis y ocho gráficos a Informe mediante sus casillas. ⌘E confirma **1 resultado, 0 hallazgos y 8 gráficos**. [Markdown y figuras reales](evidence/ocho-formas.md).
9. La primera exportación PDF mostró títulos separados de su imagen. Tras el arreglo se exportó de nuevo desde la app: [PDF final de 10 páginas](evidence/usabilidad-final.pdf). Se renderizaron sus páginas; la confirmación visual revisó título largo, barras, boxplot y puntos con tallos. Las cabeceras se contrastaron con coordenadas de PDFKit y un render directo de CoreGraphics.
10. Reabrir desde el selector nativo recuperó 12 cajas y dos versiones. El panel declara explícitamente el tipo de paquete y establece las opciones de selección después de sus tipos. Se verificó el nombre de cada forma y la selección exclusiva del paso activo. Cierre limpio sin marcador de sesión pendiente.

El primer recorrido, incluida la importación, corrección, análisis y exportaciones, se ejecutó con `sandbox-exec` y `(deny network*)` aplicado sólo al proceso de prueba. Una observación de sockets IP no devolvió conexiones de VAPULA. La confirmación posterior usó una instancia normal. Esto no sustituye una prueba con todo el Mac físicamente desconectado ni implica App Sandbox de distribución.

La herramienta visual presentó guardas por cambios de usuario, imágenes vacías y errores de ScreenCaptureKit. Tras interrupciones de sesión se recuperó la conexión y se reinició una instancia de prueba sin proyecto abierto. Una muestra de un segundo encontró el hilo principal esperando eventos; no es una medición de rendimiento. En el primer recorrido apareció un aviso de reentrancia de NSTableView sin pérdida observada; su causa no se declara resuelta. El panel de guardado requirió volver a elegir una carpeta temporal para habilitar Guardar. No se publican capturas vacías ni reconstrucciones.

## Alcance que sigue abierto

- UX-02: recorrido completo con VoiceOver y sólo teclado, incluido foco y todas las conexiones.
- UX-03/GRA-05/06: matriz completa de tamaño mínimo, contenido extremo/vacío, temas, formas y contraste/percepción cromática. No se certificó un tamaño de ventana mediante la captura remota.
- UX-04: traducción completa de los artefactos PDF/MD y mensajes técnicos no reconocidos; los diálogos del sistema siguen el idioma de macOS. El catálogo no reescribe procedimientos históricos.
- UX-05/REN-01: todos los fallos, cancelaciones y el aviso de tabla nativa bajo carga.
- SEG-01/VAL-03: Mac totalmente desconectado, otro Mac sin desarrollo y ejecución real en macOS 14.
- Developer ID y notarización continúan pendientes.

GRA-02 queda implementado en su alcance escrito. Los demás estados parciales se conservan con evidencia más precisa en [STATUS.md](STATUS.md). La versión sigue siendo preliminar.
