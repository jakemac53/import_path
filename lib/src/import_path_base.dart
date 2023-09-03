// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:ascii_art_tree/ascii_art_tree.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// An Import Path search tool.
class ImportPath {
  /// The entry point to start the search.
  final Uri from;

  /// The import to find. Can be an [Uri] or a [RegExp].
  dynamic importToFind;

  /// If `true` searches for all import matches.
  final bool findAll;

  /// If quiet won't call [printMessage] while searching.
  final bool quiet;

  /// If `true` remove from paths the [searchRoot].
  final bool strip;

  String? _searchRoot;

  /// The function to print messages/text. Default: [print].
  /// Called by [printMessage].
  void Function(Object? m) messagePrinter;

  ImportPath(this.from, this.importToFind,
      {this.findAll = false,
      this.quiet = false,
      this.strip = false,
      String? searchRoot,
      this.messagePrinter = print})
      : _searchRoot = searchRoot {
    if (importToFind is String) {
      importToFind = Uri.parse(importToFind);
    }

    if (importToFind is! Uri && importToFind is! RegExp) {
      throw ArgumentError(
          "Invalid `importToFind`, not an `Uri` or `RegExp`: $importToFind");
    }
  }

  /// The search root to strip from the displayed import paths.
  /// - If `searchRoot` is not provided at construction it's resolved
  ///   using [from] parent directory (see [resolveSearchRoot]).
  /// - See [strip] and [stripSearchRoot].
  String get searchRoot => _searchRoot ??= resolveSearchRoot();

  set searchRoot(String value) => _searchRoot = value;

  /// This list contains common Dart root directories.
  /// These names are preserved by [resolveSearchRoot] to prevent
  /// them from being stripped. Default: `'web', 'bin', 'src', 'test', 'example'`
  List<String> commonRootDirectories = ['web', 'bin', 'src', 'test', 'example'];

  /// Resolves the [searchRoot] using [from] parent.
  /// See [commonRootDirectories].
  String resolveSearchRoot() {
    var rootPath = p.dirname(from.path);
    var rootDirName = p.split(rootPath).last;

    if (commonRootDirectories.contains(rootDirName)) {
      var rootPath2 = p.dirname(rootPath);
      if (rootPath2.isNotEmpty) {
        rootPath = rootPath2;
      }
    }

    var rootUri = from.replace(path: rootPath).toString();
    return rootUri.endsWith('/') ? rootUri : '$rootUri/';
  }

  /// Return the search root to [strip] from the displayed import paths.
  /// If [strip] is `false` returns `null`.
  /// See [searchRoot].
  String? get stripSearchRoot => strip ? searchRoot : null;

  /// Prints a message/text.
  /// - Called by [execute].
  /// - See [messagePrinter].
  void printMessage(Object? m) => messagePrinter(m);

  /// Executes the import search and prints the results.
  /// - If `dots` is `true` it prints the tree in `dots` style
  /// - See [printMessage] and [ASCIIArtTree].
  Future<ASCIIArtTree?> execute({bool dots = false}) async {
    if (!quiet) {
      printMessage('» Search entry point: $from');

      if (strip) {
        printMessage(
            '» Stripping search root from displayed imports: $searchRoot');
      }

      if (findAll) {
        printMessage(
            '» Searching for all import paths for `$importToFind`...\n');
      } else {
        printMessage(
            '» Searching for the shortest import path for `$importToFind`...\n');
      }
    }

    var tree = await search(dots: dots);

    if (tree != null) {
      var treeText = tree.generate();
      printMessage(treeText);
    }

    if (!quiet) {
      if (tree == null) {
        printMessage(
            '» Unable to find an import path from $from to $importToFind');
      } else {
        var totalFoundPaths = tree.totalLeafs;
        if (totalFoundPaths > 1) {
          printMessage(
              '» Found $totalFoundPaths import paths from $from to $importToFind\n');
        }
      }
    }

    return tree;
  }

