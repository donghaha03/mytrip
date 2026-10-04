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
    label: '한국에서 ${destination.name}으로 출발하는 지도',
    child: SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final route = DepartureRoute(
            Size(constraints.maxWidth, 240),
            destination.code,
          );
          Widget label(String name, Offset point, {required bool above}) =>
              Positioned(
                left: (point.dx - 45).clamp(
                  0,
                  math.max(0, constraints.maxWidth - 90),
                ),
                top: (point.dy + (above ? -38 : 14)).clamp(4, 204),
                width: 90,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
          Widget pin(Offset point) => Positioned(
            left: point.dx - 5,
            top: point.dy - 5,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
            ),
          );
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
                          .25,
                          .75,
                          curve: Curves.easeInOutCubic,
                        ).transform(animation.value);
                        final metric = route.path.computeMetrics().single;
                        final tangent = metric.getTangentForOffset(
                          metric.length * progress,
                        )!;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RoutePainter(route.path, progress),
                              ),
                            ),
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
                pin(route.start),
                label('한국', route.start, above: true),
                if (route.hasFlight) ...[
                  pin(route.end),
                  label(destination.name, route.end, above: false),
                ],
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
    canvas.drawPath(_land, Paint()..color = const Color(0xFFD5E3F6));
    canvas.drawPath(
      _land,
      Paint()
        ..color = const Color(0xFFB2C9E9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(_LandPainter oldDelegate) => oldDelegate._land != _land;
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.path, this.progress);
  final Path path;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint..color = AppColors.border);
    final metric = path.computeMetrics().single;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      paint..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.path != path;
}
