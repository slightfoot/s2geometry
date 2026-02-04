// Copyright 2015 Google Inc. All Rights Reserved.
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

import 'dart:math' as math;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

/// The approximate radius of S2Cap from which query points are chosen.
final S1Angle queryRadius = S2Earth.metersToAngle(10000); // 10 km

/// An approximate bound on the distance measurement error for "reasonable"
/// distances (say, less than Pi/2) due to using S1ChordAngle.
const double maxChordAngleError = 1e-15;

void main() {
  group('S2ClosestPointQuery', () {
    test('testNoPoints', () {
      final index = S2PointIndex<int>();
      final query = S2ClosestPointQuery<int>(index);
      expect(query.findClosestPoint(S2Point.xPos), isNull);
      expect(query.findClosestPoints(S2Point.xPos), isEmpty);
    });

    test('testManyDuplicatePoints', () {
      const numPoints = 10000;
      final index = S2PointIndex<int>();
      for (int i = 0; i < numPoints; i++) {
        index.add(S2Point.xPos, i);
      }
      final query = S2ClosestPointQuery<int>(index);
      final results = query.findClosestPoints(S2Point.xPos);
      expect(results.length, equals(numPoints));
    });

    test('testFilteredPoints', () {
      const numPoints = 10000;
      final index = S2PointIndex<int>();
      for (int i = 0; i < numPoints; i++) {
        index.add(S2Point.xPos, i);
      }
      final query = S2ClosestPointQuery<int>(index);
      query.setFilter((result) => result.entry.data! % 2 == 0);
      final results = query.findClosestPoints(S2Point.xPos);
      expect(results.length, equals(numPoints ~/ 2));
    });

    test('testCirclePoints', () {
      _checkFactory(_PointFactory.circle, 3, 100, 10);
    });

    test('testGridPoints', () {
      _checkFactory(_PointFactory.grid, 3, 100, 10);
    });
  });
}

enum _PointFactory { circle, grid }

final _random = math.Random(42);

List<S2Point> _createPoints(_PointFactory factory, S2Cap queryCap, int numPoints) {
  switch (factory) {
    case _PointFactory.circle:
      // Points regularly spaced along a circle centered at cap axis
      final radius = 0.5 * queryCap.angle.radians;
      final points = <S2Point>[];
      for (int i = 0; i < numPoints; i++) {
        final angle = 2 * math.pi * i / numPoints;
        // Rotate around the cap axis
        final frame = _getRandomFrameAt(queryCap.axis);
        final p = S2Point(
          math.tan(radius) * math.cos(angle),
          math.tan(radius) * math.sin(angle),
          1.0,
        ).normalize();
        points.add(_fromFrame(frame, p));
      }
      return points;
    case _PointFactory.grid:
      // Points on a square grid that includes the entire query cap
      final sqrtNumPoints = math.sqrt(numPoints).ceil();
      final frame = _getRandomFrameAt(queryCap.axis);
      final radius = queryCap.angle.radians;
      final spacing = 2 * radius / sqrtNumPoints;
      final points = <S2Point>[];
      for (int i = 0; i < sqrtNumPoints; i++) {
        for (int j = 0; j < sqrtNumPoints; j++) {
          final p = S2Point(
            math.tan((i + 0.5) * spacing - radius),
            math.tan((j + 0.5) * spacing - radius),
            1.0,
          ).normalize();
          points.add(_fromFrame(frame, p));
        }
      }
      return points;
  }
}

/// A simple 3x3 matrix for frame transformations
class _Frame {
  final S2Point x, y, z;
  _Frame(this.x, this.y, this.z);
}

_Frame _getRandomFrameAt(S2Point z) {
  final zNorm = z.normalize();
  S2Point x;
  if (zNorm.z.abs() < 0.9) {
    x = zNorm.crossProd(S2Point.zPos).normalize();
  } else {
    x = zNorm.crossProd(S2Point.xPos).normalize();
  }
  final y = zNorm.crossProd(x);
  return _Frame(x, y, zNorm);
}

S2Point _fromFrame(_Frame frame, S2Point p) {
  return S2Point(
    frame.x.x * p.x + frame.y.x * p.y + frame.z.x * p.z,
    frame.x.y * p.x + frame.y.y * p.y + frame.z.y * p.z,
    frame.x.z * p.x + frame.y.z * p.y + frame.z.z * p.z,
  );
}

S2Point _getRandomPoint() {
  final z = 2 * _random.nextDouble() - 1;
  final t = 2 * math.pi * _random.nextDouble();
  final r = math.sqrt(1 - z * z);
  return S2Point(r * math.cos(t), r * math.sin(t), z);
}

