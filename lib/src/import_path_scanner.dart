// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Based on the original work of (shortest path):
// - Jacob MacDonald: jakemac53 on GitHub
//
// Resolve all import paths and optimizations by:
// - Graciliano M. Passos: gmpassos @ GitHub
//

import 'dart:io';

import 'package:graph_explorer/graph_explorer.dart';

import 'import_path_base.dart';
import 'import_path_parser.dart';

/// Import Path Scanner tool.
class ImportPathScanner extends ImportWidget {
  /// If `true` searches for all import matches.
  final bool findAll;

  /// If `true`, it will use a fast parser that attempts to
  /// parse only the import section of Dart files. Default: `false`.
  /// See [ImportParser.fastParser].
  final bool fastParser;

  /// If `true`, it will also scan imports that depend on an `if` resolution. Default: `true`.
  /// See [ImportParser.includeConditionalImports].
  final bool includeConditionalImports;

  ImportPathScanner(
      {this.findAll = false,
      bool quiet = false,
      this.fastParser = false,
      this.includeConditionalImports = true,
      MessagePrinter messagePrinter = print})
      : super(quiet: quiet, messagePrinter: messagePrinter);

  Future<List<List<Node<Uri>>>> searchPaths(Uri from, ImportToFind importToFind,
      {Directory? packageDirectory, String? stripSearchRoot}) async {
    packageDirectory ??= Directory.current;

    final importParser = await ImportParser.from(packageDirectory,
        includeConditionalImports: includeConditionalImports,
        fastParser: fastParser,
        quiet: quiet,
        messagePrinter: messagePrinter);

    var scanner = GraphScanner<Uri>(findAll: findAll);

    if (!quiet) {
      printMessage('» Search entry point: $from');

      if (stripSearchRoot != null) {
        printMessage(
            '» Stripping search root from displayed imports: $stripSearchRoot');
      }

      var msgSearching = fastParser ? 'Fast searching' : 'Searching';

      if (findAll) {
        printMessage(
            '» $msgSearching for all import paths for `$importToFind`...');
      } else {
        printMessage(
            '» $msgSearching for the shortest import path for `$importToFind`...');
      }
    }

    var result = await scanner.scanPathsFrom(
      from,
      importToFind,
      outputsProvider: (graph, node) => importParser
          .importsFor(node.value)
          .map((uri) => graph.node(uri))
          .toList(),
      maxExpansion: 100,
    );

    var paths = result.paths;
    if (!findAll) {
      paths = paths.shortestPaths();
    }

    if (!quiet) {
      printMessage(
          "» Search finished [total time: ${result.time.inMilliseconds} ms, resolve paths time: ${result.resolvePathsTime.inMilliseconds} ms]");
    }

    return paths;
  }
}
