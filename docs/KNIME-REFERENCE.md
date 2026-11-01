# KNIME reference: observed scope and independent implementation

The author selected the installed KNIME Analytics Platform 5.4.4 application as a workflow UX reference. Its Info.plist reports 5.4.4. Local plugin inventory is recorded in `knime-static-inventory.json`. No reference installation was modified and no source, executable code, icons or assets were copied into VAPULA.

Official primary reference: [KNIME Analytics Platform 5.4 user guide](https://docs.knime.com/2024-12/analytics_platform_user_guide/index.html), describing workflow nodes, configuration, execution and result inspection. VAPULA adopts the general organization of connected steps with an intentionally bounded native interface. It does not claim KNIME engine compatibility or a complete node editor.

## REA static evidence

REA CLI 6.8.0 (`rea-agents` official registry package) analyzed the shipped JavaScript directory `org.knime.ui.js_5.4.4.v202504301444`. Only `dist/assets/WorkflowMonitor-D1CaORAA.js` and `dist/assets/ContextAwareDescription-ChZUdwhr.js` were selected. JavaScript was parsed as inert text; bootstrap code was never executed.

- Artifact SHA-256: `63eeddf12a5f24ff74fcd63d4264937ab0e6f2a9b5a2c63017495f3b3c9789bd`.
- Parent evidence: `ev_4f7aa77a19401622b3d9856e29ffefa4cbe303930a8df918de03a16956442d8a`.
- Summary evidence: `ev_0b5ca24f4af2192cae55f77d917d7f73c64fb1c094ab9b9560ca38961ffa30d2`.
- Parsed files: 2; parse failures: 0; visited AST nodes: 9551; text bytes: 35382.
- 33 inventoried files were outside caller-selected analysis scope. Application and semantic graphs are **partial**. Unresolved relationships and dynamic behavior remain unknown. Complete-within-view describes the summary projection only, not full application coverage.

The concise unmodified REA summary is `evidence/knime-rea-summary.json`. The 15.7 MB full evidence remains a local temporary investigation artifact at `/private/tmp/knime-vapula-rea-evidence-v4.json`; it is not redistributed with application/source. Initial attempts failed because the sandbox denied the Swift helper cache; an authorized elevated read-only run completed. No missing reverse-engineering engines were installed and no Codex MCP registration was changed.

The automated KNIME GUI launch did not yield a reliable inspection. Accordingly, no runtime KNIME workflow behavior or screenshot is claimed. Static component names support the scope of this investigation; they alone do not prove runtime state transitions.

## Applied design decision

VAPULA renders its own committed dataset lineage and analysis references, using SwiftUI/Canvas buttons and native actions: import → prepare → analyze → visualize → report. Method/assumption controls, query ownership, statistical algorithms, Swift Charts rendering and CoreGraphics PDFs are independent implementations verified against synthetic references and the local application. The reference informed organization, not code reuse.
