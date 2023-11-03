import 'dart:io';

import 'package:dart_spell_checker/dart_spell_checker.dart';

void main(List<String> arguments) {
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
  check(files);
}
