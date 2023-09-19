// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Based on the original work of:
// - Jacob MacDonald: jakemac53 on GitHub
//
// Faster parser by:
// - Graciliano M. Passos: gmpassos @ GitHub
//

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

import 'import_path_base.dart';

/// Dart import parser.
/// Parses for import directives in Dart files.
class ImportParser extends ImportWidget {
  /// The Dart package [Directory], root of [PackageConfig].
  final Directory packageDirectory;

  /// If `true`, it will include the imports that
  /// depend on an `if` resolution. Default: `true`.
  final bool includeConditionalImports;

  /// If `true`, it will use a fast parser that attempts to
  /// parse only the import section of Dart files. Default: `false`.
  ///
  /// The faster parser is usually 2-3 times faster.
  /// To perform fast parsing, it first tries to detect the last import line
  /// using a simple [RegExp] match, then parses the file only up to the last
  /// import. If it fails, it falls back to full-file parsing.
  final bool fastParser;

  final PackageConfig _packageConfig;
  final String _generatedDir;

  ImportParser(this.packageDirectory, this._packageConfig,
      {this.includeConditionalImports = true,
      this.fastParser = false,
      bool quiet = false,
      MessagePrinter messagePrinter = print})
      : _generatedDir = p.join('.dart_tool/build/generated'),
        super(quiet: quiet, messagePrinter: messagePrinter);

  static Future<ImportParser> from(Directory packageDirectory,
      {bool includeConditionalImports = true,
      bool fastParser = false,
      bool quiet = false,
      MessagePrinter messagePrinter = print}) async {
    var packageConfig = (await findPackageConfig(packageDirectory))!;
    return ImportParser(packageDirectory, packageConfig,
        includeConditionalImports: includeConditionalImports,
        fastParser: fastParser,
        quiet: quiet,
        messagePrinter: messagePrinter);
  }

  /// Resolves an [uri] from [packageDirectory].
  Uri resolveUri(Uri uri) =>
      uri.scheme == 'package' ? _packageConfig.resolve(uri)! : uri;

  final Map<Uri, List<Uri>> _importsCache = {};

  /// Disposes the internal imports cache.
  void disposeCache() {
    _importsCache.clear();
  }

  /// Returns the imports for [uri].
  /// - If [cached] is `true` will use the internal cache of resolved imports.
  List<Uri> importsFor(Uri uri, {bool cached = true}) {
    if (cached) {
      return UnmodifiableListView(_importsCache[uri] ??= _importsForImpl(uri));
    } else {
      return _importsForImpl(uri);
    }
  }

  List<Uri> _importsForImpl(Uri uri) {
    if (uri.scheme == 'dart') return [];

    final isSchemePackage = uri.scheme == 'package';

    var filePath =
        (isSchemePackage ? _packageConfig.resolve(uri) : uri)?.toFilePath();

    if (filePath == null) {
      if (!quiet) {
        printMessage('» [WARNING] Unable to resolve Uri $uri, skipping it');
      }
      return [];
    }

    var file = File(filePath);

    // Check the [_generatedDir] for package:build
    if (!file.existsSync()) {
      var package = isSchemePackage
          ? _packageConfig[uri.pathSegments.first]
          : _packageConfig.packageOf(uri);

      if (package == null) {
        if (!quiet) {
          printMessage('» [WARNING] Unable to read file at $uri, skipping it');
        }
        return [];
      }

      var path = isSchemePackage
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

    var content = file.readAsStringSync();

    var importDirectives = _parseImportDirectives(content, quiet);
    var importsUris = _filterImportDirectiveUris(importDirectives, uri);

    return importsUris;
  }

  List<Uri> _filterImportDirectiveUris(
          Iterable<NamespaceDirective> importDirectives, Uri uri) =>
      importDirectives
          .expand((directive) {
            var mainUri = directive.uri.stringValue!;

            if (includeConditionalImports &&
                directive.configurations.isNotEmpty) {
              var conditional = directive.configurations
                  .map((e) => e.uri.stringValue)
                  .whereType<String>()
                  .toList();

              var multiple = [mainUri, ...conditional];
              return multiple;
            } else {
              return [mainUri];
            }
          })
          .map((directiveUriStr) => uri.resolve(directiveUriStr))
          .toList();

  Iterable<NamespaceDirective> _parseImportDirectives(
      String content, bool quiet) {
    if (fastParser) {
      var header = _extractHeader(content);
      if (header != null) {
        var headerParsed =
            parseString(content: header, throwIfDiagnostics: false);
        if (headerParsed.errors.isEmpty) {
          return _filterImportDirectives(headerParsed, quiet);
        }
      }
    }

    var parsed = parseString(content: content, throwIfDiagnostics: false);
    return _filterImportDirectives(parsed, quiet);
  }

  Iterable<NamespaceDirective> _filterImportDirectives(
      ParseStringResult parsed, bool quiet) {
    var importDirectives = parsed.unit.directives
        .whereType<NamespaceDirective>()
        .where((directive) {
      var uriNull = directive.uri.stringValue == null;
      if (uriNull && !quiet) {
        printMessage('Empty uri content: ${directive.uri}');
      }
      return !uriNull;
    });

    return importDirectives;
  }

  static final _regExpImport = RegExp(
      r'''(?:^|\n)[ \t]*(?:import|export)\s*['"][^\r\n'"]+?['"]\s*.*?;''',
      dotAll: true);

  String? _extractHeader(String content) {
    var importMatches =
        _regExpImport.allMatches(content).toList(growable: false);

    if (importMatches.isEmpty) return null;

    var headEndIdx = importMatches.last.end;
    var header = content.substring(0, headEndIdx);

    return header.isNotEmpty ? header : null;
  }
}
