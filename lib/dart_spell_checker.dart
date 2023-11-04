import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:collection/collection.dart';

Future<void> check(Iterable<File> files) async {
  for (final file in files) {
    final parsed = parseFile(
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    final result = await checkSpell(
      [...findComments(parsed), ...findDocComments(parsed)],
    );
  }
}

Future<Map<String, bool>> checkSpell(List<String> words) async {
  final process = await Process.start('aspell', ['-a', '-l', 'en_US']);
  final future = process.stdout.transform(utf8.decoder).first;
  process.stdin.writeln(words.join('\n'));
  final result = LineSplitter().convert(await future).skip(1);
  process.kill();
  return Map.fromEntries(
    result
        .where((e) => e.isNotEmpty)
        .map((e) => e == '*')
        .mapIndexed((i, e) => MapEntry(words[i], e)),
  );
}

List<String> findComments(ParseStringResult result) {
  return LineSplitter()
      .convert(result.content)
      .map((e) => RegExp(r'(?:[^/]|^)/{2}\s*([^/].+)').firstMatch(e))
      .map((e) => e?.group(1))
      .whereType<String>()
      .expand((e) => e.extractWords())
      .toList();
}

List<String> findDocComments(ParseStringResult result) {
  final visitor = _AstVisitor();
  result.unit.visitChildren(visitor);
  return visitor.comments;
}

class _AstVisitor extends RecursiveAstVisitor {
  final List<String> comments = [];

  @override
  visitComment(Comment node) {
    final start = node.offset;
    final blocks = node.codeBlocks
        .map(
          (e) => e.lines.map((e) {
            final s = e.offset - start;
            return (start: s, end: s + e.length);
          }),
        )
        .expand((e) => e)
        .toList()
        .reversed;
    final comment = blocks.fold(
      node.tokens.map((e) => e.lexeme).join('\n'),
      (previous, e) => previous.replaceRange(e.start, e.end, ''),
    );
    comments.addAll(comment.extractWords());
    return super.visitComment(node);
  }
}

extension on String {
  Iterable<String> extractWords() => replaceAll(RegExp(r'\[[\w\\.]+\]'), '')
      .replaceAll(RegExp(r'`.+`'), '')
      .split(RegExp(r'\s+'))
      .where((e) => RegExp(r'\w+').hasMatch(e));
}
