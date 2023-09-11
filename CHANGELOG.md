# 1.2.0

- Moved code to class `ImportPath`, `ImportPathScanner` and `ImportParser`:
  - Allows integration with other packages.
  - Facilitates tests.
- Using `ascii_art_tree` to show the output tree, with styles `dots` (original) and `elegant`.
- CLI:
  - Added options:
    - `--regexp`: to use `RegExp` to match the target import.
    - `--all`: to find all the import paths. 
    - `--quiet`: for a quiet output (only displays found paths).
    - `--strip`: strips the search root directory from displayed import paths.
    - `--format`: Defines the style for the output tree (elegant, dots, json).
    - `--fast`: to enable a fast import parser.
  - Improved help with examples.
- `ImportParser`:
  - Added faster parser.
  - Added support to conditional imports.
- `ImportPathScanner`:
  - Added support to final all the target imports.
  - Optimized resolution of paths graph.
- Updated `README.md` to show CLI and Library usage.
- Added tests and coverage (80%).
- Added GitHub Dart CI.

- Updated dependencies compatible with Dart `2.14.0` (was already dependent to SDK `2.14.0`): 
  - sdk: '>=2.14.0 <3.0.0'
  - package_config: ^2.1.0
  - path: ^1.8.3
  - args: ^2.4.2
  - ascii_art_tree: ^1.0.5
  - graph_explorer: ^1.0.0
  - lints: ^1.0.1
  - dependency_validator: ^3.2.2
  - test: ^1.21.4
  - coverage: ^1.2.0

# 1.1.1

- Add explicit executables config to the pubspec.yaml.

# 1.1.0

- Support reading generated to cache files from build_runner.
- Update analyzer dependency.
- Migrate to null safety.

# 1.0.2

Update analyzer and package_config dependencies.

# 1.0.1

Use the local package config so it actually works for arbitrary things :D.

# 1.0.0+1

Add changelog :D

# 1.0.0

Initial release
