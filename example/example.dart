import 'package:import_path/import_path.dart';

void main(List<String> args) async {
  var strip = args.any((a) => a == '--strip' || a == '-s');

  var importPath = ImportPath(
    Uri.base.resolve('bin/import_path.dart'),
    'package:analyzer/dart/ast/ast.dart',
    strip: strip,
  );

  await importPath.execute();
}

/////////////////////////////////////
// OUTPUT: with argument `--strip` //
/////////////////////////////////////
// » Search entry point: file:///workspace/import_path/bin/import_path.dart
// » Stripping search root from displayed imports: file:///workspace/import_path/
// » Searching for the shortest import path for `package:analyzer/dart/ast/ast.dart`...
//
// bin/import_path.dart
//   └─┬─ package:import_path/import_path.dart
//     └─┬─ package:import_path/src/import_path_base.dart
//       └──> package:analyzer/dart/ast/ast.dart
