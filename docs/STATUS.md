# VAPULA — Estado de los requerimientos

**Corte:** 1 de noviembre de 2026, America/Santiago.

**Línea base:** [REQUIREMENTS.md v1.0](REQUIREMENTS.md).

**Aplicación pública:** [0.1.0 preliminar](https://github.com/AD0441/VAPULA/releases/tag/v0.1.0), fuentes del paquete en [`3c9d2a6`](https://github.com/AD0441/VAPULA/commit/3c9d2a69c7668cca7591c5b63e59c7b695a09f6e).

**Documentación/identidad revisada:** [`7caa136`](https://github.com/AD0441/VAPULA/commit/7caa1364daf87f4d4e480924c399bae8f79ea4fd), incorporando después este inventario.

Se revisaron el repositorio, las pruebas existentes y la evidencia registrada. Esta entrega organiza requisitos y estado; no añade funciones ni ejecuta de nuevo las pruebas de la aplicación. El corte permite distinguir lo que vimos, lo que mejoramos y lo que falta, siguiendo la separación usada en [NABERIUS](https://github.com/AD0441/NABERIUS/blob/main/docs/STATUS.md).

## Cómo interpretar el estado

| Estado | Significado |
| --- | --- |
| Implementado | La capacidad existe en el alcance descrito y tiene evidencia identificada. No implica auditoría de todas las variantes. |
| Parcial | Existe una base, pero falta parte del comportamiento o de la aceptación escrita. La fila explica qué. |
| Pendiente | Falta la capacidad descrita o su cierre verificable. |
| Propuesto | Ampliación sin alcance aprobado; requiere priorización antes de implementarse. |

P0/P1/P2 expresan prioridad, no aprobación de una propuesta. Los orígenes C/B/D/P están definidos en la especificación. **La release 0.1.0 no cierra todos los P0.** Las pruebas automatizadas no sustituyen una auditoría de teclado/VoiceOver, una comprobación en otro Mac ni una revisión visual exhaustiva.

| Prioridad | Implementado | Parcial | Pendiente | Propuesto | Total |
| --- | --- | --- | --- | --- | --- |
| P0 | 45 | 15 | 0 | 0 | 60 |
| P1 | 2 | 10 | 7 | 4 | 23 |
| P2 | 0 | 0 | 0 | 1 | 1 |
| **Total** | **47** | **25** | **7** | **5** | **84** |

Son cantidades de requisitos, con tamaños distintos; no un porcentaje de avance ni una estimación de esfuerzo. Los 15 P0 parciales señalan trabajo de consolidación pendiente.

## Evidencia disponible y sus límites

- **Núcleo e integración:** 53 funciones Swift Testing en nueve suites, ejecutadas en release; incluyen persistencia, edición, ausentes, ejecución del grafo e informes. [Salida final][tests], [registro de validación][validation]. Es un registro previo, no una nueva ejecución de esta entrega documental.
- **Estadística:** 1.356 valores escalares de referencia independientes, con definiciones y tolerancias. No equivalen a 1.356 pruebas visuales. [Validación estadística][numerical].
- **Aplicación real:** importación de 31 filas sintéticas, relleno por media, corrección versionada, adición/retirada de filas y columna, descriptivos, histograma, PDF/MD, reapertura, movimiento y quitar/deshacer rama. [Registro nativo][native], [capturas reales][screenshots], [PDF final][pdfsample]. No se revisaron todas las combinaciones de métodos, estilos, idiomas y temas.
- **Distribución:** ZIP arm64, SHA-256, extracción limpia, firma estricta ad hoc y comparación de 36 archivos. [Integridad][integrity], [notas de release][release]. No hay Developer ID/notarización ni calificación en otro Mac/macOS mínimo.
- **CI:** ejecuciones satisfactorias de [main del código publicado](https://github.com/AD0441/VAPULA/actions/runs/41325036372), [tag 0.1.0](https://github.com/AD0441/VAPULA/actions/runs/41325199928) y [documentación de familia](https://github.com/AD0441/VAPULA/actions/runs/41332703840). CI no demuestra accesibilidad ni compatibilidad visual con todos los sistemas.

## 1. Proyecto, versiones y recuperación

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| PRY-01 | P0 | Implementado | Crear/abrir/cerrar, datos materializados y reapertura portable en integración; otro Mac se califica en VAL-03. [Pruebas de proyecto][projecttests]. |
| PRY-02 | P0 | Implementado | Versiones físicas y procedencia; hash original intacto en integración y revisión nativa. [Pruebas][projecttests], [revisión][validation]. |
| PRY-03 | P0 | Implementado | Manifiesto atómico y prueba de fallo de escritura sin versión parcial referenciada. Una tabla huérfana tras caída sigue siendo posible. [Pruebas][projecttests], [límites][limits]. |
| PRY-04 | P0 | Implementado | Compatibilidad aditiva de esquema 1 sin flujo y rechazo de esquema futuro. No existe un marco general de migraciones ni lectura por binarios antiguos. [Pruebas][projecttests], [grafo][workflowtests]. |
| PRY-05 | P0 | Parcial | Modelo de un escritor y guardas de base de datos; faltan diálogo de conflicto, ensayos sistemáticos de cierre forzado y recuperación guiada. [Límites][limits]. |
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
| FLU-07 | P0 | Parcial | Ejecución y estilos aplicados son explícitos; falta conservar o resolver todos los borradores al cambiar de caja. [Inspector][inspector], [gráficos][chartpanel]. |
| FLU-08 | P1 | Propuesto | Nombres/notas, duplicado, selección múltiple y rehacer requieren selección de alcance; no se presentan como disponibles. |

## 3. Importación

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| IMP-01 | P0 | Implementado | CSV/TSV/Parquet, vista previa y parámetros manuales; ejemplos regionales/BOM probados. [Pruebas][projecttests], [motor][engine]. |
| IMP-02 | P0 | Implementado | UTF-8/BOM y rechazo explícito de otras codificaciones. El diagnóstico aún necesita traducción completa en UX-04. [Motor][engine]. |
| IMP-03 | P0 | Implementado | Materialización en el paquete y reapertura sin referencia externa; no hay modo de enlace ni copia cruda opcional. [Pruebas][projecttests]. |
| IMP-04 | P0 | Parcial | Hay errores de importación y opciones para corregir lectura; falta normalizar mensajes con columna/fila/ejemplos y orientación, sin detalles SQL internos. [Motor][engine], [límites][limits]. |
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
| EDT-03 | P0 | Parcial | TRY_CAST avisa que puede producir NULL y pide revisar el perfil; faltan conteo específico y ejemplos de pérdidas antes de aceptar. [Límites][limits], [preparación][preparation]. |
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
| GRA-02 | P0 | Parcial | Seis opciones de paleta contando la personalizada, selector/HEX y estilos persistidos. Un HEX inválido vuelve silenciosamente al color predeterminado; falta el diagnóstico explícito del criterio. [Panel][chartpanel], [normalización][chartmodel], [pruebas][expandedworkflow]. |
| GRA-03 | P0 | Implementado | Límites y definiciones explícitos: 2.000 pares, top 30, histograma y caja; atípicos de caja contados, sin puntos dibujados. [Gráficos][charts], [límites][limits]. |
| GRA-04 | P0 | Implementado | Parámetros por caja/versión; cache se regenera al ejecutar tras reabrir. Vista identifica tipo/variables realmente aplicados. [Revisión][validation], [controlador][workflowui]. |
| GRA-05 | P0 | Parcial | Correcciones verificadas de intervalos, títulos y figura PDF; falta matriz completa de ocho formas × temas × casos × exportaciones. [Revisión][validation], [PDF][pdfsample]. |
| GRA-06 | P1 | Parcial | Colores/símbolos configurables; no hay auditoría de contraste, deficiencias de visión cromática ni lectura completa de gráficos con VoiceOver. [Panel][chartpanel], [renderizador][chartrenderer]. |

## 10. Informes e intercambio

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| INF-01 | P0 | Implementado | PDF de texto vectorial, tablas paginadas y figuras PNG; Unicode, pies, selección y páginas largas probados/renderizados. Figuras raster, no vectoriales. [PDF][pdfdocs], [pruebas][pdftests], [muestra][pdfsample]. |
| INF-02 | P0 | Implementado | MD y PNG con referencias relativas; exportación nativa y protección de sidecars comprobadas. Los archivos asociados deben viajar juntos. [Pruebas][pdftests], [revisión][validation]. |
| INF-03 | P0 | Implementado | Informe del flujo con salidas alcanzables, procedencia y máximo 32 figuras; rechazo de referencias ajenas. [Puente de exportación][reportui], [pruebas][pdftests]. |
| INF-04 | P0 | Parcial | La caja exporta su selección; el atajo general conserva una ruta global heredada. Falta unificar o explicar inequívocamente su alcance. [Puente][reportui], [espacio de trabajo][workspace], [comandos][commands]. |
| INF-05 | P1 | Parcial | MD global admite perfiles; la caja Informe no los pasa y PDF no ofrece esas tablas. Falta paridad PDF/MD desde el flujo. [Informes][reports], [puente][reportui]. |
| INF-06 | P0 | Implementado | CSV/Parquet de datos, CSV de resultados y destinos protegidos; pruebas de fallo/rollback y figuras existentes. [Pruebas de datos][projecttests], [pruebas de informes][pdftests]. |

## 11. Diseño y uso de macOS

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| UX-01 | P0 | Parcial | Maqueta y recorrido integrados, controles ajustados tras revisión; falta auditoría visual sistemática y evaluación de claridad del flujo completo. [Revisión][validation], [capturas][screenshots]. |
| UX-02 | P0 | Parcial | Controles/comandos nativos y lectura AX acotada; recorrido completo por teclado, conexiones y VoiceOver aún no certificado. [Validación][validation]. |
| UX-03 | P0 | Parcial | Colores semánticos y apariencia configurable; ventana mínima declarada 1060×700. Faltan recorridos exhaustivos en mínimo/oscuro/contenido largo. [Comandos/ventana][commands], [validación][validation]. |
| UX-04 | P0 | Parcial | Catálogos ES/EN y selector; quedan textos técnicos, mensajes dinámicos y etiquetas fijas mezcladas. [Límites][limits], [interfaz][workbench]. |
| UX-05 | P0 | Parcial | Inicio, validaciones y algunos mensajes accionables; faltan normalización y revisión de fallos/cancelación/recuperación de extremo a extremo. [Validación][validation], [límites][limits]. |
| UX-06 | P1 | Pendiente | No existe todavía estudio registrado de tres recorridos con usuarios ni cierre de tropiezos medidos. Las decisiones de la maqueta no sustituyen esa observación. |

## 12. Privacidad y seguridad

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| SEG-01 | P0 | Parcial | Núcleo sin clientes HTTP/cuentas/telemetría; observación de reposo sin sockets IP. Falta recorrido completo con red desconectada; no se afirma aislamiento App Sandbox. [Privacidad][privacy]. |
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
| VAL-01 | P0 | Implementado | Suite release y referencias independientes registradas, también CI del código publicado. No se repitió por cambios solo documentales. [Salida][tests], [referencias][numerical]. |
| VAL-02 | P0 | Implementado | Recorrido real, exportaciones abiertas y límites anotados. No sustituye GRA-05, UX-02/04 o VAL-03. [Registro][validation], [evidencia nativa][native], [PDF][pdfsample]. |
| VAL-03 | P0 | Parcial | ZIP/suma/firma ad hoc y extracción limpia probados en M1/macOS 27.2; faltan otro Mac sin desarrollo y ejecución real en macOS 14. [Integridad][integrity], [release][release]. |
| VAL-04 | P1 | Pendiente | Developer ID y notarización no realizados. Requiere recursos/cuenta autorizados al programar ese lote. [Release][release]. |

## 15. Presentación pública y familia

| Código | Prioridad | Estado | Cobertura real y pendiente |
| --- | --- | --- | --- |
| PUB-01 | P0 | Implementado | Cabecera oscura 2:1 de familia y sello propio; anteriores portadas conservadas como antecedentes. [Familia][family], [marca][brand]. |
| PUB-02 | P0 | Implementado | README, capturas reales, ventajas por tarea y comparación con fuentes/límites; imagen del Mac en detalle promocional. [README][readme], [comparación][comparison]. |
| PUB-03 | P1 | Parcial | README/FUNDING usan Ko-fi canónico; dos enlaces de la app aún usan `ko-fi.com/sebastianpasten`. Falta unificar/verificar destino sin introducir avisos intrusivos. [Interfaz][workbench], [vista heredada][legacy], [financiación][funding]. |
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
| 1. Integridad y decisiones visibles | PRY-05, IMP-04, EDT-03, FLU-07, INF-04 | Recuperación/conflictos comprensibles, pérdidas de conversión cuantificadas, borradores protegidos y exportación sin ambigüedad. |
| 2. Terminar de pulir el uso real | UX-01 a UX-05, GRA-02, GRA-05, SEG-01, VAL-03 | Recorridos con teclado/VoiceOver, idiomas/temas/ventana mínima, colores inválidos, ocho gráficos, uso desconectado y paquete en otro Mac. |
| 3. Trabajo diario y entrega | DAT-04/05, EDT-04, CAL-03/04, EST-08, INF-05, PUB-03 | Metadatos y comparación, orden descendente visible, evidencia revisable, orientación y perfiles en ambos informes; enlaces coherentes. |
| 4. Medir antes de ampliar | PRY-06, REN-02/03, UX-06 | Coste de versiones, medidas repetibles y tropiezos de usuarios; decidir después FLU-08 y EXT-01 a EXT-04. |

No se abren issues ni se implementan estas propuestas automáticamente por publicar la matriz. El orden es una recomendación de trabajo, revisable por el autor.

## Condiciones para cerrar una fila

1. Cumplir el criterio de [REQUIREMENTS.md](REQUIREMENTS.md) dentro de un alcance explícito.
2. Registrar versión, comprobación y resultado proporcionados al riesgo; enlazar evidencia real.
3. Corregir limitaciones y documentación si cambió el comportamiento. Conservar registros históricos con su fecha.
4. Actualizar esta matriz sin convertir pruebas del núcleo en afirmaciones de interfaz, seguridad o compatibilidad no verificadas.

[tests]: evidence/test-integrated-release-final.txt
[validation]: VALIDATION.md
[numerical]: STATISTICAL-VALIDATION.md
[native]: evidence/integrated-native-review.json
[screenshots]: screenshots/README.md
[pdfsample]: evidence/VAPULA-flujo-final.pdf
[integrity]: evidence/bundle-integrity-integrated.json
[release]: RELEASE-0.1.0.md
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
