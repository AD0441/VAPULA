# Lote 1 — Integridad y decisiones visibles

**Fecha:** 2 de noviembre de 2026, America/Santiago. **Versión:** 0.1.1 preliminar. Base: `4982dd1` y [requisitos](REQUIREMENTS.md). Host: MacBook Pro Apple M1, 8 GB, macOS 27.2, Swift 6.4/Xcode; mínimo de compilación macOS 14.

## Cambios entregados

| Requisito | Comportamiento |
| --- | --- |
| PRY-05 | Reserva de escritura mediante bloqueo del sistema operativo. Otra instancia recibe una acción concreta para reintentar. Una sesión interrumpida se reconoce al reabrir y se verifican las versiones del manifiesto antes de continuar. |
| IMP-04 | Diagnósticos de lectura con archivo, fila/columna/ejemplo cuando el lector aporta ese contexto, y opciones para reintentar. No se muestra la consulta interna del motor. Si falta una ubicación concreta, se indica expresamente. |
| EDT-03 | Vista previa de nuevos NULL, NULL previos y hasta cinco ejemplos no convertibles. Una conversión con pérdidas requiere aceptación vinculada a la versión, columna, tipo y cantidad; el motor también exige esa aceptación. |
| FLU-07 | Formularios pendientes conservados por proyecto, caja y versión de entrada durante la sesión. Indicador visible, descarte explícito y protección al ejecutar/cerrar. Los borradores no sustituyen parámetros ejecutados ni resultados. |
| INF-04 | Un selector común para la caja, el resultado individual y el proyecto completo. Se informa el alcance, históricos, gráficos pendientes y contenido de CSV/MD antes de elegir destino. ⌘E usa el contexto seleccionado. |

También se evita reemplazar por cero una media de referencia escrita incorrectamente: la t de una muestra pide corregirla antes de calcular.

## Protección de proyectos

`.vapula-lock` mantiene un bloqueo asesor exclusivo por paquete; no se elimina, porque sustituir su archivo permitiría bloquear inodos distintos. El sistema libera la reserva si muere el proceso. `.vapula-session` identifica una apertura sin cierre limpio; desaparece al cerrar normalmente. No hace falta borrar archivos de bloqueo para reabrir.

Al abrir se verifican tablas físicas, nombres y tipos de columnas. Tras una interrupción se contrastan también los recuentos guardados; DuckDB realiza su recuperación de transacciones/WAL. Una incoherencia se rechaza con orientación para conservar el paquete y revisar un respaldo. No se reemplaza un manifiesto corrupto por uno vacío. Un intento fallido de abrir otro proyecto conserva el proyecto actual.

Las tablas internas no referenciadas se cuentan y **se conservan**. El aviso no afirma que estén incorporadas al historial ni ofrece compactación. Cierra el proyecto antes de copiarlo. Esto no reconstruye una base físicamente corrupta ni sustituye las copias de respaldo; tampoco califica escritura concurrente sobre sistemas de archivos de red o sincronización de nube.

## Conversiones y borradores

La aceptación de una conversión se guarda en su caja. Si una preparación anterior genera otra versión de entrada, la aceptación antigua deja de servir y se solicita revisar de nuevo. Las conversiones sin nuevos NULL continúan sin una advertencia de pérdida. Esta comprobación **cuenta nuevos NULL**; no detecta todos los redondeos o cambios de precisión entre tipos.

Se conservan borradores de preparación/calidad, ausentes, estadística, gráficos y selección de informes. Pertenecen a la sesión y a su entrada; no se reinterpretan sobre otra versión. Volver al contexto anterior del flujo permite recuperar el borrador correspondiente. Aplicar lo convierte en configuración del paso; un fallo de ejecución sigue apareciendo como fallo, sin presentar su resultado anterior como actualizado.

Cerrar, abrir otro proyecto o salir con borradores ofrece volver al proyecto o descartarlos expresamente. No son un autoguardado persistente: un cierre forzado puede perder los formularios aún no aplicados. Las versiones completadas sí se guardan por separado. La revisión de recuperación de este lote trata esos datos comprometidos.

## Exportación

- **Caja:** sus salidas y antecesores, con fuentes/versiones pertinentes. Requiere pasos actualizados.
- **Resultado individual:** ese resultado y su procedencia, sin hallazgos o resultados ajenos.
- **Proyecto completo:** todos los resultados y hallazgos guardados, incluidos históricos; gráficos de cajas listas. Se informa cuántos gráficos pendientes se excluyen.
- **CSV:** métricas de resultados, sin figuras ni hallazgos de calidad. **MD:** figuras PNG relativas que deben acompañar al documento. **PDF:** texto vectorial y figuras raster.

El límite vigente es 32 gráficos. Se conservan la protección de destinos existentes y los perfiles del MD global; la paridad de perfiles PDF/MD desde la caja Informe sigue pendiente en INF-05.

## Pruebas ejecutadas

```sh
./script/test.sh -c release
./script/test.sh -c release --skip-build
```

La suite final pasó **69 funciones Swift Testing en 15 suites**. Dos repeticiones completas sin recompilar también pasaron. Las referencias estadísticas existentes siguen incluidas; no se añadieron métodos ni nuevas comparaciones numéricas en este lote.

