// Copyright 2014 Google Inc.
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

/// Port of S2RegionUnionTest.java from the Google S2 Geometry Library.
library;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2RegionUnion', () {
    test('testEmptyRegions', () {
      final regions = <S2Region>[];
      final regionUnion = S2RegionUnion(regions);
      expect(regionUnion.capBound.isEmpty, isTrue);
      expect(regionUnion.rectBound.isEmpty, isTrue);
    });

    test('testThreeRegions', () {
      final latLng1 = S2LatLng.fromDegrees(35, -40);
      final latLng2 = S2LatLng.fromDegrees(-35, 40);
      final latLng3 = S2LatLng.fromDegrees(10, 10);
      final regions = <S2Region>[
        S2PointRegion(latLng1.toPoint()),
        S2PointRegion(latLng2.toPoint()),
        S2PointRegion(latLng3.toPoint()),
      ];

      final regionUnion = S2RegionUnion(regions);

      // Verify the cap bound contains all three points
      final capBound = regionUnion.capBound;
      expect(capBound.containsPoint(latLng1.toPoint()), isTrue);
      expect(capBound.containsPoint(latLng2.toPoint()), isTrue);
      expect(capBound.containsPoint(latLng3.toPoint()), isTrue);
      expect(capBound.isEmpty, isFalse);

      final expectedRect =
          S2LatLngRect.fromPointPair(S2LatLng.fromDegrees(-35, -40), S2LatLng.fromDegrees(35, 40));
      expect(regionUnion.rectBound, equals(expectedRect));

      final face0 = S2Cell.fromFace(0);
      expect(regionUnion.mayIntersect(face0), isTrue);
      expect(regionUnion.containsCell(face0), isFalse);

      // The region intersects, but does not contain, the cells of the original points.
      expect(regionUnion.mayIntersect(S2Cell.fromPoint(latLng1.toPoint())), isTrue);
      expect(regionUnion.mayIntersect(S2Cell.fromPoint(latLng2.toPoint())), isTrue);
      expect(regionUnion.mayIntersect(S2Cell.fromPoint(latLng3.toPoint())), isTrue);
      expect(regionUnion.containsCell(S2Cell.fromPoint(latLng1.toPoint())), isFalse);
      expect(regionUnion.containsCell(S2Cell.fromPoint(latLng2.toPoint())), isFalse);
      expect(regionUnion.containsCell(S2Cell.fromPoint(latLng3.toPoint())), isFalse);
    });

    test('testSingleRegion', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(10));
      final regions = <S2Region>[cap];
      final regionUnion = S2RegionUnion(regions);

      // The cap bound should match the original cap
      expect(regionUnion.capBound.axis.x, closeTo(cap.axis.x, 1e-10));
      expect(regionUnion.capBound.axis.y, closeTo(cap.axis.y, 1e-10));
      expect(regionUnion.capBound.axis.z, closeTo(cap.axis.z, 1e-10));
    });

    test('testContainsPoint', () {
      final center = S2LatLng.fromDegrees(0, 0).toPoint();
      final cap = S2Cap.fromAxisAngle(center, S1Angle.degrees(10));
      final regionUnion = S2RegionUnion([cap]);

      // Point inside the cap
      expect(regionUnion.containsPoint(center), isTrue);
      
      // Point outside the cap
      final farPoint = S2LatLng.fromDegrees(45, 45).toPoint();
      expect(regionUnion.containsPoint(farPoint), isFalse);
    });

    test('testMultipleCaps', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(5));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(5));
      final cap3 = S2Cap.fromAxisAngle(S2Point(0, 0, 1), S1Angle.degrees(5));
      final regionUnion = S2RegionUnion([cap1, cap2, cap3]);

      // Should contain points in any of the caps
      expect(regionUnion.containsPoint(S2Point(1, 0, 0)), isTrue);
      expect(regionUnion.containsPoint(S2Point(0, 1, 0)), isTrue);
      expect(regionUnion.containsPoint(S2Point(0, 0, 1)), isTrue);

      // Should not contain point that's not in any cap
      expect(regionUnion.containsPoint(S2Point(-1, 0, 0)), isFalse);
    });

    test('testNestedUnion', () {
      // Test a union containing another union
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(5));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(5));
      final innerUnion = S2RegionUnion([cap1, cap2]);

      final cap3 = S2Cap.fromAxisAngle(S2Point(0, 0, 1), S1Angle.degrees(5));
      final outerUnion = S2RegionUnion([innerUnion, cap3]);

      expect(outerUnion.containsPoint(S2Point(1, 0, 0)), isTrue);
      expect(outerUnion.containsPoint(S2Point(0, 1, 0)), isTrue);
      expect(outerUnion.containsPoint(S2Point(0, 0, 1)), isTrue);
    });

    test('testGetCellUnionBound', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(10));
      final regionUnion = S2RegionUnion([cap]);

      final cellIds = <S2CellId>[];
      regionUnion.getCellUnionBound(cellIds);

      expect(cellIds, isNotEmpty);
    });

    test('testEqualityOperator', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(5));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(5));

      final union1 = S2RegionUnion([cap1, cap2]);
      final union2 = S2RegionUnion([cap1, cap2]);

      expect(union1 == union2, isTrue);
    });

    test('testEqualityDifferentRegions', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(5));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(5));
      final cap3 = S2Cap.fromAxisAngle(S2Point(0, 0, 1), S1Angle.degrees(5));

      final union1 = S2RegionUnion([cap1, cap2]);
      final union2 = S2RegionUnion([cap1, cap3]);

      expect(union1 == union2, isFalse);
    });

    test('testEqualityDifferentOrder', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(5));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(5));

      final union1 = S2RegionUnion([cap1, cap2]);
      final union2 = S2RegionUnion([cap2, cap1]);

      // Different order means different unions
      expect(union1 == union2, isFalse);
    });

    test('testEqualityDifferentType', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(5));
      final union = S2RegionUnion([cap]);

      expect(union == cap, isFalse);
    });

    test('testHashCode', () {
      final cap1 = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(5));
      final cap2 = S2Cap.fromAxisAngle(S2Point(0, 1, 0), S1Angle.degrees(5));

      final union1 = S2RegionUnion([cap1, cap2]);
      final union2 = S2RegionUnion([cap1, cap2]);

      expect(union1.hashCode, equals(union2.hashCode));
    });

    test('testCapBoundCaching', () {
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(10));
      final regionUnion = S2RegionUnion([cap]);

      // Call twice to test caching
      final capBound1 = regionUnion.capBound;
      final capBound2 = regionUnion.capBound;

      expect(identical(capBound1, capBound2), isTrue);
    });

    test('testRectBoundCaching', () {
      // Use S2PointRegion instead of S2Cap since S2Cap.rectBound is not implemented
      final point = S2LatLng.fromDegrees(10, 20).toPoint();
      final regionUnion = S2RegionUnion([S2PointRegion(point)]);

      // Call twice to test caching
      final rectBound1 = regionUnion.rectBound;
      final rectBound2 = regionUnion.rectBound;

      expect(identical(rectBound1, rectBound2), isTrue);
    });

    test('testMayIntersectFalse', () {
      // Create a small cap at (1, 0, 0)
      final cap = S2Cap.fromAxisAngle(S2Point(1, 0, 0), S1Angle.degrees(1));
      final regionUnion = S2RegionUnion([cap]);

      // Get a cell that's definitely on the opposite side of the sphere
      final oppositeCell = S2Cell.fromPoint(S2Point(-1, 0, 0));

      // The small cap shouldn't intersect the opposite side of the sphere
      expect(regionUnion.mayIntersect(oppositeCell), isFalse);
    });

  });
}

