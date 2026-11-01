# Third-party notices

- **DuckDB Swift / DuckDB 1.1.3**, Stichting DuckDB Foundation, official package: https://github.com/duckdb/duckdb-swift/tree/v1.1.3. MIT. Exact revision is in Package.resolved. License copied verbatim into Resources/Licenses/DuckDB-MIT.txt and bundled in the application. Upstream source includes further bundled components and their notices; these are preserved in Resources/Licenses/DuckDB-third-party/.
- SwiftUI, AppKit, CryptoKit and Swift Charts are Apple system frameworks; no extracted SF Symbols artwork is redistributed.
- The historical reference for the original VAPULA vector construction is https://commons.wikimedia.org/wiki/File:60-Vapula_seal.png (Mathers/Crowley, 1904; Commons marks it public domain). The raster is not included in this repository or the application. New vector construction and generator: project MIT.
- METATRON, PAIMON and RAZIEL/RadioWorkbench (AD0441) were inspected for native navigation, footer and documentation conventions. No source or assets were copied. No REA binary/decompilation claim is made: source inspection was sufficient, as the reverse-engineer-anything skill prescribes.
- SciPy 1.18.1 and NumPy 2.5.4 are used only by the optional reference-generation development script; their packages are not bundled or required at runtime. Reference inputs are synthetic.

- **KNIME Analytics Platform 5.4.4** was inspected read-only as a workflow UX reference, along with its official user guide. No KNIME source, executable code, icons or assets are copied into VAPULA or redistributed. Static evidence and scope limits are in docs/KNIME-REFERENCE.md. Swift Charts/CoreGraphics/CoreText implement VAPULA's charts and PDF independently.
