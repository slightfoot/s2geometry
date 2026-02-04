// Copyright 2005 Google Inc. All Rights Reserved.
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

/// Tests for S2CellUnion.
/// Ported from S2CellUnionTest.java
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('S2CellUnion', () {
    test('testBasic', () {
      final ids = <S2CellId>[];
      final empty = S2CellUnion()..initFromCellIds(ids);
      expect(empty.size, equals(0));

      final face1Id = S2CellId.fromFace(1);
      ids.add(face1Id);
      final face1Union = S2CellUnion()..initFromCellIds(ids);
      expect(face1Union.size, equals(1));
      expect(face1Union.cellId(0), equals(face1Id));

      final face2Id = S2CellId.fromFace(2);
      final cellIds = [face2Id.id];
      final face2Union = S2CellUnion()..initFromIds(cellIds);
      expect(face2Union.size, equals(1));
      expect(face2Union.cellId(0), equals(face2Id));

      final face1Cell = S2Cell(face1Id);
      final face2Cell = S2Cell(face2Id);
      expect(face1Union.containsCell(face1Cell), isTrue);
      expect(face1Union.containsCell(face2Cell), isFalse);
    });

    test('testValid', () {
      final cells = S2CellUnion();
      // Duplicate cells - not valid
      cells.initRawCellIds([
        S2CellId.fromPoint(S2Point.xPos),
        S2CellId.fromPoint(S2Point.xPos),
      ]);
      expect(cells.isValid, isFalse);

      // Different cells - valid
      cells.initRawCellIds([
        S2CellId.fromPoint(S2Point.xPos),
        S2CellId.fromPoint(S2Point.xPos).next,
      ]);
      expect(cells.isValid, isTrue);
    });

    test('testContainsCellUnion', () {
      final union1 = S2CellUnion.fromCellIds([
        S2CellId.fromFace(0).child(0).child(0),
        S2CellId.fromFace(0).child(0).child(1),
      ]);

      final union2 = S2CellUnion.fromCellIds([
        S2CellId.fromFace(0).child(0),
      ]);

      expect(union2.containsUnion(union1), isTrue);
      expect(union1.containsUnion(union2), isFalse);
    });

    test('testEmpty', () {
      final empty = S2CellUnion();
      final face1 = S2CellId.fromFace(1);

      // normalize()
      empty.normalize();
      expect(empty.size, equals(0));

      // denormalize(...)
      final output = <S2CellId>[];
      empty.denormalize(0, 2, output);
      expect(empty.size, equals(0));

      // containsCellId
      expect(empty.containsCellId(face1), isFalse);
      expect(empty.containsUnion(empty), isTrue);

      // intersectsCellId
      expect(empty.intersectsCellId(face1), isFalse);
      expect(empty.intersectsUnion(empty), isFalse);

      // getUnion
      final union = S2CellUnion();
      union.getUnion(empty, empty);
      expect(union.size, equals(0));

      // getIntersection
      final intersection = S2CellUnion();
      intersection.getIntersectionWithCellId(empty, face1);
      expect(intersection.size, equals(0));
      intersection.getIntersection(empty, empty);
      expect(intersection.size, equals(0));

      // getDifference
      final difference = S2CellUnion();
      difference.getDifference(empty, empty);
      expect(difference.size, equals(0));
    });

    test('testLeafCellsCovered', () {
      final cellUnion = S2CellUnion();
      expect(cellUnion.leafCellsCovered, equals(0));

      final ids = <S2CellId>[];
      // One leaf cell on face 0.
      ids.add(S2CellId.fromFace(0).childBeginAtLevel(S2CellId.maxLevel));
      cellUnion.initFromCellIds(ids);
      expect(cellUnion.leafCellsCovered, equals(1));

      // Face 0 itself (which includes the previous leaf cell).
      ids.add(S2CellId.fromFace(0));
      cellUnion.initFromCellIds(ids);
      expect(cellUnion.leafCellsCovered, equals(1 << 60));
    });

    test('testWholeSphere', () {
      final wholeSphere = S2CellUnion.wholeSphere();
      expect(wholeSphere.leafCellsCovered, equals(6 * (1 << 60)));
      wholeSphere.expandAtLevel(0);
      expect(wholeSphere, equals(S2CellUnion.wholeSphere()));
    });

    test('testInitFromMinMax', () {
      final minId = S2CellId.fromFace(0).rangeMin;
      final maxId = S2CellId.fromFace(0).rangeMax;
      final cellUnion = S2CellUnion()..initFromMinMax(minId, maxId);
      expect(cellUnion.size, equals(1));
      expect(cellUnion.cellId(0), equals(S2CellId.fromFace(0)));
    });

    test('testArea', () {
      final cellUnion = S2CellUnion();
      assertExactly(0.0, cellUnion.averageBasedArea);
      assertExactly(0.0, cellUnion.approxArea);
      assertExactly(0.0, cellUnion.exactArea);
    });

    test('testFromCellId', () {
      final cellId = S2CellId.fromFace(0);
      final union = S2CellUnion.fromCellId(cellId);
      expect(union.size, equals(1));
      expect(union.cellId(0), equals(cellId));
    });

    test('testCopyFrom', () {
      final original = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final copy = S2CellUnion.copyFrom(original);
      expect(copy.size, equals(original.size));
      expect(copy.cellId(0), equals(original.cellId(0)));
    });

    test('testClear', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      expect(union.size, equals(1));
      union.clear();
      expect(union.size, equals(0));
    });

    test('testInitSwap', () {
      final ids = [S2CellId.fromFace(0), S2CellId.fromFace(1)];
      final union = S2CellUnion();
      union.initSwap(ids);
      expect(union.size, equals(2));
      expect(ids.isEmpty, isTrue);
    });

    test('testInitRawSwap', () {
      final ids = [S2CellId.fromFace(0), S2CellId.fromFace(1)];
      final union = S2CellUnion();
      union.initRawSwap(ids);
      expect(union.size, equals(2));
      expect(ids.isEmpty, isTrue);
    });

    test('testInitFromCellId', () {
      final union = S2CellUnion();
      final cellId = S2CellId.fromFace(0);
      union.initFromCellId(cellId);
      expect(union.size, equals(1));
      expect(union.cellId(0), equals(cellId));
    });

    test('testIsEmpty', () {
      expect(S2CellUnion().isEmpty, isTrue);
      expect(S2CellUnion.fromCellId(S2CellId.fromFace(0)).isEmpty, isFalse);
    });

    test('testIsNormalized', () {
      // A normalized union
      final normalized = S2CellUnion.fromCellIds([
        S2CellId.fromFace(0),
        S2CellId.fromFace(1),
      ]);
      expect(normalized.isNormalized, isTrue);
    });

    test('testDenormalized', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final denorm = union.denormalized(2);
      expect(denorm.length, greaterThan(1));
    });

    test('testDenormalize', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final output = <S2CellId>[];
      union.denormalize(1, 2, output);
      expect(output.length, greaterThan(1));
    });

    test('testContainsPoint', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      expect(union.containsPoint(S2Point.xPos), isTrue);
      expect(union.containsPoint(S2Point.xNeg), isFalse);
    });

    test('testIntersectsCellId', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      expect(union.intersectsCellId(S2CellId.fromFace(0)), isTrue);
      expect(union.intersectsCellId(S2CellId.fromFace(1)), isFalse);
    });

    test('testIntersectsUnion', () {
      final union1 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final union2 = S2CellUnion.fromCellIds([S2CellId.fromFace(0).child(0)]);
      expect(union1.intersectsUnion(union2), isTrue);

      final union3 = S2CellUnion.fromCellIds([S2CellId.fromFace(1)]);
      expect(union1.intersectsUnion(union3), isFalse);
    });

    test('testMayIntersectCell', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final cell = S2Cell(S2CellId.fromFace(0));
      expect(union.mayIntersect(cell), isTrue);
    });

    test('testUnion', () {
      final u1 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final u2 = S2CellUnion.fromCellIds([S2CellId.fromFace(1)]);
      final result = S2CellUnion.union(u1, u2);
      expect(result.size, equals(2));
    });

    test('testIntersection', () {
      final u1 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final u2 = S2CellUnion.fromCellIds([S2CellId.fromFace(0).child(0)]);
      final result = S2CellUnion.intersection(u1, u2);
      expect(result.size, equals(1));
    });

    test('testGetIntersectionWithCellId', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final result = S2CellUnion();
      result.getIntersectionWithCellId(union, S2CellId.fromFace(0));
      expect(result.size, equals(1));

      // Test with non-contained cell
      result.getIntersectionWithCellId(union, S2CellId.fromFace(1));
      expect(result.size, equals(0));
    });

    test('testGetDifference', () {
      final u1 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final u2 = S2CellUnion.fromCellIds([S2CellId.fromFace(0).child(0)]);
      final result = S2CellUnion();
      result.getDifference(u1, u2);
      expect(result.size, greaterThan(0));
    });

    test('testExpand', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0).child(0).child(0)]);
      union.expand(S1Angle.degrees(1), 2);
      expect(union.size, greaterThan(1));
    });

    test('testCapBound', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final cap = union.capBound;
      expect(cap.isEmpty, isFalse);
    });

    test('testCapBoundEmpty', () {
      final union = S2CellUnion();
      final cap = union.capBound;
      expect(cap.isEmpty, isTrue);
    });

    test('testRectBound', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final rect = union.rectBound;
      expect(rect.isEmpty, isFalse);
    });

    test('testGetCellUnionBound', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final result = <S2CellId>[];
      union.getCellUnionBound(result);
      expect(result.length, equals(1));
    });

    test('testIterator', () {
      final union = S2CellUnion.fromCellIds([
        S2CellId.fromFace(0),
        S2CellId.fromFace(1),
      ]);
      int count = 0;
      final iter = union.iterator;
      while (iter.moveNext()) {
        count++;
      }
      expect(count, equals(2));
    });

    test('testEquality', () {
      final u1 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final u2 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      expect(u1, equals(u2));

      final u3 = S2CellUnion.fromCellIds([S2CellId.fromFace(1)]);
      expect(u1 == u3, isFalse);

      expect(u1 == "not a union", isFalse);
    });

    test('testHashCode', () {
      final u1 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final u2 = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      expect(u1.hashCode, equals(u2.hashCode));
    });

    test('testToString', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      final str = union.toString();
      expect(str, isNotEmpty);
    });

    test('testCellIds', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      expect(union.cellIds.length, equals(1));
    });

    test('testAreaNonEmpty', () {
      final union = S2CellUnion.fromCellIds([S2CellId.fromFace(0)]);
      expect(union.averageBasedArea, greaterThan(0));
      expect(union.approxArea, greaterThan(0));
      expect(union.exactArea, greaterThan(0));
    });

    test('testFromIds', () {
      final face0 = S2CellId.fromFace(0);
      final face1 = S2CellId.fromFace(1);
      final union = S2CellUnion.fromIds([face0.id, face1.id]);
      expect(union.size, equals(2));
      expect(union.containsCellId(face0), isTrue);
      expect(union.containsCellId(face1), isTrue);
    });

    test('testNormalizeSiblings', () {
      // Create 4 sibling cells that should be merged into their parent
      final parent = S2CellId.fromFace(0).child(0);
      final children = <S2CellId>[];
      for (var i = 0; i < 4; i++) {
        children.add(parent.child(i));
      }
      final union = S2CellUnion.fromCellIds(children);
      // All 4 children should be normalized to their parent
      expect(union.size, equals(1));
      expect(union.cellId(0), equals(parent));
    });

    test('testNormalizeMultipleLevels', () {
      // Create cells that normalize across multiple levels
      final face0 = S2CellId.fromFace(0);
      // Add all 4 children of face0.child(0)
      final children = <S2CellId>[];
      final parent = face0.child(0);
      for (var i = 0; i < 4; i++) {
        children.add(parent.child(i));
      }
      final union = S2CellUnion.fromCellIds(children);
      expect(union.size, equals(1));
    });

    test('testDenormalizeWithLevelMod2', () {
      final face = S2CellId.fromFace(0);
      final union = S2CellUnion.fromCellIds([face]);
      final output = <S2CellId>[];
      // Denormalize with minLevel=2 and levelMod=2
      union.denormalize(2, 2, output);
      expect(output.isNotEmpty, isTrue);
      for (var cell in output) {
        expect(cell.level, greaterThanOrEqualTo(2));
      }
    });

    test('testDenormalizeWithLevelMod3', () {
      final cell = S2CellId.fromFace(0).child(0);
      final union = S2CellUnion.fromCellIds([cell]);
      final output = <S2CellId>[];
      // Denormalize with minLevel=3 and levelMod=3
      union.denormalize(3, 3, output);
      expect(output.isNotEmpty, isTrue);
    });

    test('testNormalizeDuplicates', () {
      // Normalizing should remove duplicates
      final cell = S2CellId.fromFace(0);
      final union = S2CellUnion();
      union.initRawCellIds([cell, cell, cell]);
      union.normalize();
      expect(union.size, equals(1));
    });

    test('testNormalizeContained', () {
      // Normalize removes cells contained in other cells
      final parent = S2CellId.fromFace(0);
      final child = parent.child(0);
      final union = S2CellUnion();
      union.initRawCellIds([parent, child]);
      union.normalize();
      expect(union.size, equals(1));
      expect(union.cellId(0), equals(parent));
    });

    test('testExpandLargeRadius', () {
      // Test expand when radius is larger than face cell
      final cell = S2CellId.fromFace(0).childBeginAtLevel(5);
      final union = S2CellUnion.fromCellIds([cell]);
      // Expand with a radius larger than min width of face 0
      union.expand(S1Angle.degrees(90), 5);
      // Should have expanded (may be normalized to a single larger cell or multiple)
      expect(union.size, greaterThanOrEqualTo(1));
    });

    test('testExpandAtLevelWithSkipping', () {
      // Test expandAtLevel that skips contained cells
      final parent = S2CellId.fromFace(0).childBeginAtLevel(2);
      final child = parent.childBeginAtLevel(4);
      final union = S2CellUnion.fromCellIds([parent, child]);
      union.expandAtLevel(2);
      // Should have expanded cells
      expect(union.size, greaterThan(0));
    });

    test('testGetIntersectionWithCellIdBinarySearch', () {
      // Test intersection with a cell ID that triggers binary search
      final x = S2CellUnion.fromCellIds([
        S2CellId.fromFace(0).childBeginAtLevel(3),
        S2CellId.fromFace(0).childBeginAtLevel(3).next,
        S2CellId.fromFace(0).childBeginAtLevel(3).next.next,
        S2CellId.fromFace(1).childBeginAtLevel(3),
        S2CellId.fromFace(2).childBeginAtLevel(3),
      ]);
      final result = S2CellUnion();
      // Get intersection with a face cell
      result.getIntersectionWithCellId(x, S2CellId.fromFace(0));
      // Should contain only the cells from face 0
      for (int i = 0; i < result.size; i++) {
        expect(result.cellId(i).face, equals(0));
      }
    });

    test('testIntersectionAsymmetricRanges', () {
      // Test intersection of unions with asymmetric ranges
      final x = S2CellUnion.fromCellIds([
        S2CellId.fromFace(0).child(0),
        S2CellId.fromFace(2).child(0),
      ]);
      final y = S2CellUnion.fromCellIds([
        S2CellId.fromFace(1).child(0),
        S2CellId.fromFace(2).child(0),
      ]);
      final result = S2CellUnion.intersection(x, y);
      // Only face 2 child should be in intersection
      expect(result.size, equals(1));
      expect(result.cellId(0).face, equals(2));
    });
  });
}
