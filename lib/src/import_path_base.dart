// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:ascii_art_tree/ascii_art_tree.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// The import to find using [ImportPath].
/// - See [ImportToFindURI] and [ImportToFindRegExp].
abstract class ImportToFind {
  factory ImportToFind.from(Object o) {
    if (o is ImportToFind) {
      return o;
    } else if (o is Uri) {
      return ImportToFindURI(o);
    } else if (o is RegExp) {
      return ImportToFindRegExp(o);
    } else if (o is String) {
      return ImportToFindURI(Uri.parse(o));
    } else {
      throw ArgumentError("Can't resolve: $o");
    }
  }

  ImportToFind();

  /// Returns `true` if [importUri] matches the import to find.
  bool matches(Uri importUri);
}

/// An [Uri] implementation of [ImportToFind].
class ImportToFindURI extends ImportToFind {
  final Uri uri;

  ImportToFindURI(this.uri);

  @override
  bool matches(Uri importUri) => uri == importUri;

  @override
  String toString() => uri.toString();
}

/// A [RegExp] implementation of [ImportToFind].
class ImportToFindRegExp extends ImportToFind {
  final RegExp regExp;

  ImportToFindRegExp(this.regExp);

  @override
  bool matches(Uri importUri) => regExp.hasMatch(importUri.toString());

  @override
  String toString() => regExp.toString();
}

/// The [ImportPath] output style.
enum ImportPathStyle {
  dots,
  elegant,
  json,
}

ImportPathStyle? parseImportPathStyle(String s) {
  s = s.toLowerCase().trim();

  switch (s) {
    case 'dots':
      return ImportPathStyle.dots;
    case 'elegant':
      return ImportPathStyle.elegant;
    case 'json':
      return ImportPathStyle.json;
    default:
      return null;
  }
}

extension ImportPathStyleExtension on ImportPathStyle {
  ASCIIArtTreeStyle? get asASCIIArtTreeStyle {
    switch (this) {
      case ImportPathStyle.dots:
        return ASCIIArtTreeStyle.dots;
      case ImportPathStyle.elegant:
        return ASCIIArtTreeStyle.elegant;
      default:
        return null;
    }
  }
}

/// An Import Path search tool.
class ImportPath {
  /// The entry point to start the search.
  final Uri from;

  /// The import to find. Can be an [Uri] or a [RegExp].
  final ImportToFind importToFind;

  /// If `true` searches for all import matches.
  final bool findAll;

  /// If `true`, we won't call [printMessage] while searching.
  final bool quiet;

  /// If `true` remove from paths the [searchRoot].
  final bool strip;

  /// The search root to strip from the displayed import paths.
  /// - If `searchRoot` is not provided at construction it's resolved
  ///   using [from] parent directory (see [resolveSearchRoot]).
  late String searchRoot;

  /// The function to print messages/text. Default: [print].
  /// Called by [printMessage].
  void Function(Object? m) messagePrinter;

  ImportPath(this.from, Object importToFind,
      {this.findAll = false,
      this.quiet = false,
      this.strip = false,
      String? searchRoot,
      this.messagePrinter = print})
      : importToFind = ImportToFind.from(importToFind) {
    this.searchRoot = searchRoot ?? resolveSearchRoot();
  }

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
  String? get _stripSearchRoot => strip ? searchRoot : null;

  /// Prints a message/text.
  /// - Called by [execute].
  /// - See [messagePrinter].
  void printMessage(Object? m) => messagePrinter(m);

  /// Executes the import search and prints the results.
  /// - [style] defines the output format. Default: [ImportPathStyle.elegant]
  /// - See [printMessage] and [ASCIIArtTree].
  Future<ASCIIArtTree?> execute(
      {ImportPathStyle style = ImportPathStyle.elegant}) async {
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

    var tree = await search(style: style);

    if (tree != null) {
      if (style == ImportPathStyle.json) {
        var j = JsonEncoder.withIndent('  ').convert(tree.toJson());
        printMessage(j);
      } else {
        var treeText = tree.generate();
        printMessage(treeText);
      }
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
  /// - [style] defines [ASCIIArtTree] style. Default: [ImportPathStyle.elegant]
  /// - See [ASCIIArtTree].
  Future<ASCIIArtTree?> search(
      {ImportPathStyle style = ImportPathStyle.elegant}) async {
    var foundPaths = await searchPaths();
    if (foundPaths == null || foundPaths.isEmpty) return null;

    var asciiArtTree = ASCIIArtTree.fromPaths(
      foundPaths,
      stripPrefix: _stripSearchRoot,
      style: style.asASCIIArtTreeStyle ?? ASCIIArtTreeStyle.elegant,
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

    var foundPaths =
        _searchImportPaths(root, stripSearchRoot: _stripSearchRoot);
    if (foundPaths.isEmpty) {
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
      if (importToFind.matches(import)) {
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
