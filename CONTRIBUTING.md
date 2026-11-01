# Contributing

Use a recent Swift 6.2+ / complete Xcode SDK. Run `./script/test.sh` and `./script/build_and_run.sh --verify`. Changes to calculations require independent references and declared tolerances; generate them with `script/generate_references.py` in a development-only SciPy environment. Never add Python/R as application runtime requirements.

Preserve local-only operation, immutable source data, version provenance and bounded UI pages. Use Swift Testing for new unit/integration tests; UI automation uses XCTest or actual native-app inspection. Keep screenshots and fixtures synthetic. Do not commit project packages, real datasets, credentials, DerivedData, binaries or .build. Include dependency licenses and document observed limits. Report defects with a synthetic reproduction and OS/toolchain details, excluding personal data.
