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
  });
}