S2Point _samplePoint(S2Cap cap) {
  // Very simple sampling - just get random points until one is in the cap
  for (int i = 0; i < 1000; i++) {
    final p = _getRandomPoint();
    if (cap.containsPoint(p)) return p;
  }
  return cap.axis;
}

void _checkFactory(_PointFactory factory, int numIndexes, int numPoints, int numQueries) {
  final index = S2PointIndex<int>();
  final query = S2ClosestPointQuery<int>(index);

  for (int i = 0; i < numIndexes; i++) {
    // Generate a point set and index it
    final queryCap = S2Cap.fromAxisAngle(_getRandomPoint(), queryRadius);
    index.reset();
    _addPoints(index, _createPoints(factory, queryCap, numPoints));
    query.reset();

    for (int j = 0; j < numQueries; j++) {
      query.setMaxPoints(1 + _random.nextInt(99));
      if (_random.nextBool()) {
        query.setMaxDistance(_randomAngle());
      }

      final p = _samplePoint(queryCap);
      _checkFindClosestPoints(_PointTarget(p), query);
    }
  }
}

void _addPoints(S2PointIndex<int> index, List<S2Point> points) {
  for (int i = 0; i < points.length; i++) {
    index.add(points[i], i);
  }
}

S1Angle _randomAngle() {
  return S1Angle.radians(_random.nextDouble() * queryRadius.radians);
}

void _checkFindClosestPoints(_Target target, S2ClosestPointQuery<int> query) {
  query.useBruteForce(true);
  final expected = _getClosestPoints(target, query);
  query.useBruteForce(false);
  final actual = _getClosestPoints(target, query);
  _compareResults(expected, actual, query.maxPoints, query.maxDistance, S1Angle.zero);
}

List<Result<int>> _getClosestPoints(_Target target, S2ClosestPointQuery<int> query) {
  final actual = target.findClosestPoints(query);
  expect(actual.length, lessThanOrEqualTo(query.maxPoints));
  for (final result in actual) {
    // Check that result.distance is approximately equal to the angle between point and target
    final p = result.entry.point!;
    final angle = result.distance;
    expect(
      (target.getDistance(p).radians - angle.toAngle().radians).abs(),
      lessThan(maxChordAngleError),
    );
    // Check that it satisfies the maxDistance criteria
    expect(angle.compareTo(query.maxDistance), lessThanOrEqualTo(0));
  }
  return actual;
}

void _compareResults(
  List<Result<int>> expected,
  List<Result<int>> actual,
  int maxSize,
  S1ChordAngle maxDistance,
  S1Angle maxError,
) {
  final maxPruningError = S1ChordAngle.fromRadians(1e-15);
  _checkResultSet(actual, expected, maxSize, maxDistance, maxError, maxPruningError, 'Missing');
  _checkResultSet(expected, actual, maxSize, maxDistance, maxError, S1ChordAngle.zero, 'Extra');
}

void _checkResultSet(
  List<Result<int>> x,
  List<Result<int>> y,
  int maxSize,
  S1ChordAngle maxDistance,
  S1Angle maxError,
  S1ChordAngle maxPruningError,
  String label,
) {
  // Make sure there are no duplicate values
  final dataSet = x.map((r) => r.entry.data).toSet();
  expect(dataSet.length, equals(x.length), reason: 'Result set contains duplicates');

  // Compute the limit
  double limit = 0;
  if (x.length < maxSize) {
    limit = maxDistance.toAngle().radians - maxPruningError.toAngle().radians;
  } else if (x.isNotEmpty) {
    limit = x.last.distance.toAngle().radians - maxError.radians - maxPruningError.toAngle().radians;
  }

  for (final item in y) {
    if (item.distance.toAngle().radians < limit) {
      final found = x.any((r) => r.entry.data == item.entry.data);
      expect(found, isTrue, reason: '$label ${item.entry.data}');
    }
  }
}

abstract class _Target {
  S1Angle getDistance(S2Point x);
  List<Result<int>> findClosestPoints(S2ClosestPointQuery<int> query);
}

class _PointTarget implements _Target {
  final S2Point point;
  _PointTarget(this.point);

  @override
  S1Angle getDistance(S2Point x) => S1Angle.fromPoints(x, point);

  @override
  List<Result<int>> findClosestPoints(S2ClosestPointQuery<int> query) {
    final x = <Result<int>>[];
    query.findClosestPointsToList(x, point);
    final y = query.findClosestPoints(point);
    expect(x.length, equals(y.length));
    return y;
  }
}

