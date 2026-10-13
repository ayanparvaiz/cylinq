/// Minimal geohash encode/decode. Deliveries are bucketed into 6-character
/// cells (about 1.2 km × 0.6 km) so the daily stats doc stays small and the
/// heatmap needs no per-sale reads.
abstract final class Geohash {
  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(double lat, double lng, {int precision = 6}) {
    var latMin = -90.0, latMax = 90.0;
    var lngMin = -180.0, lngMax = 180.0;
    final out = StringBuffer();
    var bit = 0, ch = 0;
    var even = true;
    while (out.length < precision) {
      if (even) {
        final mid = (lngMin + lngMax) / 2;
        if (lng >= mid) {
          ch = (ch << 1) | 1;
          lngMin = mid;
        } else {
          ch <<= 1;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          ch = (ch << 1) | 1;
          latMin = mid;
        } else {
          ch <<= 1;
          latMax = mid;
        }
      }
      even = !even;
      if (++bit == 5) {
        out.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return out.toString();
  }

  /// Centre of the cell as (lat, lng), or null for an invalid hash.
  static (double, double)? decode(String hash) {
    var latMin = -90.0, latMax = 90.0;
    var lngMin = -180.0, lngMax = 180.0;
    var even = true;
    for (final c in hash.toLowerCase().split('')) {
      final v = _base32.indexOf(c);
      if (v < 0) return null;
      for (var mask = 16; mask > 0; mask >>= 1) {
        final on = v & mask != 0;
        if (even) {
          final mid = (lngMin + lngMax) / 2;
          on ? lngMin = mid : lngMax = mid;
        } else {
          final mid = (latMin + latMax) / 2;
          on ? latMin = mid : latMax = mid;
        }
        even = !even;
      }
    }
    return ((latMin + latMax) / 2, (lngMin + lngMax) / 2);
  }
}
