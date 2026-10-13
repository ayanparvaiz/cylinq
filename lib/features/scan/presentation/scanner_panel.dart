import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/widgets/fields_dialog.dart';

/// Camera viewfinder that reports each QR code once, plus a "type it" fallback
/// for torn labels and for laptops without a camera.
class ScannerPanel extends StatefulWidget {
  const ScannerPanel({super.key, required this.onCode, this.height = 260, this.hint});

  final void Function(String raw) onCode;
  final double height;
  final String? hint;

  @override
  State<ScannerPanel> createState() => _ScannerPanelState();
}

class _ScannerPanelState extends State<ScannerPanel> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  String? _last;
  DateTime _lastAt = DateTime(2000);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      // The camera sees the same label many times a second. Report it once,
      // and again only after it has been out of view for a few seconds, so a
      // label held in front of the lens does not repeat every few seconds.
      final now = DateTime.now();
      final seenRecently = raw == _last && now.difference(_lastAt) < const Duration(seconds: 3);
      _last = raw;
      _lastAt = now;
      if (seenRecently) continue;
      HapticFeedback.mediumImpact();
      widget.onCode(raw);
    }
  }

  Future<void> _typeSerial() async {
    final v = await showFieldsDialog(
      context,
      title: 'Type the serial',
      confirm: 'Add',
      fields: const [FieldSpec('Serial on the label', hint: 'GS-00042')],
    );
    if (v != null) widget.onCode(v.first);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.night,
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _CameraError(onType: _typeSerial),
                // Only drawn over a working camera, never over the error text.
                // Nudged up so it clears the torch and Type buttons on phones.
                overlayBuilder: (context, box) => Align(
                  alignment: const Alignment(0, -0.35),
                  child: Container(
                    width: box.maxHeight * 0.55,
                    height: box.maxHeight * 0.55,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.flame, width: 3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.hint != null)
              Positioned(
                left: 12,
                top: 12,
                child: _Pill(child: Text(widget.hint!, style: const TextStyle(color: Colors.white))),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  _Pill(
                    child: IconButton(
                      tooltip: 'Torch',
                      color: Colors.white,
                      icon: const Icon(Icons.flashlight_on_outlined),
                      onPressed: _controller.toggleTorch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: _typeSerial,
                      icon: const Icon(Icons.keyboard_outlined),
                      label: const Text('Type'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(30)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: child),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.onType});
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Camera not available. Allow camera access, or type the serial.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onType, child: const Text('Type serial')),
          ],
        ),
      ),
    );
  }
}
