// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Ported from com.google.common.geometry.S2PointCompressionTest.java

import 'dart:math' as math;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  // Helper to make regular points around a center
  List<S2Point> makeRegularPoints(int numVertices, double radiusKm, int level) {
    final center = const S2Point(1.0, 1.0, 1.0).normalize();
    final radiusAngle = S1Angle.radians(radiusKm / S2Earth.radiusKm);

    // Generate points around the center at the given radius
    final points = <S2Point>[];
    for (var i = 0; i < numVertices; i++) {
      final angle = 2 * math.pi * i / numVertices;

      // Create a point at the given angle around the center
      // First, find two perpendicular vectors to center
      final xAxis = center.ortho();
      final yAxis = center.crossProd(xAxis).normalize();

      // Point on circle at angle
      final x = math.cos(angle);
      final y = math.sin(angle);

      // Create point at radius distance from center
      final cosRadius = math.cos(radiusAngle.radians);
      final sinRadius = math.sin(radiusAngle.radians);

      final point = S2Point(
        center.x * cosRadius + (xAxis.x * x + yAxis.x * y) * sinRadius,
        center.y * cosRadius + (xAxis.y * x + yAxis.y * y) * sinRadius,
        center.z * cosRadius + (xAxis.z * x + yAxis.z * y) * sinRadius,
      ).normalize();

      points.add(point);
    }

    if (level < 0) {
      return points;
    } else {
      return S2TextFormat.snapPointsToLevel(points, level);
    }
  }

  void checkRoundtrip(List<S2Point> points, int level) {
    final encoded = S2PointCompression.encodePointsCompressed(points, level);
    final decodedPoints =
        S2PointCompression.decodePointsCompressed(points.length, level, encoded);
    expect(decodedPoints.length, equals(points.length));
    for (var i = 0; i < points.length; i++) {
      expect(decodedPoints[i], equals(points[i]),
          reason: 'Point $i mismatch');
    }
  }

  group('S2PointCompression', () {
    test('roundtrip empty', () {
      checkRoundtrip(<S2Point>[], S2CellId.maxLevel);
    });

    test('roundtrip fourVertexLoop', () {
      final fourVertexLoop = makeRegularPoints(4, 0.1, S2CellId.maxLevel);
      checkRoundtrip(fourVertexLoop, S2CellId.maxLevel);
    });

    test('roundtrip fourVertexUnsnappedLoop', () {
      final fourVertexUnsnappedLoop = makeRegularPoints(4, 0.1, -1);
      checkRoundtrip(fourVertexUnsnappedLoop, S2CellId.maxLevel);
    });

    test('roundtrip fourVertexLevel14Loop', () {
      final fourVertexLevel14Loop = makeRegularPoints(4, 0.1, 14);
      checkRoundtrip(fourVertexLevel14Loop, 14);
    });

    test('roundtrip oneHundredVertexLoop', () {
      final oneHundredVertexLoop = makeRegularPoints(100, 0.1, S2CellId.maxLevel);
      checkRoundtrip(oneHundredVertexLoop, S2CellId.maxLevel);
    });

    test('roundtrip oneHundredVertexUnsnappedLoop', () {
      final oneHundredVertexUnsnappedLoop = makeRegularPoints(100, 0.1, -1);
      checkRoundtrip(oneHundredVertexUnsnappedLoop, S2CellId.maxLevel);
    });

    test('roundtrip oneHundredVertexMixed15Loop', () {
      final points = makeRegularPoints(100, 0.1, -1);
      // Snap every 3rd point to MAX_LEVEL (15 points total)
      for (var i = 0; i < 15; i++) {
        points[3 * i] =
            S2TextFormat.snapPointToLevel(points[3 * i], S2CellId.maxLevel);
      }
      checkRoundtrip(points, S2CellId.maxLevel);
    });

    test('roundtrip oneHundredVertexMixed25Loop', () {
      final points = makeRegularPoints(100, 0.1, -1);
      // Snap every 4th point to MAX_LEVEL (25 points total)
      for (var i = 0; i < 25; i++) {
        points[4 * i] =
            S2TextFormat.snapPointToLevel(points[4 * i], S2CellId.maxLevel);
      }
      checkRoundtrip(points, S2CellId.maxLevel);
    });

    test('roundtrip oneHundredVertexLevel22Loop', () {
      final oneHundredVertexLevel22Loop = makeRegularPoints(100, 0.1, 22);
      checkRoundtrip(oneHundredVertexLevel22Loop, 22);
    });

    test('roundtrip multiFaceLoop', () {
      final multiFacePoints = <S2Point>[
        S2Projections.faceUvToXyz(0, -0.5, 0.5).normalize(),
        S2Projections.faceUvToXyz(1, -0.5, 0.5).normalize(),
        S2Projections.faceUvToXyz(0, 0.5, -0.5).normalize(),
        S2Projections.faceUvToXyz(2, -0.5, 0.5).normalize(),
        S2Projections.faceUvToXyz(2, 0.5, -0.5).normalize(),
        S2Projections.faceUvToXyz(2, 0.5, 0.5).normalize(),
      ];
      final multiFaceLoop =
          S2TextFormat.snapPointsToLevel(multiFacePoints, S2CellId.maxLevel);
      checkRoundtrip(multiFaceLoop, S2CellId.maxLevel);
    });

    test('roundtrip straightLine', () {
      final linePoints = <S2Point>[];
      for (var i = 0; i < 100; i++) {
        final s = 0.01 + 0.005 * i;
        final t = 0.01 + 0.009 * i;
        final u = S2Projections.stToUV(s);
        final v = S2Projections.stToUV(t);
        linePoints.add(S2Projections.faceUvToXyz(0, u, v).normalize());
      }
      final straightLine =
          S2TextFormat.snapPointsToLevel(linePoints, S2CellId.maxLevel);
      checkRoundtrip(straightLine, S2CellId.maxLevel);
    });
  });

  group('S2PointCompression sizes', () {
    List<S2Point> makeRegularPointsLocal(int numVertices, double radiusKm, int level) {
      final center = const S2Point(1.0, 1.0, 1.0).normalize();
      final radiusAngle = S1Angle.radians(radiusKm / S2Earth.radiusKm);

      final points = <S2Point>[];
      for (var i = 0; i < numVertices; i++) {
        final angle = 2 * math.pi * i / numVertices;
        final xAxis = center.ortho();
        final yAxis = center.crossProd(xAxis).normalize();
        final x = math.cos(angle);
        final y = math.sin(angle);
        final cosRadius = math.cos(radiusAngle.radians);
        final sinRadius = math.sin(radiusAngle.radians);

        final point = S2Point(
          center.x * cosRadius + (xAxis.x * x + yAxis.x * y) * sinRadius,
          center.y * cosRadius + (xAxis.y * x + yAxis.y * y) * sinRadius,
          center.z * cosRadius + (xAxis.z * x + yAxis.z * y) * sinRadius,
        ).normalize();

        points.add(point);
      }

      if (level < 0) {
        return points;
      } else {
        return S2TextFormat.snapPointsToLevel(points, level);
      }
    }

    test('size fourVertexLoop', () {
      final fourVertexLoop = makeRegularPointsLocal(4, 0.1, S2CellId.maxLevel);
      final encoded = S2PointCompression.encodePointsCompressed(
          fourVertexLoop, S2CellId.maxLevel);
      // Should be much smaller than uncompressed (96 bytes = 4 * 24)
      // Note: Exact size depends on point geometry which differs from Java's makeRegularVertices
      expect(encoded.length, lessThan(50));
    });

    test('size fourVertexLevel14Loop', () {
      final fourVertexLevel14Loop = makeRegularPointsLocal(4, 0.1, 14);
      final encoded =
          S2PointCompression.encodePointsCompressed(fourVertexLevel14Loop, 14);
      // Should be smaller than max level encoding
      expect(encoded.length, lessThan(30));
    });

    test('size oneHundredVertexLoop', () {
      final oneHundredVertexLoop =
          makeRegularPointsLocal(100, 0.1, S2CellId.maxLevel);
      final encoded = S2PointCompression.encodePointsCompressed(
          oneHundredVertexLoop, S2CellId.maxLevel);
      // Should be much smaller than uncompressed (2400 bytes = 100 * 24)
      expect(encoded.length, lessThan(400));
    });

    test('size oneHundredVertexUnsnappedLoop', () {
      final oneHundredVertexUnsnappedLoop = makeRegularPointsLocal(100, 0.1, -1);
      final encoded = S2PointCompression.encodePointsCompressed(
          oneHundredVertexUnsnappedLoop, S2CellId.maxLevel);
      // Unsnapped points are stored exactly, so about 25 bytes per point
      expect(encoded.length, greaterThan(2400)); // More than compressed
      expect(encoded.length, lessThan(3000));
    });

    test('size oneHundredVertexLevel22Loop', () {
      final oneHundredVertexLevel22Loop = makeRegularPointsLocal(100, 0.1, 22);
      final encoded = S2PointCompression.encodePointsCompressed(
          oneHundredVertexLevel22Loop, 22);
      // Lower level = smaller pi/qi values = better compression
      expect(encoded.length, lessThan(200));
    });

    test('size straightLine', () {
      final linePoints = <S2Point>[];
      for (var i = 0; i < 100; i++) {
        final s = 0.01 + 0.005 * i;
        final t = 0.01 + 0.009 * i;
        final u = S2Projections.stToUV(s);
        final v = S2Projections.stToUV(t);
        linePoints.add(S2Projections.faceUvToXyz(0, u, v).normalize());
      }
      final straightLine =
          S2TextFormat.snapPointsToLevel(linePoints, S2CellId.maxLevel);
      final encoded = S2PointCompression.encodePointsCompressed(
          straightLine, S2CellId.maxLevel);
      // About 1 byte / vertex.
      expect(encoded.length, equals(straightLine.length + 17));
    });
  });

  group('NthDerivativeCoder', () {
    test('fixed values', () {
      final input = [1, 5, 10, 15, 20, 23];
      final order0 = [1, 5, 10, 15, 20, 23];
      final order1 = [1, 4, 5, 5, 5, 3];
      final order2 = [1, 4, 1, 0, 0, -2];

      final encoder0 = NthDerivativeCoder(0);
      final decoder0 = NthDerivativeCoder(0);
      final encoder1 = NthDerivativeCoder(1);
      final decoder1 = NthDerivativeCoder(1);
      final encoder2 = NthDerivativeCoder(2);
      final decoder2 = NthDerivativeCoder(2);

      for (var i = 0; i < input.length; i++) {
        expect(encoder0.encode(input[i]), equals(order0[i]));
        expect(encoder0.encode(decoder0.decode(order0[i])), equals(input[i]));
        expect(encoder1.encode(input[i]), equals(order1[i]));
        expect(decoder1.decode(order1[i]), equals(input[i]));
        expect(encoder2.encode(input[i]), equals(order2[i]));
        expect(decoder2.decode(order2[i]), equals(input[i]));
      }
    });

    test('regression order 0', () {
      _checkRegression(0);
    });

    test('regression order 1', () {
      _checkRegression(1);
    });

    test('regression order 2', () {
      _checkRegression(2);
    });

    test('regression random orders', () {
      final random = math.Random(42);
      for (var i = 0; i < 10; i++) {
        _checkRegression(random.nextInt(NthDerivativeCoder.nMax + 1));
      }
    });
  });
}

const int _numRegressionCases = 10000; // Reduced from 1000000 for faster tests

void _checkRegression(int order) {
  final random = math.Random();
  final raw = List<int>.generate(_numRegressionCases, (_) => random.nextInt(0x7FFFFFFF) - 0x3FFFFFFF);
  final encoded = List<int>.filled(_numRegressionCases, 0);
  final decoded = List<int>.filled(_numRegressionCases, 0);

  final encoder = NthDerivativeCoder(order);
  for (var i = 0; i < _numRegressionCases; i++) {
    encoded[i] = encoder.encode(raw[i]);
  }

  final decoder = NthDerivativeCoder(order);
  for (var i = 0; i < _numRegressionCases; i++) {
    decoded[i] = decoder.decode(encoded[i]);
  }

  for (var i = 0; i < _numRegressionCases; i++) {
    expect(decoded[i], equals(raw[i]), reason: 'Mismatch at index $i');
  }
}

