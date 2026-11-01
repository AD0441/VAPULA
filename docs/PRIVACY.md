# Privacy and runtime network

VAPULA operates on local files explicitly selected through a panel or Finder drop. There are no accounts, HTTP clients, servers, telemetry, online models, runtime dependency downloads, CDN assets or version-check services. Ko-fi opens the system browser only after the user clicks its link; ordinary work does not fetch that URL.

DuckDB auto-install and auto-load of extensions are disabled; unsigned extensions are disabled. HTTPFileSystem/S3/GCS/HuggingFace filesystems are disabled. CSV/TSV/Parquet paths are local URLs, generated SQL is closed over typed operations and literals are escaped. A manifest may only reference physical UUID-named tables. This is defense in depth, not a promise that arbitrary malformed native database files are harmless.

No network entitlements are requested. This build is not App Sandbox-enforced and absence of network entitlements alone does not prove no network capability. See VALIDATION.md for the actual source scan and observed runtime coverage. OS/browser activity is outside the application's own work.

Imported datasets live inside a portable .vapula package. Original files remain intact. Reports may include filenames, source hashes, column names and computed results: review them before sharing. Application logs contain lifecycle messages, never data rows or file paths. Preferences store interface language/appearance locally.

Observed on the available host: `lsof -a -c VAPULA -i -n -P` found no application IP sockets during an idle launched session; `rg` over application sources found no HTTP client or socket calls (only the explicit Ko-fi link). This is bounded evidence, not a packet capture and not a complete offline GUI workflow test. The visual workflow is now recorded in VALIDATION.md; network disconnection/packet capture was not exercised, so no broader offline network-isolation claim is made.
