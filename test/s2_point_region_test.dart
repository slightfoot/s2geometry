// Copyright 2017 Google Inc.
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

/// Tests for S2PointRegion.

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

void main() {
  group('S2PointRegion', () {
    test('testS2Region', () {
      final pointRegion = S2PointRegion.fromCoords(1, 0, 0);

      final expectedCapBound = S2Cap.fromAxisHeight(pointRegion.point, 0);
      expect(pointRegion.capBound, equals(expectedCapBound));

      final ll = S2LatLng.fromPoint(pointRegion.point);
      final expectedRect = S2LatLngRect.fromPoint(ll);
      expect(pointRegion.rectBound, equals(expectedRect));

      // The leaf cell containing a point is still much larger than the point region.
      final cell = S2Cell.fromPoint(pointRegion.point);
      expect(pointRegion.containsCell(cell), isFalse);
      expect(pointRegion.mayIntersect(cell), isTrue);
    });

    test('testContainsPoint', () {
      final point = S2Point(1, 0, 0);
      final pointRegion = S2PointRegion(point);

      // Should contain the exact same point
      expect(pointRegion.containsPoint(point), isTrue);

      // Should not contain a different point
      expect(pointRegion.containsPoint(S2Point(0, 1, 0)), isFalse);
    });

    test('testEquality', () {
      final region1 = S2PointRegion(S2Point(1, 0, 0));
      final region2 = S2PointRegion(S2Point(1, 0, 0));
      final region3 = S2PointRegion(S2Point(0, 1, 0));

      expect(region1, equals(region2));
      expect(region1, isNot(equals(region3)));
    });

    test('testComparable', () {
      final region1 = S2PointRegion(S2Point(0, 0, 1));
      final region2 = S2PointRegion(S2Point(1, 0, 0));

      // region1 should be less than region2 based on lexicographic comparison
      expect(region1.compareTo(region2) < 0, isTrue);
    });

    test('testGetCellUnionBound', () {
      final pointRegion = S2PointRegion(S2Point(1, 0, 0));
      final results = <S2CellId>[];
      pointRegion.getCellUnionBound(results);

      // Should return at least one cell
      expect(results, isNotEmpty);
    });

    test('testHashCode', () {
      final region1 = S2PointRegion(S2Point(1, 0, 0));
      final region2 = S2PointRegion(S2Point(1, 0, 0));

      expect(region1.hashCode, equals(region2.hashCode));
    });

    test('testToString', () {
      final region = S2PointRegion(S2Point(1, 0, 0));
      expect(region.toString(), isNotEmpty);
    });

    test('testToDegreesString', () {
      final region = S2PointRegion(S2Point(1, 0, 0));
      expect(region.toDegreesString(), isNotEmpty);
      // At (1, 0, 0), lat should be ~0 and lng should be ~0
      expect(region.toDegreesString(), contains(':'));
    });
  });
}

