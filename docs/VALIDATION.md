# Validation — local expanded build

**Current update — 2026-11-02:** [0.1.1 integrity stage](INTEGRITY-STAGE.md) records 69 optimized tests in 15 suites, two complete repeats, native draft/conversion/recovery/export checks and actual output files. The dated October records below remain historical. Current coverage is in [STATUS.md](STATUS.md).

**Reading note — 2026-11-01:** the October 30–31 records below describe the local build at that time. Their statements that no repository/release had been created are historical. VAPULA was subsequently published in the [public repository](https://github.com/AD0441/VAPULA) and as the [0.1.0 preliminary release](https://github.com/AD0441/VAPULA/releases/tag/v0.1.0). Current requirement coverage and remaining work are tracked in [STATUS.md](STATUS.md), against [REQUIREMENTS.md](REQUIREMENTS.md). This documentation update does not represent a new application test run.

User-facing record: 2026-10-30 (America/Santiago). Host: Apple M1 MacBook Pro, 8 GB RAM, arm64, macOS 27.2. Swift 6.4 with the complete Xcode SDK, package Swift 6.2 / macOS 14 deployment target. Execution on macOS 14–26 or Intel was not tested.

## Optimized tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
VAPULA_PDF_SAMPLE=/tmp/vapula-results-sample.pdf \
VAPULA_BENCHMARK=1 VAPULA_BENCHMARK_OUTPUT=/tmp/vapula-benchmark.json \
VAPULA_NUMERICAL_OUTPUT=/tmp/vapula-numerical \
swift test -c release -j 2
```

40 tests in seven suites passed in release configuration. These include numerical comparisons, persistence/import/transformations and failure recovery, SQL/path safety, cancellation before commit, full-pipeline portable reopening, five added statistical procedures, histogram bins, persisted styles, schema-1 compatibility, PDF pagination/selection and a synthetic million-row benchmark. The final executed output is preserved in `evidence/test-release.txt`. Test count describes Swift Testing functions, not individual parameterized cases or scalar assertions.

The initial numerical reference matrix contains 345 scalar comparisons; the expansion adds 1,011 across 79 cases, for 1,356 total scalar reference values. Absolute and relative tolerance both apply. Observed maximum absolute differences include one-way ANOVA 3.54e−9 (within the combined tolerance for the corresponding value), chi-square 1.09e−11, one-sample t 4.80e−13, paired t 3.91e−14 and Mann–Whitney 1.39e−16. Full method definitions and limitations are in STATISTICAL-VALIDATION.md.

An earlier optimized run crashed in upstream Swift result-vector decoding despite debug checks passing. Replacing borrowed access with the owned public C API bridge resolved the observed crash; optimized integration tests now pass. Debug-only success was not used to qualify the bundle.

## Real visual and functional review

Computer Use operated the actual native application after the author unlocked the Mac and ceded control. Only synthetic test data was used.

Initial build: welcome screen, create/open project, import preview then 31 rows / five columns, database search and sorting, complete profile, duplicate-key evidence, IQR and missing-value findings, immutable filter to 16 rows while retaining the original, persisted descriptive/Welch results, histogram/boxplot/scatter/frequency views.

Expanded build: welcome and sidebar, reopen the same portable project, two connected dataset-version nodes and existing analysis nodes, select original node and continue to its statistics, inspect the ten-method menu, calculate t pareada on X/Y (29 valid pairs / two excluded source rows), inspect its persisted result, open individual export menu and save a real PDF through the native save panel, inspect the chart studio and eight-form menu, apply X/Y variables, observe pending-refresh notice, customize a title and HEX color (#A34A32), save histogram styling, render a scatter with diamond symbols.

Visual findings led to concrete corrections: result connections now use the next lineage depth to avoid passing through unrelated version nodes; table labels are human-readable and exact duplicate metric aliases are hidden from human-facing tables (CSV retains raw keys); histogram intervals use rectangles from zero to count rather than horizontal floating marks. Confirmation on the rebuilt bundle: the workflow now branches to analysis nodes at the next depth without crossing the filter node; the histogram draws filled intervals from 0 to 7/6/4/1 as appropriate; the saved title/HEX color survives reopening; the result table shows Spanish labels without the duplicate confidence-interval/n aliases. A real individual Markdown file was exported through the save panel and its single-result content checked.

The PDF sample was rendered with pdftoppm and pages 1–2 visually inspected. Metric labels, Unicode hypotheses, table continuation headers and page footers are readable without clipping. Long-report completeness and per-page footers also pass PDFKit text assertions. `evidence/resultados-sinteticos.pdf` is an actual generated vector report, not a screenshot mockup.

Automation sometimes returned timeouts or user-change guards; fresh accessibility reads and screenshot-coordinate fallback resolved the tested open-panel action. Full dark-mode, full English localization, VoiceOver navigation and exhaustive visual checking of every method/form remain unverified. These are not claimed as completed QA.

## Package and publication

The app bundles the DuckDB engine, ES/EN resources, author icon, project license and 26 upstream notices. otool shows only system/Apple framework dependencies; no runtime interpreter, Homebrew or temporary build path is linked. The clean temporary bundle passes strict ad-hoc signature verification. Desktop copies initially retained stale nested signature files and Finder metadata; replacing the generated bundle exactly and removing only FinderInfo/ResourceFork within that bundle addresses those packaging artifacts. The final Desktop bundle passed strict verification immediately after metadata removal (valid on disk / designated requirement satisfied), but FinderInfo subsequently reappeared on the Desktop app directory and strict verification there can fail again. This directory-metadata issue does not change the executable/resource bytes: all bundle-file SHA-256 hashes match the verified clean bundle (`evidence/bundle-integrity.json`). Use the attribute-free ZIP for portable verification. The ZIP was created without extended attributes, extracted into a new temporary directory and also passed strict signature verification; its SHA-256 verification passed. Developer ID, notarization and cross-OS distribution testing are not complete.

The project and artifacts remain local at the author's chosen Desktop/CODEX/VAPULA folder. No GitHub repository, push or release was created. See LIMITATIONS.md, PDF-EXPORT.md, CHARTS.md and KNIME-REFERENCE.md for actual boundaries.


## Integrated workbench — 2026-10-31

53 Swift Testing functions in nine suites passed in the optimized full build, including the real app target. Added coverage: missing-value union/cell impacts, each fill/drop policy, all-missing and nonfinite cases, typed manual editing with search/sort row identity, large integer mode ties, `rowid` shadow protection, real branched DAG execution/selective re-execution/persistence, cycle/port/source-output identity validation, and PDF/Markdown figure export/sidecar overwrite protection. All previous numerical reference suites remain included. Evidence: `evidence/test-integrated-release.txt`.

A simultaneous full-suite synthetic-million-row run recorded import 0.192 s, page 0.383 s, profile 0.276 s, database 4,468,736 bytes and runner peak RSS 640,581,632 bytes (610.9 MiB). Tests run concurrently, including PDF/image work; that peak is the whole test process, not application-only memory or an independent speed comparison with the earlier isolated benchmark. See `evidence/benchmark-integrated-release.json`.

`evidence/integrated-figure-sample.pdf` is a genuine exported test report. Rendered page 3 was inspected: the embedded five-bar image, searchable title/caption, source dataset UUID and footer fit without clipping. This checks the report engine; it does not by itself validate the app’s live chart renderer.

The integrated bundle is staged from the same release executable produced by the successful test build. After the author unlocked the Mac and ceded control, native Computer Use completed: create project; import preview and actual 31-row/five-column CSV; add Missing box, inspect six actions and one-cell/one-row impact, fill X with observed mean 21.466666666666665; double-click first X cell and correct 4.0→4.5 as a new version; inspect ten-method menu, execute X descriptives (31 valid/0 excluded, mean21.4828); inspect eight-chart menu, render real X histogram with custom title; combine analysis+chart in a report; export PDF and Markdown via native save panels. The actual PDF was rendered and its chart page inspected: chart, axes, source UUID, caption and footer are visible. The Markdown and its local PNG exist with a correct relative reference.

Additional native checks: add VARCHAR column `nota_revision` initialized as NULL; append synthetic row999 (32 rows); search999, select and remove that row (31 rows, six columns) as another version; fit overview, drag a box and confirm changed coordinates in saved metadata; remove its canvas branch and undo to restore nine boxes while keeping all six physical dataset versions. No source file was modified. The first lock attempt was a tool/environment blocker resolved by the author.

One bounded correction batch follows these findings: stack the analysis buttons when the inspector cannot fit them, fit the edit/export controls to their labels, shorten the history selector, and remove a duplicated chart title from report PNG content. Confirmation after rebuild is recorded below. Full VoiceOver, English, dark-mode, every method/form combination and cross-OS coverage remain unverified.


Final confirmation: the rebuilt app in `/Users/sebastian/Desktop/CODEX/VAPULA/dist/VAPULA.app` opens the saved package directly with `open -a`. Source selection now brings its box into the visible canvas at the current zoom. The source table still shows first X=4, while the corrected version shows X=4.5; the original SHA-256 matches its recorded import hash. The history/edit/export labels fit. Analysis buttons adapt to a vertical arrangement, with the inspector scroll available for the second control. Saved chart boxes show their actual type/X when the preview cache has not yet been regenerated. A fresh PDF exported after reopening and rendered for inspection contains the histogram with a single title, readable axes, source UUID and footer (`evidence/VAPULA-flujo-final.pdf`). The final build again passed 53 tests in nine suites (`evidence/test-integrated-release-final.txt`).

Local format compatibility: old schema-1 projects without workflows still open. Older application binaries cannot decode the new operation cases; use the updated bundle for projects that contain missing-value or manual-edit steps. No forward-compatibility claim is made for the previous binary.


Final local packaging: the ZIP was created without resource forks/extended attributes, SHA-256 checked, extracted into a fresh temporary directory and verified with strict ad-hoc codesigning. All 36 extracted bundle-file hashes match the app saved in the chosen project folder. Evidence: `evidence/bundle-integrity-integrated.json`. The synthetic native-review project is also available locally under `Examples/Flujo-sintetico.vapula`; it is generated data ignored by Git. No repository, push, public release or upload was created.
