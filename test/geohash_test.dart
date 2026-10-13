import 'package:cylinq/core/utils/geohash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes the reference point', () {
    expect(Geohash.encode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
  });

  test('decodes back to the cell centre', () {
    final (lat, lng) = Geohash.decode('u4pruydqqvj')!;
    expect(lat, closeTo(57.64911, 1e-4));
    expect(lng, closeTo(10.40744, 1e-4));
  });

  test('a Kolkata delivery lands in a 6-char cell around it', () {
    final hash = Geohash.encode(22.5726, 88.3639);
    expect(hash.length, 6);
    final (lat, lng) = Geohash.decode(hash)!;
    expect(lat, closeTo(22.5726, 0.01));
    expect(lng, closeTo(88.3639, 0.01));
  });

  test('rejects characters outside base32', () {
    expect(Geohash.decode('abc!'), isNull);
  });
}
