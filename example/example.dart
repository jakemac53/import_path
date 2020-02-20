import 'dart:io';

void main() async {
  var result = await Process.run('pub', [
    'run',
    'import_path',
    'bin/import_path.dart',
    'package:analyzer/dart/ast/ast.dart'
  ]);
  print(result.stdout);
}
