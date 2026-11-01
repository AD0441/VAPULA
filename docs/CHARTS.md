# Chart studio

VAPULA uses native Swift Charts, with a bounded chart surface and a compact design panel. The application identity stays neutral; the user explicitly authorized color in analytical graphics.

Available forms:

- Histogram: exact full-dataset counts in 5–100 equal-width intervals; one bin for a constant variable, empty bins omitted. Where bounds are available, bars use actual interval start/end rather than an arbitrary categorical width.
- Vertical and horizontal frequency bars: at most the 30 most frequent values, including an explicit NULL category. Counts are exact over the current dataset version.
- Scatter: at most the first 2,000 complete finite pairs. Circle, square, diamond and triangle marks are available.
- Line and area: those same bounded pairs sorted by X, with straight segments and optional points. Sorting does not imply time order, causal structure or representative sampling; that limitation is visible below the chart. Repeated X values keep stable query-row order.
- Boxplot: type-7 quartiles and observed 1.5-IQR whiskers. Candidate outliers are counted but not drawn as individual points.
- Lollipop: horizontal frequency stems with configurable point marks.

Presentation options include graphite, ocean, forest, plum, spectrum and a custom RGB color; editable title and axis labels; grid visibility; point form/size; line thickness; and histogram interval count. Custom colors can be entered as a six-digit HEX value or selected in the native color picker. Category labels and numeric values still convey meaning independently of color. Graphite adapts to the system foreground.

The query's actual X/Y names and computed histogram-bin count remain separate from pending picker/style inputs. Axis defaults and provenance use the names of the data actually calculated. A visible notice asks for a refresh when new variables or interval counts have not been applied. Revisiting the surface seeds the pickers from the existing chart's actual variables rather than relabeling cached data with unrelated defaults.

`ChartConfiguration` is a Codable/Sendable value. Save style explicitly to persist it with the dataset version. Titles/colors do not alter data or statistical calculations. Settings read from editable project metadata are normalized to finite bounded sizes, valid HEX and 5–100 bins before rendering/query use. Rendering defensively ignores non-finite chart coordinates; calculations still follow the data engine's own validation rules.

The chart studio does not claim new inferential methods, density estimation, automatic uncertainty bands or arbitrary custom plotting code. Export of statistical results to PDF/Markdown is a separate reporting flow.


## Charts in the integrated canvas

Add a Gráfico box to any data-producing box. The inspector retains all eight forms and color/mark/axis controls. Apply and execute updates the artifact and makes dependent reports stale. Add an Informe box and select its analysis/quality/chart inputs; PDF embeds PNG plots, while Markdown creates local PNG sidecars. Executing a chart after reopening regenerates its bounded cache from its saved parameters.
