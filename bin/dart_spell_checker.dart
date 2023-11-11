import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_spell_checker/dart_spell_checker.dart';

Future<void> main(List<String> arguments) async {
  final path = arguments.first;
  final dir = Directory(path);
  final Iterable<File> files;
  if (dir.statSync().type == FileSystemEntityType.file) {
    if (path.endsWith('.dart')) {
      files = [File(path)];
    } else {
      throw ArgumentError();
    }
  } else {
    files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((e) => e.path.endsWith('.dart'));
  }
  final result = await check(files);
  result.forEach((key, value) {
    final words = value.whereNot((e) => e.passed).sortedBy<num>((e) => e.line);
    if (words.isNotEmpty) {
      print('* ${key.path}');
      for (final word in words) {
        print('  * ${word.line}: ${word.value}');
      }
    }
  });
}
