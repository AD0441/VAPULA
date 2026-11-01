# VAPULA — Requerimientos del producto

**Versión de la especificación:** 1.0 · **Fecha:** 1 de noviembre de 2026, America/Santiago.

**Producto:** VAPULA · preparación, estadística y presentación de datos para macOS.

**Autor:** Sebastián Pastén F. · **Eslogan:** De los datos a la evidencia.

> **Propósito:** recorrer una pregunta desde los datos originales hasta un resultado revisable, mediante cajas conectadas, controles comprensibles y procesamiento local. Simplicidad con impacto. Concéntrate en lo que vale la pena.

## 0. Cómo leer esta línea base

Consolida lo conversado, lo construido y lo que todavía debemos resolver. Toma de [NABERIUS](https://github.com/AD0441/NABERIUS/blob/main/docs/REQUIREMENTS.md) la organización por decisiones, requisitos, prioridades y aceptación; conserva el propósito, formato y arquitectura propios de VAPULA.

La cobertura real está en [STATUS.md](STATUS.md), separada de esta especificación. **La publicación preliminar 0.1.0 no certifica el cumplimiento de todos los P0.** Este inventario tampoco autoriza por sí solo a implementar todas las ampliaciones: las propuestas requieren priorización del autor.

| Etiqueta | Significado |
| --- | --- |
| P0 | Consolidar la base indispensable: integridad, recorrido principal y uso comprensible. |
| P1 | Siguiente mejora de productividad o calidad; no bloquea por sí sola la versión preliminar existente. |
| P2 | Evolución posterior, sujeta a alcance y recursos. |
| C | Decisión explícita de la conversación: flujo sencillo, más opciones, edición/ausentes, gráficos, exportación o presentación. |
| B | Base del encargo original o capacidad ya incorporada al proyecto. |
| D | Requisito de cierre derivado de una limitación observada; propuesta de trabajo técnico que debe priorizarse. |
| P | Ampliación de producto propuesta, aún sin aprobación de alcance ni solución técnica. |

La prioridad expresa importancia, no estado. Un requisito puede estar implementado, parcial, pendiente o propuesto. Una imagen promocional, una maqueta o un botón sin comportamiento no demuestra cumplimiento. Los criterios siguientes describen qué verificar, aunque esa verificación todavía esté pendiente.

## 1. Decisiones confirmadas

| Código | Decisión |
| --- | --- |
| D-01 | Aplicación nativa para macOS, priorizando Apple Silicon; SwiftUI y puentes AppKit acotados. |
| D-02 | Un proyecto portable `.vapula` reúne datos, versiones, flujo y resultados. Las vistas de datos y estadística comparten ese modelo. |
| D-03 | Procesamiento local, sin cuenta, IA en línea, telemetría ni instalación de Python/R para utilizar la aplicación. |
| D-04 | Las fuentes no se modifican. Cada transformación satisfactoria produce una versión física nueva con procedencia. |
| D-05 | Un escritorio de cajas conectadas, inspirado en la claridad de los flujos de KNIME, con un catálogo más acotado y controles propios. |
| D-06 | Mantener la maqueta aceptada: barra con iconos, fuentes/historial a la izquierda, lienzo central, inspector derecho y salidas debajo. |
| D-07 | Siete familias: importar, preparar, ausentes, calidad, análisis, gráficos e informes. Las opciones aparecen según el contexto. |
| D-08 | Corregir y completar datos de forma explícita: edición, filas/columnas y elección entre media, mediana, moda, constante o retirada de observaciones. |
| D-09 | Ampliar estadística y diseño de gráficos conservando sencillez. La base actual tiene diez métodos y ocho formas; no implica aprobar todo método futuro. |
| D-10 | Exportar resultados en PDF real y Markdown con figuras y procedencia, además de los intercambios tabulares disponibles. |
| D-11 | Repositorio público MIT, capturas reales y apoyo voluntario en Ko-fi. La autorización posterior de publicación sustituyó la preferencia inicial de mantenerlo local. |
| D-12 | Identidad de familia con METATRON, NABERIUS, RAZIEL y PAIMON: portada oscura cuidada, sello propio y autoría común. La imagen del Mac permanece en el detalle. Véase [FAMILY.md](FAMILY.md). |
| D-13 | Ventajas concretas y límites explícitos. Ninguna promesa de superioridad universal, exactitud o rendimiento se deduce de la portada o del lenguaje usado. |

## 2. Lo que vimos y mejoramos

| Punto de partida o hallazgo | Evolución que debe conservarse |
| --- | --- |
| Primera versión percibida como pobre en pruebas y presentación. | Diez métodos, referencias numéricas independientes, ocho gráficos, estilos y exportación PDF/MD. |
| Formato tosco y recorrido poco intuitivo. | Maqueta nativa aceptada y luego lienzo ejecutable de cajas, inspector contextual y salidas conectadas. |
| Faltaban decisiones sobre datos incompletos y correcciones. | Vista previa del impacto, políticas de ausentes, imputación, eliminación y edición mediante versiones. |
| Había que relacionar preparación, análisis y entrega. | Ejecución selectiva, invalidación de descendientes e informe con resultados y gráficos del flujo. |
| La revisión real mostró cortes de controles y títulos duplicados. | Controles adaptables, navegación al nodo seleccionado y una sola cabecera en las figuras exportadas. |
| La presentación pública debía seguir la filosofía de METATRON. | README de familia, portada oscura, capturas sintéticas reales, explicación de ventajas, comparación con límites y Ko-fi. |

Esto describe la evolución; el alcance efectivamente verificado y sus evidencias están en [STATUS.md](STATUS.md) y [VALIDATION.md](VALIDATION.md).

## 3. Usuarios, recorridos y límites

Usuarios principales: docentes e investigadores que preparan tablas y contrastan preguntas generales; estudiantes que deben comprender y documentar sus decisiones; profesionales que necesitan revisar datos locales y entregar resultados.

Recorrido principal: **crear/abrir → importar y perfilar → preparar/corregir → revisar calidad → analizar y graficar → exportar y reabrir**. Debe ser posible ramificar una comparación conservando la entrada y reconocer qué versión produjo cada salida.

Fuera del alcance vigente: plataforma universal de ciencia de datos, ejecución arbitraria de SQL/código o plugins, colaboración simultánea, nube obligatoria, IA, todos los formatos y todos los métodos de KNIME/R/Python. Las ampliaciones propuestas al final no modifican automáticamente estos límites.

## 4. Proyecto, versiones y recuperación

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| PRY-01 | P0 · B | Crear, abrir y cerrar proyectos `.vapula` portables con datos, flujo y resultados. | Cerrar, copiar el paquete y reabrir sin depender de la ruta original de importación; conservar valores y referencias. |
| PRY-02 | P0 · C | Conservar fuentes y versiones físicas inmutables con procedencia. | Comparar el SHA-256 de la fuente antes/después; una transformación crea otra versión y la anterior sigue consultable. |
| PRY-03 | P0 · B | Guardar metadatos atómicamente y no publicar versiones incompletas. | Un fallo de consulta o escritura no deja una versión parcial referenciada por el manifiesto. |
| PRY-04 | P0 · B | Reconocer la versión del formato y los casos compatibles. | Abrir los proyectos antiguos de esquema 1 sin flujo y rechazar un esquema futuro con un diagnóstico; no prometer lectura por binarios antiguos. |
| PRY-05 | P0 · D | Resolver aperturas simultáneas y recuperación tras cierre forzado con mensajes útiles. | Ensayar dos instancias y cierres en importación/transformación/guardado; al reabrir, identificar estado válido y ofrecer una salida sin pérdida silenciosa. |
| PRY-06 | P1 · D | Hacer visible el coste de almacenar versiones y preparar mantenimiento seguro. | Mostrar tamaño/espacio requerido antes de operaciones costosas; cualquier limpieza conserva versiones referenciadas y requiere una elección explícita. |

## 5. Lienzo y ejecución del flujo

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| FLU-01 | P0 · C | Añadir cajas desde una barra compacta con las siete familias. | Completar el recorrido principal desde el lienzo, con inspector contextual y pestañas Datos/Resultado/Gráfico/Informe. |
| FLU-02 | P0 · C | Mover cajas, desplazar, ampliar y encuadrar el lienzo; conservar su organización. | Guardar/reabrir mantiene posiciones y configuración; seleccionar una fuente permite encontrar su caja. |
| FLU-03 | P0 · B | Validar conexiones tipadas y un grafo sin ciclos. | Rechazar ciclos, puertos incompatibles, identidades duplicadas y referencias ajenas antes de ejecutar. |
| FLU-04 | P0 · B | Ejecutar el flujo pendiente o los antecesores del paso elegido e invalidar descendientes. | Cambiar una preparación obliga a recalcular sus salidas dependientes, conservando ramas independientes. |
| FLU-05 | P0 · B | Mostrar fases, fallo y cancelación sin perder pasos ya completados. | Un fallo aguas abajo conserva versiones válidas previas; cancelar impide el siguiente compromiso de datos y explica la espera por la consulta activa. |
| FLU-06 | P0 · C | Quitar una rama del lienzo y deshacer sin borrar el historial físico. | Quitar y deshacer restaura el grafo; las versiones anteriores siguen disponibles y no se presentan como eliminadas del disco. |
| FLU-07 | P0 · D | Distinguir parámetros editados, guardados y realmente ejecutados. | Cambiar de caja con un formulario pendiente conserva el borrador o pide una decisión; ninguna salida antigua aparenta usar parámetros nuevos. |
| FLU-08 | P1 · P | Evaluar nombres/notas, duplicado, selección múltiple y rehacer para flujos repetitivos. | Priorizar cada acción y demostrar un recorrido más corto sin saturar la barra ni alterar referencias del grafo. |

## 6. Importación

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| IMP-01 | P0 · B | Vista previa de CSV, TSV y Parquet antes de importar. | Revisar cabecera, delimitador, decimal, fecha y opción de texto; la importación final utiliza los parámetros elegidos. |
| IMP-02 | P0 · B | Aceptar UTF-8 con/sin BOM e informar codificaciones no soportadas. | Abrir ejemplos regionales válidos y rechazar entradas no UTF-8 con una explicación que permita corregir el archivo. |
| IMP-03 | P0 · B | Materializar la fuente seleccionada dentro del proyecto. | Tras cerrar y retirar la fuente externa, el proyecto mantiene sus datos importados. |
| IMP-04 | P0 · D | Diagnosticar la ubicación y causa de fallos de lectura o conversión. | Un archivo problemático señala columna/fila o muestra disponible y el parámetro a revisar; no obliga a interpretar una consulta interna. |
| IMP-05 | P1 · D | Explicar antes de importar las restricciones de anchura, rutas y almacenamiento. | Avisar del máximo de 256 columnas, rutas no admitidas y materialización; no iniciar un trabajo que ya se sabe incompatible. |

## 7. Tabla, perfiles y metadatos

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| DAT-01 | P0 · B | Tabla paginada con búsqueda y ordenación en el motor. | Navegar sin cargar toda la tabla en la interfaz; buscar/ordenar mantiene una página válida y la identidad de las filas. |
| DAT-02 | P0 · B | Perfiles numéricos y categóricos del conjunto completo. | Presentar válidos/ausentes/no finitos, distintos y resúmenes pertinentes; no calcular el perfil solo con la página visible. |
| DAT-03 | P0 · C | Acceder al historial y reconocer la versión activa. | Seleccionar entrada y versión corregida muestra valores diferentes, nombre y procedencia coherentes. |
| DAT-04 | P1 · D | Editar metadatos de variables: escala, unidad y función, sin confundirlos con el tipo físico. | Guardar/reabrir conserva metadatos y los muestra en perfiles e informes; una escala desconocida permanece explícita. |
| DAT-05 | P1 · D | Comparar entrada y salida de una transformación. | Mostrar filas/columnas afectadas y diferencias relevantes sin reemplazar la entrada ni exigir comparar archivos a mano. |

## 8. Preparación y edición

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| EDT-01 | P0 · B | Filtrar, seleccionar/renombrar columnas, convertir tipos y derivar aritmética con parámetros tipados. | Cada operación guarda parámetros reproducibles y crea otra versión; los nombres/textos nunca ejecutan código. |
| EDT-02 | P0 · C | Corregir celdas, añadir filas/columnas y retirar filas identificadas. | Tras buscar/ordenar, editar actúa sobre la fila original correcta; tipos y valores se validan antes de guardar. |
| EDT-03 | P0 · D | Contabilizar y explicar pérdidas al convertir tipos. | Antes de aceptar una conversión con valores no convertibles, mostrar cantidad y ejemplos de nuevos NULL y permitir conservar la versión previa. |
| EDT-04 | P1 · B | Ordenar versiones en ambos sentidos y agregar por grupos. | Elegir ascendente/descendente en la preparación y obtener count/mean/sum/min/max con grupos verificables. |
| EDT-05 | P1 · C | Hacer comprensible añadir o retirar columnas sin perder el origen. | Seleccionar columnas que conservar, añadir una tipada y revisar la nueva estructura; impedir una tabla sin columnas. |

## 9. Valores ausentes

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| AUS-01 | P0 · C | Política visible: NULL y elección de texto vacío/espacios o NaN/infinito. | Los conteos y las acciones usan exactamente la política seleccionada y las columnas indicadas. |
| AUS-02 | P0 · C | Mostrar el impacto antes de actuar. | Informar celdas por columna y unión de filas afectadas, evitando contar una fila varias veces. |
| AUS-03 | P0 · C | Completar por media, mediana o moda de los valores observados. | Verificar resultados y desempate determinista; una columna totalmente ausente falla sin inventar una estimación. |
| AUS-04 | P0 · C | Completar con constante validada y retirar filas/columnas afectadas. | Rechazar constantes incompatibles y eliminación de todas las columnas; conservar la fuente como versión anterior. |
| AUS-05 | P0 · C | Registrar la decisión de imputación y advertir su efecto sobre análisis posteriores. | Procedencia, columnas y método acompañan las salidas; advertir cambios en dispersión/asociaciones y ausencia de ajuste de incertidumbre. |
| AUS-06 | P1 · D | Explicar promociones de tipo y precisión al imputar. | Antes de media/mediana, avisar de conversión a DOUBLE y riesgo para enteros grandes; la moda conserva valores exactos cuando corresponde. |

## 10. Calidad de datos

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| CAL-01 | P0 · B | Revisar ausentes, no finitos, claves duplicadas, rangos e IQR. | Cada regla informa conteo, versión, parámetros y ejemplos reproducibles. |
| CAL-02 | P0 · B | Separar hallazgo de corrección. | Un candidato IQR o duplicado no se elimina automáticamente ni se presenta como error confirmado. |
| CAL-03 | P1 · D | Revisar y exportar evidencia de hallazgos más allá de la muestra visual. | Identificar el límite de 100 ejemplos y ofrecer una salida completa o una selección documentada para revisión externa. |
| CAL-04 | P1 · D | Detectar inconsistencias de tipo con evidencia interpretable. | Señalar valores incompatibles con el tipo esperado y permitir decidir si corregir, convertir o conservar. |

## 11. Estadística y resultados

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| EST-01 | P0 · C | Mantener diez métodos generales: descriptivos, t de una muestra, t pareada, Pearson, Spearman, Welch, ANOVA de un factor, Mann–Whitney, chi-cuadrado y regresión lineal simple. | Elegir variables apropiadas, ejecutar y recuperar resultados del método y versión declarados. |
| EST-02 | P0 · B | Validar entradas, tamaños, finitud, constantes y límites de cálculo. | Casos degenerados explican por qué no se estima; exceder 200.000 filas en análisis materializados se rechaza, sin muestreo silencioso. |
| EST-03 | P0 · B | Presentar hipótesis, supuestos, n válido y exclusiones. | El resultado distingue variable/grupo/parámetros y no convierte asociación o significación en causalidad. |
| EST-04 | P0 · B | Definir tamaños de efecto, intervalos y salidas según el método realmente implementado. | Contrastar con referencias; no anunciar p para Pearson/Spearman, exactitud para Mann–Whitney ni post-hoc para ANOVA. |
| EST-05 | P0 · B | Estimar regresión simple con procedimientos numéricos estables. | Casos de escala/constantes y referencias verifican pendiente, intercepto, R² y errores disponibles sin invertir matrices innecesarias. |
| EST-06 | P1 · D | Añadir diagnósticos y salidas de regresión que hoy faltan. | Ofrecer residuos exportables, gráficos diagnósticos e intervalos de coeficientes, con definición y referencias independientes. |
| EST-07 | P0 · C | Conservar resultados legibles con procedencia y exportación selectiva. | Reabrir mantiene métricas/parámetros; exportar un resultado no añade análisis ajenos. |
| EST-08 | P1 · D | Ayudar a elegir una prueba sin automatizar una conclusión injustificada. | Explicar propósito, tipo de variable, diseño y límites desde el inspector; probar comprensión con recorridos concretos. |

## 12. Gráficos y personalización

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| GRA-01 | P0 · C | Ocho formas: histograma, barras verticales/horizontales, dispersión, línea, área, caja y lollipop. | Cada caja usa variables compatibles y presenta datos de su versión ejecutada. |
| GRA-02 | P0 · C | Personalizar paleta/color, títulos, ejes, cuadrícula, símbolos, tamaño y trazo. | Guardar/reabrir conserva las opciones aplicables; HEX inválido recibe un diagnóstico y el estilo no altera resultados. |
| GRA-03 | P0 · B | Explicar cobertura, agregación y límites de representación. | Declarar primeros 2.000 pares, top 30, intervalos del histograma y criterio de caja; no llamarlos muestra representativa. |
| GRA-04 | P0 · C | Conservar parámetros del gráfico y regenerar la vista sin confundir borradores. | Reabrir permite recalcular; etiquetas y figura corresponden a la configuración ejecutada, no al formulario pendiente. |
| GRA-05 | P0 · D | Verificar legibilidad y consistencia de las ocho formas en pantalla y exportación. | Revisar títulos largos, vacíos, valores extremos, colores, modo claro/oscuro y figuras exportadas sin cortes ni títulos repetidos. |
| GRA-06 | P1 · D | Ofrecer opciones de color y símbolos utilizables sin depender solo del color. | Verificar contraste y distinción de series/estados con una alternativa accesible y un recorrido con VoiceOver. |

## 13. Informes e intercambio

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| INF-01 | P0 · C | Exportar PDF real con texto seleccionable, paginación y figuras. | Abrir el PDF fuera de VAPULA; comprobar Unicode, tablas largas, pies, títulos y ausencia de recortes. |
| INF-02 | P0 · C | Exportar Markdown con figuras locales portables. | Mover MD y PNG asociados a otra carpeta y resolver sus enlaces relativos; informar que deben viajar juntos. |
| INF-03 | P0 · C | Componer un informe con salidas elegidas del flujo y su procedencia. | Incluir solo análisis/calidad/gráficos alcanzables y seleccionados; rechazar referencias ajenas y mostrar el límite de 32 figuras. |
| INF-04 | P0 · D | Hacer consistente el alcance de exportación entre caja, resultado y atajo general. | Las tres entradas explicitan qué se exporta y no introducen resultados adicionales por una ruta heredada. |
| INF-05 | P1 · B | Incluir perfiles de datos en PDF y MD desde el flujo. | Exportar desde la caja Informe reproduce perfiles de la versión elegida en ambos formatos, junto a sus resultados. |
| INF-06 | P0 · B | Exportar CSV de resultados y CSV/Parquet de datos protegiendo destinos. | Mantener tipos/valores admitidos y no sobrescribir archivos existentes; un fallo retira solo archivos nuevos de esa exportación. |

## 14. Diseño y uso de macOS

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| UX-01 | P0 · C | Mantener un escritorio sobrio, claro y contextual según la maqueta aceptada. | Completar importación→ausentes→análisis→gráfico→informe con controles visibles, sin campos truncados ni explicaciones internas innecesarias. |
| UX-02 | P0 · D | Acceso completo por teclado y VoiceOver. | Ejecutar el recorrido principal, conectar/configurar cajas y exportar con foco visible, nombres y orden de lectura comprensibles. |
| UX-03 | P0 · B | Modos claro/oscuro y adaptación a la ventana mínima declarada. | Revisar lienzo, inspector, tabla, errores y gráficos a 1060×700, incluido contenido largo y preferencias de texto disponibles. |
| UX-04 | P0 · B | Español/inglés completos y consistentes. | Cambiar idioma y revisar controles, mensajes dinámicos, ayudas y errores del recorrido; no dejar mezclas salvo contenido del usuario. |
| UX-05 | P0 · D | Estados vacíos, errores y acciones de recuperación comprensibles. | Proyecto nuevo, tipo incorrecto, `rowid`, límite de filas y exportación fallida indican qué ocurrió y una acción posible. |
| UX-06 | P1 · D | Repetir tareas frecuentes con menos configuración y orientación contextual. | Observar usuarios completar tres recorridos, registrar tropiezos y corregirlos antes de añadir controles permanentes. |

## 15. Privacidad y seguridad

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| SEG-01 | P0 · B | Funciones principales locales, sin red, cuenta, telemetría ni IA en línea. | Ejecutar el recorrido completo con red desconectada y contrastar código/observación de conexiones; diferenciar enlaces externos voluntarios. |
| SEG-02 | P0 · B | Consultas cerradas y operaciones tipadas, sin ejecución de texto del usuario. | Pruebas de nombres/valores maliciosos no ejecutan SQL adicional; extensiones, rutas remotas y expansión glob permanecen bloqueadas. |
| SEG-03 | P0 · B | No publicar datos personales, credenciales ni proyectos del usuario. | Repositorio, capturas, muestras y paquetes públicos contienen solo fuentes y datos sintéticos permitidos. |
| SEG-04 | P0 · B | Dependencias identificadas y licencias redistribuidas correctamente. | Revisar origen/licencia de cada incorporación; el paquete contiene licencia propia y avisos del motor y terceros. |

## 16. Rendimiento y cancelación

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| REN-01 | P0 · B | Motor fuera del hilo principal y carga tabular acotada. | Revisar aislamiento y paginación; medir el recorrido real sin congelaciones prolongadas del control de ventana. |
| REN-02 | P1 · D | Medir rendimiento reproducible en Apple Silicon antes de prometer ventajas. | Con un millón de filas, registrar importación/perfil, al menos diez páginas, mediana/p95, RSS y condiciones; objetivo inicial de paginación caliente p95 <1 s, aún por validar. |
| REN-03 | P1 · D | Auditar consumo y escala del lienzo, incluida cancelación bajo carga. | Registrar reposo, memoria, interacción y apertura con grafos grandes hasta el límite admitido; medir demora de cancelación y publicar límites reales. |

## 17. Verificación y distribución

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| VAL-01 | P0 · B | Pruebas optimizadas de núcleo, integración y referencias numéricas independientes. | Ejecutar Swift Testing en release, conservar salidas y contrastar cada procedimiento nuevo con definiciones/tolerancias explícitas. |
| VAL-02 | P0 · C | Pruebas visuales reales y evidencia de exportaciones. | Operar la aplicación con datos sintéticos, abrir sus archivos exportados y registrar versión, pasos, resultado y límites de cobertura. |
| VAL-03 | P0 · D | Calificar el paquete en otro Mac y en el sistema mínimo anunciado. | Descargar/verificar SHA-256 y abrir sin entorno de desarrollo en Apple Silicon/macOS 14 y otro sistema soportado; documentar Gatekeeper y firma. |
| VAL-04 | P1 · D | Preparar distribución con Developer ID y notarización cuando haya recursos autorizados. | Verificar firma, notarización y ticket de un artefacto reproducible; no presentar ad-hoc como notarizado. |

## 18. Presentación pública y familia

| Código | Prioridad · origen | Requisito | Criterio de aceptación |
| --- | --- | --- | --- |
| PUB-01 | P0 · C | README y portada cuidados según METATRON y el sistema de familia. | Mantener portada oscura 2:1, sello propio, mensaje/autoría comunes y separación entre arte promocional y capturas reales. |
| PUB-02 | P0 · C | Explicar utilidad, ventajas concretas y límites con imágenes reales. | La página presenta casos, capturas sintéticas sin alterar, descarga, alcance y comparaciones respaldadas; no inventa benchmarks ni superioridad universal. |
| PUB-03 | P1 · C | Conservar apoyo voluntario discreto y enlaces coherentes. | README, aplicación y documentación apuntan al destino canónico de Ko-fi sin mensajes intrusivos. |
| PUB-04 | P1 · C | Preparar imagen y descripción para el sitio del autor. | Entregar portada/tarjeta y textos breve/detallado utilizables; distinguir material preparado de publicación efectiva en el sitio. |

## 19. Ampliaciones propuestas, pendientes de decidir

Estas opciones responden al deseo de más posibilidades sin convertir VAPULA en un entorno general. Su prioridad es orientativa y **ninguna está comprometida por esta lista**.

| Código | Prioridad · origen | Propuesta | Criterio previo a aprobar su implementación |
| --- | --- | --- | --- |
| EXT-01 | P1 · P | Importación XLSX y combinaciones visuales de tablas. | Priorizar por separado; definir hojas/tipos, claves, cardinalidad y duplicados; evaluar biblioteca, licencia, mantenimiento y memoria. |
| EXT-02 | P1 · P | Más pruebas generales y comprobación de supuestos. | Elegir métodos por una necesidad concreta; candidatos: normalidad, homogeneidad, Fisher, Welch ANOVA o post-hoc con corrección. Especificar supuestos, referencias y salidas antes de programar. |
| EXT-03 | P1 · P | Más formas y opciones de gráficos y exportación de figuras independientes. | Priorizar intervalos/barras de error, QQ, mapa de calor o violín y SVG/PDF/PNG; comparar soluciones nativas/bibliotecas por legibilidad, licencia, accesibilidad y exportación. |
| EXT-04 | P2 · P | Reglas de ausentes personalizadas y preparación repetible por grupos. | Definir marcadores como NA o códigos especiales, imputación por grupo y recetas reutilizables sin introducir ejecución arbitraria. |

## 20. Restricciones y decisiones de arquitectura

Se conserva la [arquitectura modular vigente](ARCHITECTURE.md): núcleo/modelos, datos/DuckDB, estadística, informes e interfaz. Las tareas de cierre deben respetar las versiones inmutables, la persistencia atómica, el motor serializado fuera de la interfaz y las operaciones tipadas. No se propone reescribir el proyecto para cumplir este inventario.

Límites operativos actuales que la interfaz y las pruebas deben hacer visibles: 256 columnas, páginas de 100 filas, máximo de 200.000 filas para análisis numéricos materializados, 500 cajas, primeros 2.000 pares en dispersión/línea/área, 30 categorías y 32 figuras por informe. No son garantías de rendimiento al alcanzar cada máximo. [LIMITATIONS.md](LIMITATIONS.md) detalla límites adicionales y las definiciones estadísticas.

El motor tiene límites de recursos propios; esos valores no limitan toda la memoria del proceso. La cancelación es cooperativa y espera a que termine la consulta síncrona activa. Una nueva biblioteca se justifica por el requisito seleccionado, su licencia, mantenimiento, memoria y compatibilidad con exportación; no por ampliar el catálogo por sí solo.

## 21. Escenarios de aceptación

| Caso | Recorrido verificable | Requisitos principales |
| --- | --- | --- |
| AC-01 | Importar con opciones regionales, cerrar, copiar el paquete, retirar la fuente externa y reabrir con valores/resultados iguales. | PRY-01, PRY-02, PRY-04, IMP-01, IMP-03 |
| AC-02 | Buscar y ordenar, corregir una celda, añadir columna/fila y retirar esa fila; comprobar identidad y fuente intacta. | DAT-01, DAT-03, EDT-02, EDT-05 |
| AC-03 | Revisar NULL, texto vacío y no finitos; contrastar unión de filas y cada acción de relleno/retirada. | AUS-01 a AUS-04, CAL-01 |
| AC-04 | Intentar media/mediana/moda en una columna totalmente ausente y conservar una explicación, sin valores fabricados. | AUS-03, AUS-06 |
| AC-05 | Cambiar una preparación en una rama y ejecutar sus descendientes sin alterar la otra; quitar/deshacer la rama. | FLU-03 a FLU-06 |
| AC-06 | Fallar/cancelar aguas abajo y reabrir; conservar pasos completos, sin referencias parciales ni resultado antiguo marcado como actualizado. | PRY-03, PRY-05, FLU-04, FLU-05, FLU-07 |
| AC-07 | Convertir texto con valores inválidos y revisar el impacto de nuevos NULL antes de aceptar. | IMP-04, EDT-03, CAL-04 |
| AC-08 | Ejecutar los diez métodos con casos conocidos, degenerados y exclusiones; contrastar referencias y advertencias. | EST-01 a EST-05, VAL-01 |
| AC-09 | Guardar/reabrir cada forma de gráfico y comprobar cobertura, títulos, estilo y salida real. | GRA-01 a GRA-06 |
| AC-10 | Elegir un análisis y un gráfico, exportar PDF/MD, mover los archivos y comprobar que no entran resultados ajenos. | EST-07, INF-01 a INF-04 |
| AC-11 | Exportar sobre un nombre existente y provocar fallo; verificar que el archivo anterior y otras figuras permanecen intactos. | INF-06 |
| AC-12 | Completar el recorrido sin red; verificar ausencia de conexiones del núcleo y protección frente a nombres/valores maliciosos. | SEG-01, SEG-02 |
| AC-13 | Completar el recorrido con teclado/VoiceOver, en ambos idiomas y temas, a la ventana mínima, con etiquetas largas. | UX-01 a UX-05, GRA-05, GRA-06 |
| AC-14 | Medir un millón de filas y grafos crecientes; registrar condiciones, p95, memoria y cancelación sin convertir límites internos en garantías globales. | REN-01 a REN-03 |
| AC-15 | Descargar en otro Mac, verificar suma/firma, abrir sin herramientas de desarrollo y comprobar la plataforma mínima declarada. | VAL-03, VAL-04 |

La ejecución y su resultado se registran en STATUS/VALIDATION, no se presuponen por aparecer aquí.

## 22. Orden de trabajo propuesto

1. **Consolidar la base:** recuperación, fallos comprensibles, pérdidas de conversión, borradores y exportación coherente; cerrar recorridos de teclado, idiomas, apariencia y paquete limpio.
2. **Mejorar el trabajo diario:** comparación de versiones, metadatos, evidencia completa, perfiles en informes, orden descendente y ayuda estadística contextual.
3. **Ampliar con una pregunta concreta:** priorizar individualmente FLU-08 y EXT-01 a EXT-04; elegir métodos, formas o bibliotecas después de definir su aceptación.

Entregables de cada lote: comportamiento real, requisitos afectados, evidencia proporcionada al riesgo, límites actualizados y paquete/documentación coherentes. Una entrega de documentación no cambia la versión de la aplicación ni justifica una nueva release binaria.

## 23. Convención de mantenimiento

Conservar códigos estables y actualizar conjuntamente esta especificación y [STATUS.md](STATUS.md). Una fila solo se cierra con evidencia del alcance escrito; pruebas del núcleo no sustituyen revisión de accesibilidad, y una captura no certifica todos los gráficos. Nuevas ideas entran primero como propuestas con origen y prioridad, sin convertirlas en compromisos implícitos.
