import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/geohash.dart';

/// Where cylinders were delivered, on free OpenStreetMap tiles (no API key,
/// no billing). Each ~1 km geohash cell is one circle; more cylinders make it
/// bigger and more opaque, in the single brand hue.
class DeliveryMap extends StatelessWidget {
  const DeliveryMap({super.key, required this.cells, this.height = 380});

  final Map<String, int> cells;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = <(LatLng, int)>[
      for (final e in cells.entries)
        if (Geohash.decode(e.key) case (final lat, final lng)) (LatLng(lat, lng), e.value),
    ];
    if (points.isEmpty) return const SizedBox.shrink();
    final max = points.map((p) => p.$2).reduce(math.max);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: points.first.$1,
            initialZoom: 13,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: [for (final p in points) p.$1],
                    padding: const EdgeInsets.all(48),
                    maxZoom: 15,
                  )
                : null,
            // On a phone a one-finger drag must scroll the page, not pan the
            // map, or the dashboard traps the thumb. Pinch still zooms.
            interactionOptions: InteractionOptions(
              flags: MediaQuery.sizeOf(context).width < 600
                  ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                  : InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cylinq.app',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                // Smallest first so big circles never hide small ones' hit areas.
                for (final (point, n) in [...points]..sort((a, b) => a.$2.compareTo(b.$2)))
                  _marker(point, n, max),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }

  Marker _marker(LatLng point, int n, int max) {
    final t = math.sqrt(n / max); // area, not radius, tracks the count
    final size = 14 + 34 * t;
    return Marker(
      point: point,
      width: size + 12, // hit target larger than the mark
      height: size + 12,
      child: Tooltip(
        message: '$n cylinder${n == 1 ? '' : 's'} delivered around here',
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.flame.withValues(alpha: 0.35 + 0.5 * t),
              // The ring separates overlapping circles. OSM tiles are light in
              // both themes, so it is white rather than the app surface.
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
