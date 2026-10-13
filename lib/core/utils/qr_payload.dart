/// What a CylinQ QR label encodes.
///
/// A URL rather than a bare serial, so a phone camera that is not running the
/// app still opens the web dashboard on that cylinder:
/// `https://cylinq.web.app/c/{orgId}/{serial}`.
abstract final class QrPayload {
  static const host = 'cylinq.web.app';

  static String forCylinder(String orgId, String serial) =>
      'https://$host/c/$orgId/$serial';

  /// Reads a scanned code. Accepts the URL form or a bare serial typed by hand.
  static ScannedCode? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme) {
      final seg = uri.pathSegments;
      if (seg.length == 3 && seg[0] == 'c' && seg[2].isNotEmpty) {
        return ScannedCode(orgId: seg[1], serial: seg[2].toUpperCase());
      }
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9]{1,8}-\d{1,8}$').hasMatch(text)) return null;
    return ScannedCode(serial: text.toUpperCase());
  }
}

class ScannedCode {
  const ScannedCode({required this.serial, this.orgId});

  final String serial;

  /// Null when the serial was typed by hand.
  final String? orgId;

  bool belongsTo(String org) => orgId == null || orgId == org;
}
