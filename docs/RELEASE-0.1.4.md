# VAPULA 0.1.4 · Claridad y arrastre

- Las cajas siguen al puntero con zoom y guardan la posición al soltar.
- ⌥⌘L revela y enfoca la lista de pasos. Las flechas cambian la selección.
- El resumen CSV cuenta los resultados con métricas y orienta cuando la selección está vacía. Un gráfico pendiente deja de bloquear el CSV de un análisis ejecutado.
- La exportación confirma el archivo guardado, indica cuándo se canceló y ofrece acciones ante conflictos de nombre o destino.

La entrega pasó 81 pruebas release en 17 suites, la revisión nativa de teclado y exportación, y la prueba de arrastre del autor. El [cierre V3](ACCEPTANCE-V3.md) registra los recorridos y el comportamiento observado del selector de macOS.

El paquete preliminar es para Apple Silicon y usa firma ad hoc. El mínimo de compilación es macOS 14. La app se comprobó en macOS 27.3. [Integridad del ZIP](evidence/bundle-integrity-0.1.4.json) · [Estado de requisitos](STATUS.md).
