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
    final comment = node.tokens.map((e) => e.lexeme).join('\n');
    comments.add(comment);
    return super.visitComment(node);
  }
}
