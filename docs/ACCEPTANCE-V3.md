# VAPULA · Claridad esencial V3

**10 de noviembre de 2026, America/Santiago. VAPULA 0.1.4, build 5.** Cierre de los recorridos probados de V3 en la Gantt, con la corrección del arrastre solicitada durante la revisión.

| Antes | Después | Comprobación |
| --- | --- | --- |
| Los atajos seleccionaban pasos y el foco podía quedar en otro panel. | ⌥⌘L revela y enfoca la lista. Las flechas eligen el paso. | Con la biblioteca oculta, el primer atajo recuperó la lista. ↓ seleccionó Descriptiva y mostró media 5. |
| El diálogo CSV contaba figuras y permitía avanzar con un resultado vacío. | CSV muestra los análisis con métricas. El destino se desactiva si faltan métricas y el aviso indica cómo continuar. | En 0.1.3 se observó un gráfico anunciado en CSV y el botón activo con cero resultados. En V3 una caja Histograma quedó bloqueada y el Informe exportó un resultado con 12 métricas. |
| El destino podía abrirse mientras se retiraba la hoja de opciones. | El destino se presenta tras cerrar las opciones. Guardar y cancelar tienen mensajes propios. | Return abrió el destino. Se observaron la cancelación y la confirmación con el nombre del archivo. |
| El arrastre medía la traslación en el espacio local de la caja, que cambiaba al moverla. | La traslación se mide en la ventana y se convierte una vez según el zoom. Las posiciones y los cables se previsualizan durante el gesto. Se guarda una posición al soltar. | El autor confirmó que el arrastre corregido funciona bien. Se observaron tres posiciones nuevas en el manifiesto sintético y un cierre limpio. |

La muestra incorporó cuatro filas, una descriptiva, un histograma y un informe. El CSV guardado contiene un resultado con n=4 y media 5. PDFKit leyó tres páginas del PDF final y verificó el identificador del resultado, el histograma y la versión real del exportador. El SHA-256 del CSV fuente coincide antes y después. Los archivos de la muestra son locales. El [registro de aceptación](evidence/v3-acceptance.json) recoge las observaciones y las [81 pruebas release en 17 suites](evidence/test-v3-release.txt) incluyen las dos regresiones de CSV.

En macOS 27.3 se observó un selector nativo con Abrir o Guardar desactivado en la carpeta recordada. Volver a elegir esa carpeta habilitó los botones y permitió completar la prueba. La herramienta remota devolvió errores al automatizar el gesto de arrastre, que comprobó el autor. El alcance de teclado cubre revelar la lista, cambiar de paso y llegar al destino del informe. VoiceOver y la matriz completa de idiomas, temas, tamaños y entornos siguen en [STATUS.md](STATUS.md).

El ZIP para Apple Silicon pasó la firma ad hoc tras una extracción limpia. Sus 38 archivos coinciden con el bundle comprobado. [Integridad de 0.1.4](evidence/bundle-integrity-0.1.4.json).
