# 1.2.0

- CLI:
  - Using `ascii_art_tree` to show the output tree, with styles `dots` (original) and `elegant`.
  - Added options:
    - `--regexp`: to use `RegExp` to match the target import.
    - `--all`: to find all the import paths. 
    - `--quiet`: for a quiet output (only displays found paths).
    - `--strip`: strips the search root directory from displayed import paths.
    - `--format`: Defines the style for the output tree (elegant, dots, json).
    - `--fast`: to enable a fast import parser.
  - Improved help with examples.
- Added support for conditional imports.
- Added public libraries to facilitate integration with other packages.
- Updated `README.md` to show CLI and Library usage.

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
