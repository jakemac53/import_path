// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

// Assigned early on in `main`.
late PackageConfig packageConfig;

main(List<String> args) async {
  if (args.length != 2) {
    print('''
Expected exactly two Dart files as arguments, a file to start
searching from and an import to search for.
''');
    return;
  }

  var from = Uri.base.resolve(args[0]);
  var importToFind = Uri.base.resolve(args[1]);
  packageConfig = (await findPackageConfig(Directory.current))!;

  var root = from.scheme == 'package' ? packageConfig.resolve(from)! : from;
  var queue = Queue<Uri>()..add(root);

  // Contains the closest parent to the root of the app for a given  uri.
  var parents = <String, String?>{root.toString(): null};
  while (queue.isNotEmpty) {
    var parent = queue.removeFirst();
    var newImports = _importsFor(parent)
        .where((uri) => !parents.containsKey(uri.toString()));
    queue.addAll(newImports);
    for (var import in newImports) {
      parents[import.toString()] = parent.toString();
      if (importToFind == import) {
        _printImportPath(import.toString(), parents, root.toString());
        return;
      }
    }
  }
  print('Unable to find an import path from $from to $importToFind');
}

final generatedDir = p.join('.dart_tool/build/generated');

List<Uri> _importsFor(Uri uri) {
  if (uri.scheme == 'dart') return [];

  var file = File((uri.scheme == 'package' ? packageConfig.resolve(uri) : uri)!
      .toFilePath());
  // Check the generated dir for package:build
  if (!file.existsSync()) {
    var package = uri.scheme == 'package'
        ? packageConfig[uri.pathSegments.first]
        : packageConfig.packageOf(uri);
    if (package == null) {
      print('Warning: unable to read file at $uri, skipping it');
      return [];
    }
    var path = uri.scheme == 'package'
        ? p.joinAll(uri.pathSegments.skip(1))
        : p.relative(uri.path, from: package.root.path);
    file = File(p.join(generatedDir, package.name, path));
    if (!file.existsSync()) {
      print('Warning: unable to read file at $uri, skipping it');
      return [];
    }
  }
  var contents = file.readAsStringSync();

  var parsed = parseString(content: contents, throwIfDiagnostics: false);
  return parsed.unit.directives
      .whereType<NamespaceDirective>()
      .where((directive) {
        if (directive.uri.stringValue == null) {
          print('Empty uri content: ${directive.uri}');
        }
        return directive.uri.stringValue != null;
      })
      .map((directive) => uri.resolve(directive.uri.stringValue!))
      .toList();
}

void _printImportPath(
    String import, Map<String, String?> parents, String root) {
  var path = <String>[];
  String? next = import;
  path.add(next);
  while (next != root && next != null) {
    next = parents[next];
    if (next != null) {
      path.add(next);
    }
  }
  var spacer = '';
  for (var import in path.reversed) {
    print('$spacer$import');
    spacer += '..';
  }
}
