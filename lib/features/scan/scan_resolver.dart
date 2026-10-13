import '../../core/models/cylinder.dart';
import '../../core/utils/qr_payload.dart';
import '../cylinders/data/cylinders_repository.dart';

/// Outcome of turning a scanned string into one of our cylinders.
sealed class Resolved {
  const Resolved();
}

class Found extends Resolved {
  const Found(this.cylinder);
  final Cylinder cylinder;
}

class Rejected extends Resolved {
  const Rejected(this.reason);
  final String reason;
}

Future<Resolved> resolveScan(String raw, {required String orgId, required CylindersRepository repo}) async {
  final code = QrPayload.parse(raw);
  if (code == null) return const Rejected('Not a CylinQ label');
  if (!code.belongsTo(orgId)) return const Rejected('This label belongs to another business');
  final cylinder = await repo.fetch(code.serial);
  if (cylinder == null) return Rejected('${code.serial} is not registered');
  return Found(cylinder);
}
