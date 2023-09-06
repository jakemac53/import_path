import 'dart:io';
import 'dart:convert' show JsonEncoder;
import 'package:import_path/import_path.dart';
import 'package:import_path/src/import_path_base.dart';
import 'package:path/path.dart' as pack_path;
import 'package:test/test.dart';

void main() {
  group('ImportPath[shortest]', () {
    test(
        'strip: false ; dots: false ; quiet: false',
        () => doSearchTest(
            strip: false, dots: false, quiet: false, expectedTreeText: r'''
file://.../import_path.dart
  └─┬─ package:import_path/import_path.dart
    └─┬─ package:import_path/src/import_path_base.dart
      └──> package:analyzer/dart/ast/ast.dart
'''));

    test(
        'strip: false ; dots: false ; quiet: true',
        () => doSearchTest(
            strip: false, dots: false, quiet: true, expectedTreeText: r'''
file://.../import_path.dart
  └─┬─ package:import_path/import_path.dart
    └─┬─ package:import_path/src/import_path_base.dart
      └──> package:analyzer/dart/ast/ast.dart
'''));

    test(
        'strip: false ; dots: true ; quiet: false',
        () => doSearchTest(
            strip: false, dots: true, quiet: false, expectedTreeText: r'''
file://.../import_path.dart
..package:import_path/import_path.dart
....package:import_path/src/import_path_base.dart
......package:analyzer/dart/ast/ast.dart
'''));

    test(
        'strip: true ; dots: true ; quiet: false',
        () => doSearchTest(
            strip: true, dots: true, quiet: false, expectedTreeText: r'''
bin/import_path.dart
..package:import_path/import_path.dart
....package:import_path/src/import_path_base.dart
......package:analyzer/dart/ast/ast.dart
'''));
  });

  group('ImportPath[all]', () {
    test(
        'strip: true ; dots: true ; quiet: false',
        () => doSearchTest(
            strip: true,
            dots: true,
            quiet: false,
            all: true,
            expectedTreeText: RegExp(r'''^bin/import_path.dart
\..package:import_path/import_path.dart
\....package:import_path/src/import_path_base.dart
\......package:analyzer/dart/analysis/utilities.dart
.*?\........package:analyzer/dart/ast/ast.dart.*?
\......package:analyzer/dart/ast/ast.dart\s*$''', dotAll: true)));
  });
}

Future<void> doSearchTest(
    {required bool strip,
    required bool dots,
    required bool quiet,
    bool all = false,
    required Pattern expectedTreeText}) async {
  var output = [];

  var importPath = ImportPath(
    _resolveFileUri('bin/import_path.dart'),
    'package:analyzer/dart/ast/ast.dart',
    strip: strip,
    quiet: quiet,
    findAll: all,
    messagePrinter: (m) {
      output.add(m);
      print(m);
    },
  );

  var tree = await importPath.execute(
      style: dots ? ImportPathStyle.dots : ImportPathStyle.elegant);
  expect(tree, isNotNull);

  var outputIdx = 0;
  if (!quiet) {
    expect(output[outputIdx++], startsWith('» Search entry point:'));
    if (strip) {
      expect(output[outputIdx++],
          startsWith('» Stripping search root from displayed imports:'));
    }

    if (all) {
      expect(
          output[outputIdx++],
          equals(
              '» Searching for all import paths for `package:analyzer/dart/ast/ast.dart`...\n'));
    } else {
      expect(
          output[outputIdx++],
          equals(
              '» Searching for the shortest import path for `package:analyzer/dart/ast/ast.dart`...\n'));
    }
  }

  var treeText = output[outputIdx++]
      .toString()
      .replaceAll(RegExp(r'file://.*?/import_path/bin'), 'file://...');

  expect(treeText, matches(expectedTreeText));

  if (all) {
    expect(
        output[outputIdx++], matches(RegExp(r'» Found \d+ import paths from')));
  }

  expect(output.length, equals(outputIdx));

  {
    var output2 = [];

    var importPath2 = ImportPath(
      _resolveFileUri('bin/import_path.dart'),
      'package:analyzer/dart/ast/ast.dart',
      strip: strip,
      quiet: true,
      findAll: all,
      messagePrinter: (m) => output2.add(m),
    );

    var tree2 = await importPath2.execute(style: ImportPathStyle.json);

    expect(
        output2,
        equals([
          JsonEncoder.withIndent('  ').convert(tree2?.toJson()),
        ]));
  }
}

Uri _resolveFileUri(String targetFilePath) {
  var possiblePaths = [
    './',
    '../',
    './import_path',
  ];

  for (var p in possiblePaths) {
    var file = File(pack_path.join(p, targetFilePath));
    if (file.existsSync()) {
      return file.absolute.uri;
    }
  }

  return Uri.base.resolve(targetFilePath);
}
