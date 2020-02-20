A tool to find the shortest import path from one dart file to another.

## Usage

First, globally activate the package:

`pub global activate import_path`

Then run it, the first argument is the library or application that you want to
start searching from, and the second argument is the import you want to search
for.

`import_path <entrypoint> <import>`

Files should be specified as dart import uris, so relative or absolute file
paths, as well as `package:` and `dart:` uris are supported.

## Example

From the root of this package, you can do:

```
pub global activate import_path
import_path bin/import_path.dart package:analyzer/dart/ast/ast.dart
```
