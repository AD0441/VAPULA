# Dónde destaca VAPULA

VAPULA está diseñado para una tarea concreta: preparar una tabla local, responder preguntas estadísticas generales y compartir resultados con su procedencia, desde una aplicación nativa para Mac. La ventaja que buscamos es acortar ese recorrido con pocas familias de herramientas y versiones explícitas de los datos.

## Lo que mejora en un flujo de trabajo cotidiano

### Corregir sin perder la entrada

Una corrección de celda, una fila añadida o un tratamiento de ausentes produce una versión nueva. Puedes volver a la entrada y continuar otra rama, incluso si ya guardaste análisis de la salida anterior. Retirar una caja del lienzo conserva las versiones físicas y resultados en el historial.

La mejora es especialmente concreta cuando hoy editas celdas directamente y guardas copias manuales para recordar qué cambió. No depende de que actives un historial opcional. La contrapartida es el espacio en disco de esas versiones. [Modelo de datos](DATA-MODEL.md) · [Operaciones](../Sources/VapulaData/Cleaning.swift).

### Menos montaje para análisis generales

El bundle incorpora el motor de datos. El usuario final puede limpiar, calcular, visualizar y exportar desde controles nativos, sin instalar Python, R o un catálogo de extensiones. La barra se limita a siete familias y el laboratorio a diez métodos generales; la selección acotada es una decisión de diseño, no una medición de superioridad universal. [Herramientas del flujo](../Sources/VapulaCore/DataWorkflow.swift) · [Métodos y supuestos](STATISTICAL-VALIDATION.md).

### Un resultado unido a sus datos

Un resultado registra versión, variables, parámetros, procedimiento, observaciones válidas/excluidas y advertencias. El informe conserva fuentes y versiones relevantes, y puede reunir análisis, controles de calidad y gráficos. Esto ayuda a revisar cómo se llegó a un número, además de copiarlo a otra aplicación. [Informes](PDF-EXPORT.md) · [Validación real](VALIDATION.md).

### Ausentes con una decisión visible

Antes de aplicar, se muestran las filas y celdas afectadas. NULL siempre se trata como ausente; texto vacío y números no finitos se controlan por separado. Puedes elegir media, mediana, moda, un valor indicado o retirar las filas/columnas afectadas. La imputación no se presenta como una corrección estadísticamente inocua: los análisis descendientes advierten que puede cambiar la dispersión y las asociaciones.

## Frente a otras opciones

La columna de VAPULA describe para qué se ha diseñado la app. La valoración de comodidad depende de la tarea; no procede de un estudio comparativo con usuarios.

| Opción | Cuándo VAPULA ofrece un recorrido enfocado | Cuándo conviene la otra opción |
| --- | --- | --- |
| **Edición directa en una planilla** | Cuando necesitas que cada corrección conserve una versión identificable y que el análisis siga conectado a ella, sin organizar copias manualmente. | Cuando el trabajo depende principalmente de fórmulas, presentación y colaboración dentro del libro. |
| **Excel con Power Query** | Cuando prefieres reunir preparación, pruebas generales, gráficos e informe en un mismo escritorio de cajas para Mac. | Cuando necesitas integrar transformaciones en un trabajo ya organizado alrededor de Excel. Power Query también registra y permite revisar sus pasos; la transformación reproducible no es una función exclusiva de VAPULA. [Documentación de pasos aplicados](https://learn.microsoft.com/es-es/power-query/applied-steps). |
| **KNIME** | Cuando buscas un conjunto pequeño de herramientas predefinidas para datos locales y estadística general, con el aspecto y controles propios de macOS. | Cuando necesitas el ecosistema de integraciones y capacidades más amplio de KNIME, incluidas conexiones a bases de datos y plataformas externas. [Extensiones e integraciones oficiales](https://docs.knime.com/build/integrations/). |
| **Python con pandas** | Cuando quieres tratar ausentes y organizar operaciones con formularios y cajas, sin escribir ni mantener un programa para esa tarea. | Cuando necesitas programar transformaciones personalizadas y componerlas con el ecosistema de Python. pandas ya ofrece detección, retirada y reemplazo de ausentes; esos cálculos tampoco son exclusivos de VAPULA. [Guía oficial de ausentes](https://pandas.pydata.org/docs/user_guide/missing_data.html). |

Fuentes consultadas el 1 de noviembre de 2026. No se comparan precios ni límites de versiones comerciales. El funcionamiento de VAPULA se contrasta con sus fuentes y pruebas; las características de terceros se apoyan en su documentación oficial, no en una auditoría completa de sus productos.

## Un recorrido que puedes reproducir

1. Importa [laboratorio.csv](../Tests/VapulaTests/Fixtures/laboratorio.csv): 31 filas sintéticas y cinco columnas.
2. Añade **Ausentes**, selecciona `x` y revisa el impacto: una celda, en una de las 31 filas. Elige media y aplica para obtener otra versión.
3. Comprueba que la fuente original sigue en el flujo. Para otra corrección, usa doble clic sobre una celda; vuelve a crearse una versión.
4. Conecta **Analizar** y **Gráfico** a la versión elegida. Calcula descriptivos y un histograma de `x`.
5. Reúne ambas salidas en **Informe** y exporta PDF o Markdown con su figura.

![VAPULA como laboratorio integrado de datos, análisis y gráficos](assets/promo/vapula-cover.png)

Imagen promocional generada a partir de una captura real. Las [capturas de la aplicación](screenshots/README.md) y la [validación](VALIDATION.md) documentan las pruebas efectivamente realizadas.

## Lo que todavía no se puede afirmar

No hay un benchmark entre VAPULA y estas aplicaciones que demuestre menor consumo, mayor velocidad o mejores resultados estadísticos. Las mediciones locales del M1 y las referencias numéricas verifican un alcance concreto de VAPULA, no una clasificación frente a otros productos.

Esta versión no incluye joins, Excel como formato de entrada, regresión múltiple, pruebas post-hoc, ejecución de scripts arbitrarios ni ecosistema de plugins. El procesamiento local y el código abierto tampoco son exclusivos. Consulta [los límites completos](LIMITATIONS.md) antes de elegir la herramienta para un trabajo especializado.
