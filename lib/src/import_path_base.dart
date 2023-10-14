// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Based on the original work of:
// - Jacob MacDonald: jakemac53 on GitHub
//
// Conversion to library:
// - Graciliano M. Passos: gmpassos @ GitHub
//

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:ascii_art_tree/ascii_art_tree.dart';
import 'package:graph_explorer/graph_explorer.dart';
import 'package:path/path.dart' as p;

import 'import_path_parser.dart';
import 'import_path_scanner.dart';

typedef MessagePrinter = void Function(Object? m);

/// Base class [ImportPath], [ImportPathScanner] and [ImportParser].
abstract class ImportWidget {
  /// If `true`, we won't call [printMessage].
  final bool quiet;

  /// The function to print messages/text. Default: [print].
  /// Called by [printMessage].
  MessagePrinter messagePrinter;

  ImportWidget({this.quiet = false, this.messagePrinter = print});

  /// Prints a message/text.
  /// - See [messagePrinter].
  void printMessage(Object? m) => messagePrinter(m);
}

/// The import to find using [ImportPath].
/// - See [ImportToFindURI] and [ImportToFindRegExp].
abstract class ImportToFind extends NodeMatcher<Uri> {
  /// Resolves [o] (an [Uri], [String], [RegExp] or [ImportToFind])
  /// and returns an [ImportToFind].
  /// - If [o] is a [String] it should be a valid [Uri].
  /// - See [ImportToFindURI] and [ImportToFindRegExp].
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

  @override
  bool matchesValue(Uri value) => matches(value);

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

/// Import Path search tool.
class ImportPath extends ImportWidget {
  /// The entry point to start the search.
  final Uri from;

  /// The import to find. Can be an [Uri] or a [RegExp].
  /// See [ImportToFind.from].
  final ImportToFind importToFind;

  /// If `true` searches for all import matches.
  /// See [ImportPathScanner.findAll].
  final bool findAll;

  /// If `true` remove from paths the [searchRoot].
  final bool strip;

  /// If `true`, it will use a fast parser that attempts to
  /// parse only the import section of Dart files. Default: `false`.
  /// See [ImportPathScanner.fastParser].
  final bool fastParser;

  /// If `true`, it will also scan imports that depend on an `if` resolution. Default: `true`.
  /// See [ImportPathScanner.includeConditionalImports].
  final bool includeConditionalImports;

  /// The search root to strip from the displayed import paths.
  /// - If `searchRoot` is not provided at construction it's resolved
  ///   using [from] parent directory (see [resolveSearchRoot]).
  late String searchRoot;

  ImportPath(this.from, Object importToFind,
      {this.findAll = false,
      bool quiet = false,
      this.strip = false,
      this.fastParser = false,
      this.includeConditionalImports = true,
      String? searchRoot,
      MessagePrinter messagePrinter = print})
      : importToFind = ImportToFind.from(importToFind),
        super(quiet: quiet, messagePrinter: messagePrinter) {
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

  /// Executes the import search and prints the results.
  /// - [style] defines the output format. Default: [ImportPathStyle.elegant]
  /// - See [search], [printMessage] and [ASCIIArtTree].
  Future<ASCIIArtTree?> execute(
      {ImportPathStyle style = ImportPathStyle.elegant,
      Directory? packageDirectory}) async {
    var tree = await search(
        style: style.asASCIIArtTreeStyle ?? ASCIIArtTreeStyle.elegant,
        packageDirectory: packageDirectory);

    if (tree != null) {
      if (!quiet) {
        printMessage('');
      }

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
        var totalFoundPaths = tree.totalLeaves;
        if (totalFoundPaths > 1) {
          printMessage(
              '» Found $totalFoundPaths import paths from $from to $importToFind\n');
        }
      }
    }

    return tree;
  }

  /// Performs the imports search and returns the tree.
  /// - [style] defines [ASCIIArtTree] style. Default: [ASCIIArtTreeStyle.elegant]
  /// - See [searchPaths] and [ASCIIArtTree].
  Future<ASCIIArtTree?> search(
      {ASCIIArtTreeStyle style = ASCIIArtTreeStyle.elegant,
      Directory? packageDirectory}) async {
    var foundPaths = await searchPaths(packageDirectory: packageDirectory);
    if (foundPaths.isEmpty) return null;

    var asciiArtTree = ASCIIArtTree.fromPaths(
      foundPaths,
      stripPrefix: _stripSearchRoot,
      style: style,
    );

    return asciiArtTree;
  }

  /// Performs the imports search and returns the found import paths.
  /// - [packageDirectory] is used to resolve . Default: [Directory.current].
  /// - Uses [ImportPathScanner].
  Future<List<List<String>>> searchPaths({Directory? packageDirectory}) async {
    var importPathScanner = ImportPathScanner(
        findAll: findAll,
        fastParser: fastParser,
        messagePrinter: messagePrinter,
        quiet: quiet,
        includeConditionalImports: includeConditionalImports);

    var foundPaths = await importPathScanner.searchPaths(from, importToFind,
        stripSearchRoot: _stripSearchRoot, packageDirectory: packageDirectory);

    var foundPathsStr = foundPaths.toListOfStringPaths();
    return foundPathsStr;
  }
}