  /// Performs the imports search and returns the tree.
  /// - If [dots] is `true` uses the `dots` style for the tree.
  /// - See [ASCIIArtTree].
  Future<ASCIIArtTree?> search({bool dots = false}) async {
    var foundPaths = await searchPaths();
    if (foundPaths == null || foundPaths.isEmpty) return null;

    var asciiArtTree = ASCIIArtTree.fromPaths(
      foundPaths,
      stripPrefix: stripSearchRoot,
      style: dots ? ASCIIArtTreeStyle.dots : ASCIIArtTreeStyle.elegant,
    );

    return asciiArtTree;
  }

  late PackageConfig _packageConfig;
  late String _generatedDir;

  /// Performs the imports search and returns the found import paths.
  Future<List<List<String>>?> searchPaths() async {
    var currentDir = Directory.current;
    _packageConfig = (await findPackageConfig(currentDir))!;
    _generatedDir = p.join('.dart_tool/build/generated');

    var root = from.scheme == 'package' ? _packageConfig.resolve(from)! : from;

    var foundPaths = _searchImportPaths(root, stripSearchRoot: stripSearchRoot);

    var foundCount = foundPaths.length;
    if (foundCount <= 0) {
      return null;
    }

    if (!findAll) {
      foundPaths.sort((a, b) => a.length.compareTo(b.length));
      var shortest = foundPaths.first;
      return [shortest];
    } else {
      return foundPaths;
    }
  }

  List<List<String>> _searchImportPaths(
    Uri node, {
    String? stripSearchRoot,
    Set<Uri>? walked,
    List<String>? parents,
    List<List<String>>? found,
  }) {
    found ??= [];

    if (walked == null) {
      walked = {node};
    } else if (!walked.add(node)) {
      return found;
    }

    final nodePath = node.toString();
    if (parents == null) {
      parents = [nodePath];
    } else {
      parents.add(nodePath);
    }

    var newImports = _importsFor(node, quiet: quiet)
        .where((uri) => !walked!.contains(uri))
        .toList(growable: false);

    for (var import in newImports) {
      if (_matchesImport(importToFind, import)) {
        var foundPath = [...parents, import.toString()];
        found.add(foundPath);
      } else {
        _searchImportPaths(import,
            stripSearchRoot: stripSearchRoot,
            walked: walked,
            parents: parents,
            found: found);
      }
    }

    var rm = parents.removeLast();
    assert(rm == nodePath);

    return found;
  }

  bool _matchesImport(Object importToFind, Uri import) {
    if (importToFind is RegExp) {
      return importToFind.hasMatch(import.toString());
    } else {
      return importToFind == import;
    }
  }

  List<Uri> _importsFor(Uri uri, {required bool quiet}) {
    if (uri.scheme == 'dart') return [];

    var filePath = (uri.scheme == 'package' ? _packageConfig.resolve(uri) : uri)
        ?.toFilePath();

    if (filePath == null) {
      if (!quiet) {
        printMessage('» [WARNING] Unable to resolve Uri $uri, skipping it');
      }
      return [];
    }

    var file = File(filePath);
    // Check the generated dir for package:build
    if (!file.existsSync()) {
      var package = uri.scheme == 'package'
          ? _packageConfig[uri.pathSegments.first]
          : _packageConfig.packageOf(uri);
      if (package == null) {
        if (!quiet) {
          printMessage('» [WARNING] Unable to read file at $uri, skipping it');
        }
        return [];
      }

      var path = uri.scheme == 'package'
          ? p.joinAll(uri.pathSegments.skip(1))
          : p.relative(uri.path, from: package.root.path);
      file = File(p.join(_generatedDir, package.name, path));
      if (!file.existsSync()) {
        if (!quiet) {
          printMessage('» [WARNING] Unable to read file at $uri, skipping it');
        }
        return [];
      }
    }

    var contents = file.readAsStringSync();

    var parsed = parseString(content: contents, throwIfDiagnostics: false);
    return parsed.unit.directives
        .whereType<NamespaceDirective>()
        .where((directive) {
          if (directive.uri.stringValue == null && !quiet) {
            printMessage('Empty uri content: ${directive.uri}');
          }
          return directive.uri.stringValue != null;
        })
        .map((directive) => uri.resolve(directive.uri.stringValue!))
        .toList();
  }
}
