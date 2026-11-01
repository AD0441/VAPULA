# Project format and integrity

A `.vapula` directory package contains `manifest.json`, `data.duckdb` and, while needed by DuckDB, `data.duckdb.wal`. Copy/move a project after closing it. Version 1 manifests are accepted; unknown schema versions are rejected without writing. No schema upgrade exists yet because no earlier released schema exists. Add explicit migrations before changing schemaVersion.

Sources record UUID, original filename, byte count, SHA-256, format, timestamp and import options. Raw files are never changed. Import materializes data into the embedded database; it does not silently keep an extra raw-file copy or temporary external reference. This first cut offers this single portable storage policy, explained before import; selecting a zero-copy external source policy is deferred.

Each DatasetVersion has a UUID-derived internal table name, source UUID, optional parent, typed operation, columns/types and row count. Transformations materialize new tables and preserve parents. Reverting means selecting an earlier version. Old versions consume storage until future explicit compaction is implemented.

Each analysis stores its specification (method, columns, group labels, alpha), dataset UUID, valid/excluded counts, metric values, procedure, warnings and date. Findings store rules and candidate counts by version; evidence is queried from that immutable table. Measurement scale defaults to unknown; user scale/unit editing is deferred and the UI warns against inferring scale from physical types.

A DuckDB transaction creates a version. Cancellation/error before commit rolls it back. After successful commit, JSON is atomically replaced. A crash between the two may leave an unreferenced internal table, never a manifest reference to an uncommitted table; orphan cleanup is deferred. A manifest-write failure drops the newly created table. No external source is used to reopen a project. Concurrent writers to the same project are unsupported; DuckDB enforces its file lock.

The source SHA-256 is checked before and after materialization inside the import transaction; if the source changed, import rolls back. Numeric profiles preserve the database's physical numeric type for distinct/min/max. Paired mathematical calculations use Double and have separate resolution limits.


## Additive workflow metadata

The optional `workflow` field records DataWorkflow version 1, at most 500 typed nodes, port references, positions, parameters, dirty/error state and output dataset/result IDs. It is backward compatible with schema-1 projects without the field. `sourceRowID` is query/UI identity and is not a new column in imported data. New preparation operations include missing-value policy/action, typed addColumn/appendRow/editCell and explicit removeRows. Each output is a fresh physical table with its own row identities. Removing canvas nodes does not remove historical datasets.
