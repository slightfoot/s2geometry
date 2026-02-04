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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2RegionIntersection', () {
    test('testEmptyIntersection', () {
      // An intersection of no regions covers the entire sphere
      final intersection = S2RegionIntersection([]);
      
      // Should contain any point
      expect(intersection.containsPoint(const S2Point(1, 0, 0)), isTrue);
      expect(intersection.containsPoint(const S2Point(0, 1, 0)), isTrue);
      expect(intersection.containsPoint(const S2Point(0, 0, 1)), isTrue);
      
      // RectBound should be full
      expect(intersection.rectBound.isFull, isTrue);
    });

    test('testSingleRegion', () {
      final cap = S2Cap.fromAxisAngle(
        const S2Point(1, 0, 0),
        S1Angle.degrees(10),
      );
      final intersection = S2RegionIntersection([cap]);

      // Should contain points inside the cap
      expect(intersection.containsPoint(const S2Point(1, 0, 0)), isTrue);
      
      // Should not contain points outside the cap
      expect(intersection.containsPoint(const S2Point(-1, 0, 0)), isFalse);
      expect(intersection.containsPoint(const S2Point(0, 1, 0)), isFalse);
    });

    test('testTwoOverlappingCaps', () {
      // Two overlapping caps centered on +X and slightly off +X
      final cap1 = S2Cap.fromAxisAngle(
        const S2Point(1, 0, 0),
        S1Angle.degrees(30),
      );
      final cap2 = S2Cap.fromAxisAngle(
        S2LatLng.fromDegrees(10, 0).toPoint(),
        S1Angle.degrees(30),
      );
      final intersection = S2RegionIntersection([cap1, cap2]);

      // Center of first cap should be in intersection
      expect(intersection.containsPoint(const S2Point(1, 0, 0)), isTrue);
      
      // Antipodal point should not be in intersection
      expect(intersection.containsPoint(const S2Point(-1, 0, 0)), isFalse);
    });

    test('testTwoNonOverlappingCaps', () {
      // Two non-overlapping caps on opposite sides of the sphere
      final cap1 = S2Cap.fromAxisAngle(
        const S2Point(1, 0, 0),
        S1Angle.degrees(10),
      );
      final cap2 = S2Cap.fromAxisAngle(
        const S2Point(-1, 0, 0),
        S1Angle.degrees(10),
      );
      final intersection = S2RegionIntersection([cap1, cap2]);

      // Neither center should be in the intersection
      expect(intersection.containsPoint(const S2Point(1, 0, 0)), isFalse);
      expect(intersection.containsPoint(const S2Point(-1, 0, 0)), isFalse);
    });

    test('testContainsCell', () {
      // Two large overlapping caps
      final cap1 = S2Cap.fromAxisAngle(
        const S2Point(1, 0, 0),
        S1Angle.degrees(60),
      );
      final cap2 = S2Cap.fromAxisAngle(
        const S2Point(1, 0, 0),
        S1Angle.degrees(50),
      );
      final intersection = S2RegionIntersection([cap1, cap2]);

      // A small cell near the center should be contained
      final cellId = S2CellId.fromFace(0).childBeginAtLevel(10);
      final cell = S2Cell(cellId);

      // Only contained if both caps contain it
      expect(
        intersection.containsCell(cell),
        equals(cap1.containsCell(cell) && cap2.containsCell(cell)),
      );
    });

    test('testMayIntersect', () {
      // Single cap centered at +X
      final cap = S2Cap.fromAxisAngle(
        const S2Point(1, 0, 0),
        S1Angle.degrees(60),
      );
      final intersection = S2RegionIntersection([cap]);

      // Face 0 cell should mayIntersect the cap
      final cell0 = S2Cell.fromFace(0);
      expect(cap.mayIntersect(cell0), isTrue); // Verify cap behavior
      expect(intersection.mayIntersect(cell0), isTrue);

      // Face 3 cell (opposite of face 0) should not mayIntersect
      final cell3 = S2Cell.fromFace(3);
      expect(intersection.mayIntersect(cell3), isFalse);
    });

    test('testRectBound', () {
      final rect1 = S2LatLngRect.fromPointPair(
        S2LatLng.fromDegrees(-10, -10),
        S2LatLng.fromDegrees(10, 10),
      );
      final rect2 = S2LatLngRect.fromPointPair(
        S2LatLng.fromDegrees(-5, -15),
        S2LatLng.fromDegrees(15, 5),
      );
      final intersection = S2RegionIntersection([rect1, rect2]);

      final rectBound = intersection.rectBound;

      // The rectBound should be the intersection of the two rects
      // Use lat.lo, lat.hi, lng.lo, lng.hi
      expect(S1Angle.radians(rectBound.lat.lo).degrees, closeTo(-5, 0.001));
      expect(S1Angle.radians(rectBound.lat.hi).degrees, closeTo(10, 0.001));
      expect(S1Angle.radians(rectBound.lng.lo).degrees, closeTo(-10, 0.001));
      expect(S1Angle.radians(rectBound.lng.hi).degrees, closeTo(5, 0.001));
    });

    test('testEquality', () {
      final cap1 = S2Cap.fromAxisAngle(const S2Point(1, 0, 0), S1Angle.degrees(10));
      final cap2 = S2Cap.fromAxisAngle(const S2Point(0, 1, 0), S1Angle.degrees(20));
      
      final intersection1 = S2RegionIntersection([cap1, cap2]);
      final intersection2 = S2RegionIntersection([cap1, cap2]);
      final intersection3 = S2RegionIntersection([cap2, cap1]);
      
      expect(intersection1, equals(intersection2));
      expect(intersection1, isNot(equals(intersection3))); // Order matters
      expect(intersection1.hashCode, equals(intersection2.hashCode));
    });
  });
}

