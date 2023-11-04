import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

void check(Iterable<File> files) {
  final comments = [];
  for (final file in files) {
    final result = parseFile(
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    comments.addAll(findComments(result));
  }
}

List<String> findComments(ParseStringResult result) {
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
    comments.addAll(
      comment
          .replaceAll(RegExp(r'\[[\w\\.]+\]'), '')
          .replaceAll(RegExp(r'`.+`'), '')
          .split(RegExp(r'\s+'))
          .where((e) => RegExp(r'\w+').hasMatch(e)),
    );
    return super.visitComment(node);
  }
}
