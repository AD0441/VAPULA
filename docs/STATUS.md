# VAPULA — Estado de los requerimientos

**Corte:** 2 de noviembre de 2026, America/Santiago.

**Línea base:** [REQUIREMENTS.md v1.1](REQUIREMENTS.md).

**Aplicación:** [0.1.2 preliminar](https://github.com/AD0441/VAPULA/releases/tag/v0.1.2), [fuentes del tag](https://github.com/AD0441/VAPULA/tree/v0.1.2). Lote de usabilidad sobre `d77da2e`. Las releases 0.1.0/0.1.1 conservan su evidencia histórica.

**Documentación/identidad revisada:** [`7caa136`](https://github.com/AD0441/VAPULA/commit/7caa1364daf87f4d4e480924c399bae8f79ea4fd), incorporando después este inventario.

Esta matriz conserva la separación entre requisitos y cobertura usada en [NABERIUS](https://github.com/AD0441/NABERIUS/blob/main/docs/STATUS.md). El [lote 1 de integridad](INTEGRITY-STAGE.md) implementa PRY-05, IMP-04, EDT-03, FLU-07 e INF-04, con pruebas y revisión nativa. Los demás pendientes y propuestas conservan su alcance.

## Cómo interpretar el estado

| Estado | Significado |
| --- | --- |
| Implementado | La capacidad existe en el alcance descrito y tiene evidencia identificada. No implica auditoría de todas las variantes. |
| Parcial | Existe una base, pero falta parte del comportamiento o de la aceptación escrita. La fila explica qué. |
| Pendiente | Falta la capacidad descrita o su cierre verificable. |
| Propuesto | Ampliación sin alcance aprobado; requiere priorización antes de implementarse. |

P0/P1/P2 expresan prioridad, no aprobación de una propuesta. Los orígenes C/B/D/P están definidos en la especificación. **La release preliminar no cierra todos los P0.** Las pruebas automatizadas no sustituyen una auditoría de teclado/VoiceOver, una comprobación en otro Mac ni una revisión visual exhaustiva.

| Prioridad | Implementado | Parcial | Pendiente | Propuesto | Total |
| --- | --- | --- | --- | --- | --- |
| P0 | 51 | 9 | 0 | 0 | 60 |
| P1 | 2 | 10 | 7 | 4 | 23 |
| P2 | 0 | 0 | 0 | 1 | 1 |
| **Total** | **53** | **19** | **7** | **5** | **84** |

Son cantidades de requisitos, con tamaños distintos; no un porcentaje de avance ni una estimación de esfuerzo. Los 9 P0 parciales señalan trabajo de consolidación pendiente.

## Evidencia disponible y sus límites

- **Núcleo e integración:** 76 funciones Swift Testing en 16 suites en release. Incluyen los casos previos y los nuevos de RGB, traducción, conexiones y paginación PDF. [Salida final][tests], [registro del lote][usability].
- **Estadística:** 1.356 valores escalares de referencia independientes, con definiciones y tolerancias. No equivalen a 1.356 pruebas visuales. [Validación estadística][numerical].
- **Aplicación real:** el recorrido base de 31 filas sigue registrado. El lote 1 añade borradores, conversión con cuatro pérdidas/cancelación/aceptación, recuperación visible y PDF/MD selectivos sobre cuatro filas sintéticas. [Lote 1][integritystage], [registro base][native], [capturas base][screenshots]. El [lote 2][usability] añade navegación, ES/EN, diagnóstico HEX, ocho formas, PDF/MD y reapertura con ocho filas sintéticas. No se revisaron todas las combinaciones de métodos, estilos, idiomas y temas.
- **Distribución:** ZIP arm64 0.1.2, SHA-256, extracción limpia, firma estricta ad hoc y comparación de archivos. [Integridad 0.1.2][integrity], [notas de release][release]. No hay Developer ID/notarización ni calificación en otro Mac/macOS mínimo.
- **CI histórica:** ejecuciones satisfactorias de [main del código publicado](https://github.com/AD0441/VAPULA/actions/runs/41325036372), [tag 0.1.0](https://github.com/AD0441/VAPULA/actions/runs/41325199928) y [documentación de familia](https://github.com/AD0441/VAPULA/actions/runs/41332703840). CI no demuestra accesibilidad ni compatibilidad visual con todos los sistemas.

## 1. Proyecto, versiones y recuperación

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| PRY-01 | P0 | Implementado | Crear/abrir/cerrar, datos materializados y reapertura portable en integración; otro Mac se califica en VAL-03. [Pruebas de proyecto][projecttests]. |
| PRY-02 | P0 | Implementado | Versiones físicas y procedencia; hash original intacto en integración y revisión nativa. [Pruebas][projecttests], [revisión][validation]. |
| PRY-03 | P0 | Implementado | Manifiesto atómico y prueba de fallo de escritura sin versión parcial referenciada. Una tabla huérfana tras caída sigue siendo posible. [Pruebas][projecttests], [límites][limits]. |
| PRY-04 | P0 | Implementado | Compatibilidad aditiva de esquema 1 sin flujo y rechazo de esquema futuro. No existe un marco general de migraciones ni lectura por binarios antiguos. [Pruebas][projecttests], [grafo][workflowtests]. |
| PRY-05 | P0 | Implementado | Reserva exclusiva de escritura, detección de sesión interrumpida, comprobación de versiones y rechazo de incoherencias sin borrar datos. Cuatro SIGKILL reales, conflicto entre escritores y apertura fallida probados; no reconstruye corrupción física. [Lote 1][integritystage], [pruebas][sessiontests]. |
| PRY-06 | P1 | Pendiente | Sin estimador de espacio, coste de versiones ni interfaz de compactación/limpieza. [Límites][limits]. |

## 2. Lienzo y ejecución del flujo

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| FLU-01 | P0 | Implementado | Siete familias, barra, inspector y cuatro salidas; recorrido nativo real. [Interfaz][workbench], [revisión][validation]. |
| FLU-02 | P0 | Implementado | Arrastre, zoom, desplazamiento, encuadre y posiciones persistidas; selección de fuente vuelve a su caja. [Lienzo][canvas], [revisión][validation]. |
| FLU-03 | P0 | Implementado | Validación de ciclos, clases, identidades y referencias; pruebas de fuente/salida. [Modelo][graph], [pruebas][workflowtests]. |
| FLU-04 | P0 | Implementado | Antecesores selectivos, invalidación y ramas independientes verificadas con ejecución real del motor. [Pruebas][workflowtests]. |
| FLU-05 | P0 | Implementado | Fases/errores por caja, compromisos previos conservados y cancelación cooperativa. Espera la consulta síncrona; no hay interrupción inmediata de DuckDB. [Ejecución][execution], [límites][limits]. |
| FLU-06 | P0 | Implementado | Quitar/deshacer rama conserva seis versiones físicas en la revisión nativa. Deshacer restaura configuración del grafo; no borra datos ni ofrece rehacer. [Revisión][validation], [controlador][workflowui]. |
| FLU-07 | P0 | Implementado | Borradores por proyecto/caja/entrada durante la sesión, indicador, descarte y guardas al ejecutar/cerrar. Ausentes y título de gráfico conservados al cambiar de caja en revisión real. No son autoguardado de formularios ante SIGKILL. [Modelo][draftmodel], [revisión][integritystage]. |
| FLU-08 | P1 | Propuesto | Nombres/notas, duplicado, selección múltiple y rehacer requieren selección de alcance; no se presentan como disponibles. |

## 3. Importación

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| IMP-01 | P0 | Implementado | CSV/TSV/Parquet, vista previa y parámetros manuales; ejemplos regionales/BOM probados. [Pruebas][projecttests], [motor][engine]. |
| IMP-02 | P0 | Implementado | UTF-8/BOM y rechazo explícito de otras codificaciones. El diagnóstico aún necesita traducción completa en UX-04. [Motor][engine]. |
| IMP-03 | P0 | Implementado | Materialización en el paquete y reapertura sin referencia externa; no hay modo de enlace ni copia cruda opcional. [Pruebas][projecttests]. |
| IMP-04 | P0 | Implementado | Mensajes por tipo de fallo y contexto disponible de fila/columna/ejemplo, sin SQL interno. Si el lector no informa ubicación concreta, se indica y se orienta el reintento. [Diagnósticos][importdiagnostic], [integración][importtests], [lote 1][integritystage]. |
| IMP-05 | P1 | Parcial | Límites y rutas están protegidos en el motor/documentados; falta anticiparlos de manera uniforme en la confirmación de importación. [Límites][limits], [motor][engine]. |

## 4. Tabla, perfiles y metadatos

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| DAT-01 | P0 | Implementado | Tabla de 100 filas, búsqueda/ordenación en DuckDB e identidad estable al editar. Máximo 256 columnas. [Cuadrícula][grid], [pruebas][cleaningtests]. |
| DAT-02 | P0 | Implementado | Perfiles completos, distintos exactos y resúmenes; no dependen de la página. [Pruebas][projecttests], [consultas][queries]. |
| DAT-03 | P0 | Implementado | Fuentes e historial compartidos; entrada X=4 y versión corregida X=4,5 verificadas al reabrir. [Revisión][validation]. |
| DAT-04 | P1 | Pendiente | Escala desconocida por defecto; sin editor de metadatos, unidades ni funciones de variable. [Modelo de datos][datamodel], [límites][limits]. |
| DAT-05 | P1 | Parcial | Se pueden abrir ambas versiones y consultar procedencia; no existe un comparador de diferencias/impacto general. [Historial][workbench], [límites][limits]. |

## 5. Preparación y edición

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| EDT-01 | P0 | Implementado | Transformaciones tipadas reproducibles, constantes finitas y protección de identificadores/valores. [Pruebas][projecttests], [preparación][preparation]. |
| EDT-02 | P0 | Implementado | Corrección, filas/columnas nuevas y retirada por identidad tras búsqueda/ordenación. Columna real `rowid` requiere renombrar; no hay pegado de matrices. [Pruebas][cleaningtests], [revisión][validation]. |
| EDT-03 | P0 | Implementado | Conteo exacto de nuevos NULL, previos y hasta cinco ejemplos. Aceptación explícita ligada a entrada/columna/tipo/cantidad, comprobada también por el motor; cambia la entrada y exige revisar otra vez. No detecta todos los redondeos. [Pruebas][casttests], [revisión][integritystage]. |
| EDT-04 | P1 | Parcial | Motor con ambos sentidos y agregación count/mean/sum/min/max; la preparación visible fija ascendente. La tabla sí permite ordenar su vista. [Preparación][preparation], [pruebas][projecttests]. |
| EDT-05 | P1 | Implementado | Selección nativa de columnas a conservar y adición tipada; retirar columnas se hace mediante selección, no con un comando directo de borrado. [Preparación][preparation], [edición][editing], [pruebas][cleaningtests]. |

## 6. Valores ausentes

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| AUS-01 | P0 | Implementado | NULL y opciones de texto vacío/espacios/no finitos, aplicadas en vista previa y transformación. [Pruebas][cleaningtests], [panel][missingui]. |
| AUS-02 | P0 | Implementado | Celdas por columna y unión de filas con impacto exacto. [Pruebas][cleaningtests]. |
| AUS-03 | P0 | Implementado | Media/mediana/moda, vacío total rechazado y desempate de moda determinista; precisión BIGINT de moda probada. [Pruebas][cleaningtests]. |
| AUS-04 | P0 | Implementado | Constantes tipadas, retirar filas o columnas e impedir quitar todas. Se verificaron adición/retirada y fuente intacta en el flujo real. [Pruebas][cleaningtests], [revisión][validation]. |
| AUS-05 | P0 | Implementado | Método registrado y advertencia en inferencias descendientes; no ajusta estadísticamente la incertidumbre imputada. [Ejecución][execution], [límites][limits]. |
| AUS-06 | P1 | Parcial | El panel avisa conversión a DOUBLE y efectos de imputar; falta advertencia específica de precisión para enteros grandes antes de ejecutar. [Panel][missingui], [límites][limits]. |

## 7. Calidad de datos

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| CAL-01 | P0 | Implementado | Seis familias de hallazgo: NULL, blancos, no finitos, duplicados, rango e IQR; evidencia acotada por regla. [Calidad][quality], [pruebas][projecttests]. |
| CAL-02 | P0 | Implementado | Candidatos separados de transformaciones; ninguna detección elimina automáticamente. [Calidad][quality], [límites][limits]. |
| CAL-03 | P1 | Parcial | Conteos y hasta 100 ejemplos; falta exportación completa de filas afectadas desde un recorrido dedicado. [Calidad][quality], [límites][limits]. |
| CAL-04 | P1 | Pendiente | Inconsistencia por celda no es una regla independiente; hoy se aborda con fallos de lectura, TRY_CAST y perfiles. [Límites][limits]. |

## 8. Estadística y resultados

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| EST-01 | P0 | Implementado | Diez métodos disponibles; referencias automatizadas y menú nativo comprobado. No todos fueron recorridos visualmente. [Validación estadística][numerical], [revisión][validation]. |
| EST-02 | P0 | Implementado | Casos constantes/no finitos/tamaños/overflow y límites explícitos. No hay muestreo silencioso de análisis materializados. [Pruebas][statstests], [expansión][expandedtests], [límites][limits]. |
| EST-03 | P0 | Implementado | n/exclusiones, supuestos y advertencias por procedimiento en resultados; interpretación contextual, sin conclusión causal automática. [Validación estadística][numerical], [presentación][analysispresentation]. |
| EST-04 | P0 | Implementado | Efectos definidos por método y salidas acotadas; correlaciones sin p, Mann–Whitney asintótico y ANOVA sin post-hoc. [Definiciones y referencias][numerical]. |
| EST-05 | P0 | Implementado | Regresión centrada con covarianzas, errores disponibles y pruebas de escala/degeneración. [Pruebas][statstests], [definiciones][numerical]. |
| EST-06 | P1 | Pendiente | Sin exportación completa de residuos, paneles diagnósticos ni intervalos de coeficientes. [Límites][limits]. |
| EST-07 | P0 | Implementado | Resultados persistidos, etiquetas legibles y selección individual PDF/MD comprobada; alcance global por atajo aún en INF-04. [Pruebas PDF][pdftests], [revisión][validation]. |
| EST-08 | P1 | Parcial | Ya hay explicaciones previas por método, supuestos y selección contextual de variables; falta comprobar comprensión y suficiencia de la ayuda con usuarios. [Panel estadístico][statisticsui], [presentación][analysispresentation]. |

## 9. Gráficos y personalización

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| GRA-01 | P0 | Implementado | Ocho formas en el renderizador y menú; histograma/dispersión y estilos recorridos en la app. Exhaustividad visual en GRA-05. [Gráficos][charts], [renderizador][chartrenderer], [revisión][validation]. |
| GRA-02 | P0 | Implementado | Paletas y estilos persistidos; HEX inválido conserva su entrada, explica el formato y bloquea aplicar. Aviso de contraste para RGB personalizados. Comprobación nativa de inválido/blanco/color válido y pruebas de RGB/contraste. [Lote de usabilidad][usability], [panel][chartpanel]. |
| GRA-03 | P0 | Implementado | Límites y definiciones explícitos: 2.000 pares, top 30, histograma y caja; atípicos de caja contados, sin puntos dibujados. [Gráficos][charts], [límites][limits]. |
| GRA-04 | P0 | Implementado | Parámetros por caja/versión; cache se regenera al ejecutar tras reabrir. Vista identifica tipo/variables realmente aplicados. [Revisión][validation], [controlador][workflowui]. |
| GRA-05 | P0 | Parcial | Ocho formas ejecutadas y exportadas; título largo y categoría larga revisados. PDF final agrupa título/procedencia/imagen. Falta matriz completa de temas, tamaños, vacíos y extremos. [Revisión][usability], [PDF final][polishpdf]. |
| GRA-06 | P1 | Parcial | Paletas integradas adaptadas a oscuro y aviso de contraste personalizado; marcas con nombres AX. Faltan auditoría cromática completa y recorrido VoiceOver de todas las figuras. [Revisión][usability]. |

## 10. Informes e intercambio

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| INF-01 | P0 | Implementado | PDF de texto vectorial, tablas paginadas y figuras PNG; Unicode, pies, selección y páginas largas probados/renderizados. Figuras raster, no vectoriales. [PDF][pdfdocs], [pruebas][pdftests], [muestra][pdfsample]. |
| INF-02 | P0 | Implementado | MD y PNG con referencias relativas; exportación nativa y protección de sidecars comprobadas. Los archivos asociados deben viajar juntos. [Pruebas][pdftests], [revisión][validation]. |
| INF-03 | P0 | Implementado | Informe del flujo con salidas alcanzables, procedencia y máximo 32 figuras; rechazo de referencias ajenas. [Puente de exportación][reportui], [pruebas][pdftests]. |
| INF-04 | P0 | Implementado | Selector y plan comunes para caja/resultado/proyecto; resumen previo, históricos y gráficos pendientes explícitos. ⌘E y PDF/MD reales verificados, con exclusión de ramas ajenas. [Selección][reportselection], [pruebas][selectiontests], [revisión][integritystage]. |
| INF-05 | P1 | Parcial | MD global admite perfiles; la caja Informe no los pasa y PDF no ofrece esas tablas. Falta paridad PDF/MD desde el flujo. [Informes][reports], [puente][reportui]. |
| INF-06 | P0 | Implementado | CSV/Parquet de datos, CSV de resultados y destinos protegidos; pruebas de fallo/rollback y figuras existentes. [Pruebas de datos][projecttests], [pruebas de informes][pdftests]. |

## 11. Diseño y uso de macOS

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| UX-01 | P0 | Parcial | Lista de pasos y nombres de formas, inspector más amplio y vista inferior proporcional; recorrido completo sintético y exportaciones reales. Falta evaluación sistemática de claridad con usuarios. [Lote 2][usability]. |
| UX-02 | P0 | Parcial | Lista nativa, atajos de pasos/paneles, menú de entradas compatibles y nombres/selección AX comprobados. Falta recorrido completo sólo con teclado y VoiceOver. [Revisión][usability]. |
| UX-03 | P0 | Parcial | Acento adaptativo, marcas claras en oscuro, paneles ajustados y restricción nativa del mínimo 1060×700. Se observó oscuro y contenido largo; no se certificó el mínimo con la captura remota ni la matriz completa. [Revisión][usability]. |
| UX-04 | P0 | Parcial | Catálogo ES/EN con 758 entradas y cambio en vivo del recorrido principal, mensajes conocidos y ayudas. Datos/títulos propios conservados. Informes y texto técnico desconocido aún pueden mezclar idiomas; diálogos del sistema siguen macOS. [Revisión][usability], [catálogo][uitext]. |
| UX-05 | P0 | Parcial | Diagnóstico de lectura, HEX y contraste comprobados; selector de paquete/reapertura confirmados. Faltan todos los fallos/cancelaciones y seguimiento del aviso de tabla nativa. [Revisión][usability]. |
| UX-06 | P1 | Pendiente | No existe todavía estudio registrado de tres recorridos con usuarios ni cierre de tropiezos medidos. Las decisiones de la maqueta no sustituyen esa observación. |

## 12. Privacidad y seguridad

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| SEG-01 | P0 | Parcial | Núcleo local sin clientes HTTP, cuentas ni telemetría. Recorrido completo con red denegada al proceso de prueba y observación sin sockets IP; falta Mac físicamente desconectado. No es una afirmación de App Sandbox. [Revisión][usability], [privacidad][privacy]. |
| SEG-02 | P0 | Implementado | SQL cerrado, escapes/operaciones tipadas, rutas locales protegidas y extensiones/sistemas remotos deshabilitados. Pruebas de inyección y rutas. [Pruebas][projecttests], [privacidad][privacy]. |
| SEG-03 | P0 | Implementado | Muestras/capturas sintéticas y exclusiones de datos/proyectos/builds. Debe revisarse de nuevo en cada publicación. [Normas][agents], [capturas][screenshots], [exclusiones][gitignore]. |
| SEG-04 | P0 | Implementado | Motor oficial fijado, licencia MIT y avisos incluidos en el bundle. Cualquier dependencia futura requiere otra revisión. [Avisos][notices], [integridad][integrity]. |

## 13. Rendimiento y cancelación

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| REN-01 | P0 | Parcial | Actor de datos, páginas acotadas y recorrido nativo funcional. Falta perfil de interacción bajo consultas largas para cerrar el criterio de respuesta. [Motor][engine], [rendimiento][performance]. |
| REN-02 | P1 | Parcial | Hay dos mediciones M1 de un millón de filas con cargas distintas; faltan repetición, diez páginas y p95. El objetivo <1 s no es una medición obtenida. [Rendimiento][performance]. |
| REN-03 | P1 | Pendiente | Sin estudio de CPU/energía en reposo, interacción/apertura de grafos grandes ni demora de cancelación bajo carga. Límite 512 MB de DuckDB no es límite total del proceso. [Rendimiento][performance], [límites][limits]. |

## 14. Verificación y distribución

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| VAL-01 | P0 | Implementado | 76 funciones en 16 suites release; referencias estadísticas y SIGKILL anteriores conservados. Casos nuevos de interfaz/modelo y regresión PDF reproducida antes del arreglo. [Salida][tests], [lote 2][usability]. |
| VAL-02 | P0 | Implementado | Recorrido real, exportaciones abiertas y límites anotados. No sustituye GRA-05, UX-02/04 o VAL-03. [Registro][validation], [evidencia nativa][native], [PDF][pdfsample]. |
| VAL-03 | P0 | Parcial | ZIP/suma/firma ad hoc y extracción limpia probados en M1/macOS 27.2; faltan otro Mac sin desarrollo y ejecución real en macOS 14. [Integridad][integrity], [release][release]. |
| VAL-04 | P1 | Pendiente | Developer ID y notarización no realizados. Requiere recursos/cuenta autorizados al programar ese lote. [Release][release]. |

## 15. Presentación pública y familia

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| PUB-01 | P0 | Implementado | Portada fotográfica 2:1 con logo propio y procedencia declarada; cabecera gráfica y portadas anteriores conservadas como antecedentes. [Familia][family], [marca][brand]. |
| PUB-02 | P0 | Implementado | README, capturas reales, ventajas por tarea y comparación con fuentes/límites; imagen del Mac en detalle promocional. [README][readme], [comparación][comparison]. |
| PUB-03 | P1 | Parcial | App, README y FUNDING apuntan al Ko-fi canónico sin avisos intrusivos; la herramienta web no pudo comprobar el destino externo en este lote. [Revisión][usability], [financiación][funding]. |
| PUB-04 | P1 | Implementado | Imagen/tarjeta y textos breve/detallado preparados. **No demuestra publicación en el sitio del autor**; esa actualización es una acción posterior distinta. [Texto breve][webshort], [detalle][webdetail], [procedencia de imágenes][promo]. |

## 16. Ampliaciones propuestas

| Código | Prioridad orientativa | Estado | Decisión pendiente |
| --- | --- | --- | --- |
| EXT-01 | P1 | Propuesto | Separar y priorizar XLSX y joins; definir hojas/claves/cardinalidad y compatibilidad. No hay implementación. |
| EXT-02 | P1 | Propuesto | Elegir qué pruebas/supuestos resuelven el próximo caso; no aprobar de una vez todos los candidatos. |
| EXT-03 | P1 | Propuesto | Elegir nuevas formas e intercambio independiente; evaluar biblioteca cuando esté definido el requisito, sin sustituir automáticamente Swift Charts. |
| EXT-04 | P2 | Propuesto | Definir marcadores especiales, grupos y reutilización de recetas; no ejecutar código arbitrario. |

## Qué queda por hacer primero

| Lote propuesto | Requisitos | Resultado esperado para revisar |
| --- | --- | --- |
| 1. Integridad y decisiones visibles — entregado | PRY-05, IMP-04, EDT-03, FLU-07, INF-04 | Implementado y comprobado dentro del [alcance del lote 1](INTEGRITY-STAGE.md). Continúa el lote 2. |
| 2. Terminar de pulir el uso real — entrega preliminar y calificaciones abiertas | UX-01 a UX-05, GRA-02, GRA-05, SEG-01, VAL-03 | Entregadas navegación, traducción de interfaz, HEX y figuras PDF; [evidencia][usability]. Quedan VoiceOver, matriz visual, informes por idioma, desconexión física y otro Mac. |
| 3. Trabajo diario y entrega | DAT-04/05, EDT-04, CAL-03/04, EST-08, INF-05, PUB-03 | Metadatos y comparación, orden descendente visible, evidencia revisable, orientación y perfiles en ambos informes; enlaces coherentes. |
| 4. Medir antes de ampliar | PRY-06, REN-02/03, UX-06 | Coste de versiones, medidas repetibles y tropiezos de usuarios; decidir después FLU-08 y EXT-01 a EXT-04. |

El autor autorizó continuar con la siguiente etapa el 2 de noviembre; se entregó el lote 1. El autor autorizó el lote 2 a continuación. Su entrega preliminar no cierra las calificaciones externas ni la matriz completa; los lotes siguientes y las ampliaciones conservan su alcance pendiente. No se abren issues automáticamente por actualizar la matriz.

## Condiciones para cerrar una fila

1. Cumplir el criterio de [REQUIREMENTS.md](REQUIREMENTS.md) dentro de un alcance explícito.
2. Registrar versión, comprobación y resultado proporcionados al riesgo; enlazar evidencia real.
3. Corregir limitaciones y documentación si cambió el comportamiento. Conservar registros históricos con su fecha.
4. Actualizar esta matriz sin convertir pruebas del núcleo en afirmaciones de interfaz, seguridad o compatibilidad no verificadas.

[tests]: evidence/test-polish-release.txt
[validation]: VALIDATION.md
[numerical]: STATISTICAL-VALIDATION.md
[native]: evidence/integrated-native-review.json
[screenshots]: screenshots/README.md
[pdfsample]: evidence/VAPULA-flujo-final.pdf
[integrity]: evidence/bundle-integrity-0.1.2.json
[release]: RELEASE-0.1.2.md
[limits]: LIMITATIONS.md
[projecttests]: ../Tests/VapulaTests/ProjectDataTests.swift
[workflowtests]: ../Tests/VapulaTests/WorkflowExecutionTests.swift
[cleaningtests]: ../Tests/VapulaTests/CleaningTests.swift
[statstests]: ../Tests/VapulaTests/StatisticsTests.swift
[expandedtests]: ../Tests/VapulaTests/ExpandedStatisticsTests.swift
[expandedworkflow]: ../Tests/VapulaTests/ExpandedWorkflowTests.swift
[pdftests]: ../Tests/VapulaTests/PDFReportTests.swift
[workbench]: ../Sources/VapulaApp/WorkbenchView.swift
[canvas]: ../Sources/VapulaApp/WorkbenchCanvas.swift
[graph]: ../Sources/VapulaCore/DataWorkflow.swift
[execution]: ../Sources/VapulaData/WorkflowExecution.swift
[workflowui]: ../Sources/VapulaApp/Workspace+Workflow.swift
[inspector]: ../Sources/VapulaApp/WorkbenchInspector.swift
[chartpanel]: ../Sources/VapulaApp/ChartStylePanel.swift
[chartmodel]: ../Sources/VapulaCore/ChartConfiguration.swift
[engine]: ../Sources/VapulaData/DataEngine.swift
[grid]: ../Sources/VapulaApp/DataGrid.swift
[queries]: ../Sources/VapulaData/Queries.swift
[datamodel]: DATA-MODEL.md
[preparation]: ../Sources/VapulaApp/PreparationView.swift
[editing]: ../Sources/VapulaApp/DataEditingView.swift
[missingui]: ../Sources/VapulaApp/MissingValuesView.swift
[quality]: ../Sources/VapulaData/Quality.swift
[analysispresentation]: ../Sources/VapulaCore/AnalysisPresentation.swift
[statisticsui]: ../Sources/VapulaApp/StatisticsView.swift
[charts]: CHARTS.md
[chartrenderer]: ../Sources/VapulaApp/StatisticalChartView.swift
[pdfdocs]: PDF-EXPORT.md
[reportui]: ../Sources/VapulaApp/Workspace+Reporting.swift
[workspace]: ../Sources/VapulaApp/Workspace.swift
[commands]: ../Sources/VapulaApp/VapulaApp.swift
[reports]: ../Sources/VapulaReports/Reports.swift
[privacy]: PRIVACY.md
[agents]: ../AGENTS.md
[gitignore]: ../.gitignore
[notices]: ../THIRD_PARTY_NOTICES.md
[performance]: PERFORMANCE.md
[family]: FAMILY.md
[brand]: BRAND.md
[readme]: ../README.md
[comparison]: COMPARISON.md
[legacy]: ../Sources/VapulaApp/ContentView.swift
[funding]: ../.github/FUNDING.yml
[webshort]: website/VAPULA.md
[webdetail]: website/VAPULA-detalle.md
[promo]: assets/promo/README.md

[integritystage]: INTEGRITY-STAGE.md
[sessiontests]: ../Tests/VapulaTests/Data/ProjectSessionTests.swift
[importdiagnostic]: ../Sources/VapulaCore/ImportDiagnostic.swift
[importtests]: ../Tests/VapulaTests/Data/ImportFailureTests.swift
[casttests]: ../Tests/VapulaTests/Data/CastPreviewTests.swift
[draftmodel]: ../Sources/VapulaCore/InspectorDrafts.swift
[reportselection]: ../Sources/VapulaReports/ReportSelection.swift
[selectiontests]: ../Tests/VapulaTests/Reports/ReportSelectionTests.swift

[usability]: USABILITY-STAGE.md
[polishpdf]: evidence/usabilidad-final.pdf
[uitext]: ../Sources/VapulaCore/Resources/Interface.en.json
