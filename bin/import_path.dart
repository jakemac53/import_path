// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:import_path/import_path.dart';

void _showHelp() {
  print('''
╔═════════════════════╗
║  import_path - CLI  ║
╚═════════════════════╝

USAGE:

  import_path %startSearchFile %targetImport -s -q --all

OPTIONS:

  --regexp   # Parses `%targetImport` as a `RegExp`.
  --all      # Searches for all the import paths.
  -s         # Strips the search root directory from displayed import paths.
  -q         # Quiet output (only displays found paths).
  --elegant  # Use `elegant` style for the output tree (default).
  --dots     # Use `dots` style for the output tree.

EXAMPLES:

  # Search for the shortest import path of `dart:io` in a `web` directory:
  import_path web/main.dart dart:io

  # Search all the import paths of a deferred library,
  # stripping the search root directory from the output:
  import_path web/main.dart web/lib/deferred_lib.dart --all -s

  # For a quiet output (no headers or warnings, only displays found paths):
  import_path web/main.dart dart:io -q

  # Search for all the imports for "dart:io" and "dart:html" using `RegExp`:
  import_path web/main.dart "dart:(io|html)" --regexp --all

''');
}

void main(List<String> args) async {
  var help = args.length < 2 || args.any((a) => a == '--help' || a == '-h');
  if (help) {
    _showHelp();
    return;
  }

  var from = Uri.base.resolve(args[0]);
  dynamic importToFind = args[1];

  var regexp = args.length > 2 && args.any((a) => a == '--regexp');
  var findAll = args.length > 2 && args.any((a) => a == '--all');
  var quiet = args.length > 2 && args.any((a) => a == '-q');
  var strip = args.length > 2 && args.any((a) => a == '-s');
  var dots = args.length > 2 && args.any((a) => a == '--dots');

  if (regexp) {
    importToFind = RegExp(importToFind);
  } else {
    importToFind = Uri.base.resolve(importToFind);
  }

  var importPath = ImportPath(from, importToFind,
      findAll: findAll, quiet: quiet, strip: strip);

  await importPath.execute(dots: dots);
}
