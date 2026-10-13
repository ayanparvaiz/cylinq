import '../../core/models/cylinder.dart';
import '../../core/models/cylinder_status.dart';
import '../../core/models/movement.dart';

/// What the person scanning is doing right now.
enum ScanMode {
  lookup('Look up', 'Scan to see a cylinder'),
  fill('Fill', 'Empty → full at godown'),
  load('Load', 'Full from godown → my vehicle'),
  give('Give full', 'Full cylinder handed to customer'),
  take('Take empty', 'Empty taken back from customer'),
  returned('Return', 'From my vehicle → godown');

  const ScanMode(this.label, this.hint);

  final String label;
  final String hint;

  MoveType get moveType => switch (this) {
    ScanMode.fill => MoveType.fill,
    ScanMode.load => MoveType.load,
    ScanMode.give => MoveType.deliver,
    ScanMode.take => MoveType.collect,
    ScanMode.returned => MoveType.returned,
    ScanMode.lookup => throw StateError('Look up does not move a cylinder'),
  };

  /// Where the cylinder ends up and whether it then holds gas.
  (CylinderStatus, bool) target(Cylinder c) => switch (this) {
    ScanMode.fill => (CylinderStatus.godown, true),
    ScanMode.load => (CylinderStatus.vehicle, true),
    ScanMode.give => (CylinderStatus.customer, true),
    ScanMode.take => (CylinderStatus.vehicle, false),
    ScanMode.returned => (CylinderStatus.godown, c.filled),
    ScanMode.lookup => (c.status, c.filled),
  };
}

/// Result of checking a scanned cylinder against the current mode.
class MoveCheck {
  const MoveCheck.ok() : allowed = true, warning = null;
  const MoveCheck.warn(this.warning) : allowed = true;
  const MoveCheck.block(this.warning) : allowed = false;

  final bool allowed;

  /// Shown under the cylinder in the scan list. Records drift from reality
  /// (a load nobody scanned, a swap at the door), so most surprises are
  /// warnings the person can accept, not hard stops.
  final String? warning;
}

MoveCheck checkMove(ScanMode mode, Cylinder c) {
  if (c.status == CylinderStatus.retired) return const MoveCheck.block('Retired cylinder. Do not use.');
  final lost = c.status == CylinderStatus.lost ? 'Was marked lost. ' : '';
  final now = c.stateLabel;

  String? problem = switch (mode) {
    ScanMode.lookup => null,
    ScanMode.fill when c.status != CylinderStatus.godown => 'Not at godown ($now).',
    ScanMode.fill when c.filled => 'Already full.',
    ScanMode.load when c.status != CylinderStatus.godown => 'Not at godown ($now).',
    ScanMode.load when !c.filled => 'Recorded as empty.',
    ScanMode.give when c.status == CylinderStatus.customer =>
      'Already with ${c.holderName ?? 'a customer'}.',
    ScanMode.give when !c.filled => 'Recorded as empty.',
    ScanMode.take when c.status != CylinderStatus.customer => 'Not recorded with a customer ($now).',
    ScanMode.returned when c.status != CylinderStatus.vehicle => 'Not in a vehicle ($now).',
    _ => null,
  };
  final message = '$lost${problem ?? ''}'.trim();
  return message.isEmpty ? const MoveCheck.ok() : MoveCheck.warn(message);
}