Evidencia: [ejecución final](evidence/test-integrity-release.txt), [repetición 1](evidence/test-integrity-repeat-1.txt), [repetición 2](evidence/test-integrity-repeat-2.txt).

| Caso | Comprobación |
| --- | --- |
| Dos escritores | Otra instancia no abre para escritura; cerrar la primera libera la reserva. |
| Apertura fallida | Un manifiesto inválido no reemplaza el proyecto actual ni retiene el bloqueo del candidato. |
| Metadatos incoherentes | Tras un marcador de interrupción, recuentos incompatibles impiden abrir; no se reescribe el manifiesto ni se descarta la tabla. |
| SIGKILL durante importación | La tabla comprometida antes del manifiesto queda conservada sin una referencia parcial. |
| SIGKILL después de transformar y antes de guardar metadatos | La versión anterior sigue válida y la tabla nueva se conserva sin atribuirle un compromiso inexistente. |
| SIGKILL después del guardado atómico | La nueva versión completa reaparece. |
| SIGKILL dentro de una transacción | Se descarta el trabajo no comprometido y se recupera la versión previa. |
| Conversión | Se distinguen NULL previos/nuevos, se rechaza aceptación ausente/incorrecta/de otra entrada y se conserva el original. |
| Importación fallida | Un Parquet malformado ofrece orientación, omite SQL interno y no añade versiones. |
| Selección de informe | Ramas ajenas, resultados históricos no elegidos y entradas obsoletas no se incluyen en una selección individual. |

Los cierres forzados usan [exit tests de Swift Testing](https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0008-exit-tests.md) en procesos separados. Una [primera ejecución completa](evidence/test-integrity-initial-failure.txt) con cuatro hijos concurrentes produjo tres SIGTRAP inesperados, aunque la ejecución seleccionada había pasado. Se añadió captura de stderr y comprobación explícita del estado exacto; los ensayos nativos se acotaron a uno a la vez para el host de 8 GB. La suite final y sus dos repeticiones pasaron con SIGKILL comprobado. No se afirma una causa interna del runtime que no se haya demostrado, ni se aceptan otras señales como sustituto del cierre ensayado.

## Revisión de la aplicación real

Computer Use operó un proyecto de cuatro filas sintéticas, primero con cinco cajas y luego seis. No se usaron datos personales.

1. Modificar el relleno constante 10→11 sin aplicarlo, cambiar a Datos y volver: reapareció 11 como borrador, mientras la tabla ejecutada seguía mostrando 10.
2. Intentar ejecutar pidió resolver el borrador. Intentar salir ofreció volver/descartar; volver conservó el formulario. Descartar restauró 10 y retiró el indicador.
3. ⌘E sobre Descriptiva mostró un resultado; elegir Proyecto completo mostró dos históricos y avisó del gráfico pendiente.
4. Exportar un PDF real por el panel nativo. PDFKit verificó un resultado de dos disponibles y renderizó sus dos páginas, inspeccionadas sin recortes. [PDF exportado](evidence/integridad-seleccion.pdf).
5. Añadir Preparar y elegir `id → DATE`: cuatro nuevos NULL, cero previos y ejemplos 1/2/3/4. Cancelar conservó tres versiones; aceptar creó la cuarta. Volver a la entrada mostró los identificadores originales.
6. Salir limpiamente retiró el marcador de sesión. En el paquete final se preparó un marcador **sintético** de interrupción para revisar el aviso: al reabrir se mostraron cuatro versiones verificadas. La muerte real de procesos se comprueba aparte en los exit tests.
7. Escribir «Distribución sintética» como título, cambiar de caja y volver: el título reapareció sin haber ejecutado. Aplicarlo actualizó la caja/gráfico y retiró el indicador.
8. Actualizar Informe con análisis y gráfico, abrir ⌘E y exportar MD+PNG. El documento contiene un resultado, un gráfico y su referencia relativa; excluye el resultado histórico y la rama independiente de conversión. [MD real](evidence/integridad-flujo.md), [figura real](evidence/integridad-flujo-grafico-1.png).

La herramienta presentó timeouts, guardas por cambios de usuario y errores intermitentes de ScreenCaptureKit. Se renovó la sesión y se usó el proyecto mínimo; una muestra del proceso de un segundo no mostró su hilo principal bloqueado en ese instante. Esto no es una medición general de respuesta. No se publican capturas vacías ni reconstrucciones de la interfaz.

Quedan fuera de esta comprobación: auditoría completa con VoiceOver/teclado, todos los idiomas/temas/formas, cortes de energía, corrupción física, otro Mac y ejecución real en macOS 14. Continúan como pendientes en [STATUS.md](STATUS.md).

## Paquete

0.1.1 se empaqueta desde el ejecutable de la suite final. El script compara la copia **antes de firmar**; codesign modifica la firma y campos del Mach-O. El bundle final pasa verificación estricta ad hoc. La extracción limpia del ZIP, su SHA-256 y la coincidencia de los 36 archivos se comprobaron y están en el [registro del paquete](evidence/bundle-integrity-0.1.1.json). Developer ID y notarización siguen pendientes.
