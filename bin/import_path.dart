// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'package:import_path/import_path.dart';

void _showHelp(ArgParser argsParser) {
  var usage = argsParser.usage
      .replaceAllMapped(RegExp(r'(^|\n)'), (m) => '${m.group(1)}  ');

  print('''
╔═════════════════════╗
║  import_path - CLI  ║
╚═════════════════════╝

USAGE:

  import_path %startSearchFile %targetImport -s -q --all

OPTIONS:

$usage

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
  var argsParser = ArgParser();

  argsParser.addFlag('help',
      abbr: 'h', negatable: false, help: "Show usage information");

  argsParser.addFlag('all',
      abbr: 'a', negatable: false, help: "Searches for all the import paths.");

  argsParser.addFlag('strip',
      abbr: 's',
      negatable: false,
      help: "Strips the search root directory from displayed import paths.");

  argsParser.addFlag('regexp',
      abbr: 'r',
      negatable: false,
      help: "Parses `%targetImport` as a `RegExp`.");

  argsParser.addFlag('fast',
      abbr: 'z',
      negatable: false,
      help:
          "Uses a fast Dart parser (only parses the import directives at the top).");

  argsParser.addFlag('quiet',
      abbr: 'q',
      negatable: false,
      help: "Quiet output (only displays found paths).");

  argsParser.addOption('format',
      abbr: 'f',
      allowed: ['elegant', 'dots', 'json'],
      defaultsTo: 'elegant',
      help: "The output format");

  var argsResult = argsParser.parse(args);

  var help = argsResult.arguments.isEmpty || argsResult['help'];
  if (help) {
    _showHelp(argsParser);
    return;
  }

  var regexp = argsResult['regexp'] as bool;
  var findAll = argsResult['all'] as bool;
  var quiet = argsResult['quiet'] as bool;
  var strip = argsResult['strip'] as bool;
  var fast = argsResult['fast'] as bool;

  var format = argsResult['format'] as String;

  var style = parseImportPathStyle(format) ?? ImportPathStyle.elegant;

  var from = Uri.base.resolve(argsResult.rest[0]);

  var importToFindArg = argsResult.rest[1];
  var importToFind =
      regexp ? RegExp(importToFindArg) : Uri.base.resolve(importToFindArg);

  var importPath = ImportPath(from, importToFind,
      findAll: findAll, quiet: quiet, strip: strip, fastParser: fast);

  await importPath.execute(style: style);
}
