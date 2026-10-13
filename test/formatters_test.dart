import 'package:cylinq/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 13, 12);

  test('ago reads naturally', () {
    expect(ago(now.subtract(const Duration(hours: 3)), now: now), 'today');
    expect(ago(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
    expect(ago(now.subtract(const Duration(days: 75)), now: now), '2 months ago');
    expect(ago(null, now: now), '—');
  });

  test('rupees use Indian grouping and drop zero paise', () {
    expect(rupees(123456), '₹1,23,456');
    expect(rupees(905.5), '₹905.50');
  });
}
