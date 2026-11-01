# Performance

Hardware available: MacBook Pro, Apple M1, 8 GB RAM, arm64, macOS 27.2. This is the actual minimum-memory target machine requested in the brief. No extrapolation to M2/M3 or other OS versions is claimed.

Design limits: DuckDB memory_limit=512MB, two query threads, 100-row UI pages, max 256 columns, 2,000 scatter points, 30 frequency categories and 200,000 source rows for materialized paired analyses. memory_limit constrains DuckDB's buffer manager, not the entire process RSS. Exact quantiles/distinct counts, import intermediates and result buffers can exceed it. Disk spill follows DuckDB behavior. No idle timers or animation loops are installed.

Reproduction: `VAPULA_BENCHMARK=1 VAPULA_BENCHMARK_OUTPUT=/tmp/vapula-benchmark.json ./script/test.sh --filter PerformanceTests`. The test generates a synthetic million-row/four-column CSV in chunks, times import, the final 100-row page and a full profile, and records process peak RSS using getrusage. Test-runner peak includes runtime/test overhead. Debug results are labeled as such; they are not release-build budgets or guarantees. Measured output is below and in VALIDATION.md.

Engineering targets (assumptions, not measured claims): responsive page navigation under one second on ordinary local datasets; idle CPU near zero; no unbounded table materialization in UI. Sustained energy use, thermal state, GPU frame time and UI energy/GPU profiling remain separate future measurements.

## Measured optimized integration run

2026-10-30, same Apple M1 / 8 GB host, release test runner, synthetic 1,000,000 rows / four columns: import **0.209 s**, final 100-row page **0.00493 s**, complete profile **0.205 s**, process peak RSS **262,520,832 bytes (250.4 MiB)**, database **4,468,736 bytes**. This is one warm local run, not a benchmark across devices or data distributions. The input is generated for the test and contains no personal data. Machine-readable evidence is in `docs/evidence/benchmark-release.json`. Repeated validation runs do not establish independent performance improvement.


## Full-suite workbench validation

2026-10-31, concurrent full release suite including PDF/image tests: import 0.192 s, final page 0.383 s, full profile 0.276 s; whole test-process peak 640,581,632 bytes (610.9 MiB). This is not isolated application RSS or evidence of a regression/improvement relative to the earlier differently loaded run. Machine output: `evidence/benchmark-integrated-release.json`.
