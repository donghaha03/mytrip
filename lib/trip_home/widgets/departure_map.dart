import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/country.dart';
import '../theme/app_colors.dart';
import 'departure_map_data.dart';

/// Illustrative country-to-country route, not an airport or live flight map.
class DepartureRoute {
  DepartureRoute(this.size, String countryCode) {
    final origin = departureCoordinates['KR']!;
    final destination = departureCoordinates[countryCode] ?? origin;
    final longitudeDelta = (destination.$1 - origin.$1 + 180) % 360 - 180;
    _center = (
      origin.$1 + longitudeDelta / 2,
      (origin.$2 + destination.$2) / 2,
    );
    _scale = math.min(
      (size.width - 48) / math.max(38, longitudeDelta.abs() + 24),
      (size.height - 72) /
          math.max(28, (destination.$2 - origin.$2).abs() + 20),
    );
    start = project(origin.$1, origin.$2);
    end = project(origin.$1 + longitudeDelta, destination.$2);
    hasFlight =
        departureCoordinates.containsKey(countryCode) &&
        (end - start).distance > 1;
    path = Path()..moveTo(start.dx, start.dy);
    if (hasFlight) {
      path.quadraticBezierTo(
        (start.dx + end.dx) / 2,
        math.min(start.dy, end.dy) - math.min(48, (end - start).distance * .3),
        end.dx,
        end.dy,
      );
    }
  }

  final Size size;
  late final (double, double) _center;
  late final double _scale;
  late final Offset start, end;
  late final bool hasFlight;
  late final Path path;

  Offset project(double longitude, double latitude) => Offset(
    size.width / 2 + (longitude - _center.$1) * _scale,
    size.height / 2 - (latitude - _center.$2) * _scale,
  );
}

class DepartureMap extends StatelessWidget {
  const DepartureMap({
    super.key,
    required this.destination,
    required this.animation,
  });
  final Country destination;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '여행지로 이동하는 지도',
    child: ColoredBox(
      color: const Color(0xFFF0F6FB),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final route = DepartureRoute(constraints.biggest, destination.code);
          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _LandPainter(route)),
                  ),
                ),
                if (route.hasFlight)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final progress = const Interval(
                          .15,
                          .85,
                          curve: Curves.easeInOutCubic,
                        ).transform(animation.value);
                        final metric = route.path.computeMetrics().single;
                        final tangent = metric.getTangentForOffset(
                          metric.length * progress,
                        )!;
                        return Stack(
                          children: [
                            Positioned(
                              left: tangent.position.dx - 16,
                              top: tangent.position.dy - 16,
                              child: Transform.rotate(
                                angle: tangent.angle + math.pi / 2,
                                child: const Icon(
                                  Icons.flight_rounded,
                                  size: 32,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _LandPainter extends CustomPainter {
  _LandPainter(DepartureRoute route) {
    for (final ring in departureLand) {
      for (final shift in [-360.0, 0.0, 360.0]) {
        _land.addPolygon([
          for (var i = 0; i < ring.length; i += 2)
            route.project(ring[i] + shift, ring[i + 1]),
        ], true);
      }
    }
  }
  final _land = Path();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_land, Paint()..color = const Color(0xFFD6E8E4));
    canvas.drawPath(
      _land,
      Paint()
        ..color = const Color(0xFFB3CCC8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(_LandPainter oldDelegate) => oldDelegate._land != _land;
}
