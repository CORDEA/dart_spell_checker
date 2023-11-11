import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:collection/collection.dart';

Future<void> check(Iterable<File> files) async {
  for (final file in files) {
    final content = file.readAsLinesSync();
    final parsed = parseString(
      content: content.join('\n'),
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    final result = await _checkSpell(
      [..._findComments(content), ..._findDocComments(parsed)],
    );
  }
}

Future<Map<_Comment, bool>> _checkSpell(List<_Comment> words) async {
  final process = await Process.start('aspell', ['-a', '-l', 'en_US']);
  final future = process.stdout.transform(utf8.decoder).first;
  process.stdin.writeln(words.map((e) => e.value).join('\n'));
  final result = LineSplitter().convert(await future).skip(1);
  process.kill();
  return Map.fromEntries(
    result
        .where((e) => e.isNotEmpty)
        .map((e) => e == '*')
        .mapIndexed((i, e) => MapEntry(words[i], e)),
  );
}

List<_Comment> _findComments(List<String> content) {
  return content
      .map((e) => RegExp(r'(?:[^/]|^)/{2}\s*([^/].+)').firstMatch(e)?.group(1))
      .mapIndexed((i, e) => e == null ? null : _Comment(value: e, line: i + 1))
      .whereType<_Comment>()
      .expand(
        (comment) => comment.value
            .extractWords()
            .map((e) => _Comment(value: e, line: comment.line)),
      )
      .toList();
}

List<_Comment> _findDocComments(ParseStringResult result) {
  final visitor = _AstVisitor(result.lineInfo);
  result.unit.visitChildren(visitor);
  return visitor.comments;
}

class _AstVisitor extends RecursiveAstVisitor {
  _AstVisitor(this.lineInfo);

  final List<_Comment> comments = [];
  final LineInfo lineInfo;

  @override
  visitComment(Comment node) {
    final start = node.offset;
    final line = lineInfo.getLocation(start).lineNumber;
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
    comments.addAll(
      comment
          .split('\n')
          .mapIndexed(
            (i, e) =>
                e.extractWords().map((e) => _Comment(value: e, line: line + i)),
          )
          .expand((e) => e),
    );
    return super.visitComment(node);
  }
}

extension on String {
  Iterable<String> extractWords() => replaceAll(RegExp(r'\[[\w\\.]+\]'), '')
      .replaceAll(RegExp(r'`.+`'), '')
      .split(RegExp(r'\s+'))
      .where((e) => RegExp(r'\w+').hasMatch(e));
}

class _Comment {
  _Comment({
    required this.value,
    required this.line,
  });

  final String value;
  final int line;

  @override
  String toString() => '_Comment(value: $value, line: $line)';
}
