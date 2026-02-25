import 'package:tom_reflector/tom_reflector.dart';
import 'package:test/test.dart';

void main() {
  test('creates analyzer instance', () {
    final analyzer = TomAnalyzer();
    expect(analyzer, isA<TomAnalyzer>());
  });
}
