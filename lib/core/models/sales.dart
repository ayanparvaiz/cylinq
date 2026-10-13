import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMode {
  cash('Cash'),
  upi('UPI'),
  credit('Credit');

  const PaymentMode(this.label);
  final String label;

  static PaymentMode parse(Object? v) => PaymentMode.values.firstWhere(
    (p) => p.name == v,
    orElse: () => PaymentMode.cash,
  );
}

/// One delivery visit: full cylinders given, empties taken back, money received.
class Sale {
  const Sale({
    required this.id,
    required this.customerName,
    required this.areaName,
    required this.given,
    required this.taken,
    required this.amount,
    required this.payment,
    required this.byName,
    this.at,
  });

  final String id;
  final String customerName;
  final String areaName;
  final List<String> given;
  final List<String> taken;
  final num amount;
  final PaymentMode payment;
  final String byName;
  final DateTime? at;

  factory Sale.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Sale(
      id: doc.id,
      customerName: d['customerName'] as String? ?? '',
      areaName: d['areaName'] as String? ?? '',
      given: List<String>.from(d['given'] as List? ?? const []),
      taken: List<String>.from(d['taken'] as List? ?? const []),
      amount: d['amount'] as num? ?? 0,
      payment: PaymentMode.parse(d['payment']),
      byName: d['byName'] as String? ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
    );
  }
}

/// Totals for one area inside a [DailyStats] doc.
class AreaTotal {
  const AreaTotal({this.sales = 0, this.qty = 0, this.amount = 0});

  final int sales;
  final int qty;
  final num amount;

  AreaTotal operator +(AreaTotal o) =>
      AreaTotal(sales: sales + o.sales, qty: qty + o.qty, amount: amount + o.amount);
}

/// `orgs/{orgId}/daily/{yyyy-MM-dd}`: running totals the dashboard reads
/// instead of scanning every sale. One doc per day keeps a month to 30 reads.
class DailyStats {
  const DailyStats({
    required this.day,
    this.sales = 0,
    this.qty = 0,
    this.amount = 0,
    this.areas = const {},
    this.cells = const {},
  });

  final String day;
  final int sales;
  final int qty;
  final num amount;

  /// areaId → totals.
  final Map<String, AreaTotal> areas;

  /// geohash (6 chars, roughly 1.2 × 0.6 km) → cylinders delivered there.
  final Map<String, int> cells;

  factory DailyStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final areas = <String, AreaTotal>{};
    (d['areas'] as Map? ?? const {}).forEach((key, value) {
      final m = value as Map? ?? const {};
      areas[key as String] = AreaTotal(
        sales: (m['sales'] as num?)?.toInt() ?? 0,
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        amount: m['amount'] as num? ?? 0,
      );
    });
    final cells = <String, int>{};
    (d['cells'] as Map? ?? const {}).forEach((key, value) {
      cells[key as String] = (value as num?)?.toInt() ?? 0;
    });
    return DailyStats(
      day: doc.id,
      sales: (d['sales'] as num?)?.toInt() ?? 0,
      qty: (d['qty'] as num?)?.toInt() ?? 0,
      amount: d['amount'] as num? ?? 0,
      areas: areas,
      cells: cells,
    );
  }
}
