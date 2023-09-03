# import_path

A tool to find the shortest import path from one dart file to another.

## CLI Usage

First, globally activate the package:

```shell
dart pub global activate import_path
```

Then run it, the first argument is the library or application that you want to
start searching from, and the second argument is the import you want to search
for.

```shell
import_path <entrypoint> <import>
```

Files should be specified as dart import uris, so relative or absolute file
paths, as well as `package:` and `dart:` uris are supported.

## Examples

From the root of this package, you can do:

```shell
pub global activate import_path

import_path bin/import_path.dart package:analyzer/dart/ast/ast.dart
```

To find all the `dart:io` imports from a `web/main.dart`:

```shell
import_path web/main.dart dart:io --all
```

Search for all the imports for "dart:io" and "dart:html" using `RegExp`:

```shell
import_path web/main.dart "dart:(io|html)" --regexp --all
```
For help or more usage examples:

```shell
import_path --help
```

## Library Usage

You can also use the class `ImportPath` from your code:

```dart
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
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/jakemac53/import_path/issues

## Authors

- Jacob MacDonald: [jakemac53][github_jakemac53].
- Graciliano M. Passos: [gmpassos][github_gmpassos].

[github_jakemac53]: https://github.com/jakemac53
[github_gmpassos]: https://github.com/gmpassos

## License

Dart free & open-source [license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
