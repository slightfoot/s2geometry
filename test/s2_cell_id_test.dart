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

/// Tests for S2CellId.
/// Ported from S2CellIdTest.java
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

S2CellId getCellId(double latDegrees, double lngDegrees) {
  return S2CellId.fromLatLng(S2LatLng.fromDegrees(latDegrees, lngDegrees));
}

void main() {
  group('S2CellId', () {
    test('testDefaultConstructor', () {
      final id = S2CellId(0);
      expect(id.id, equals(0));
      expect(id.isValid, isFalse);
    });

    test('testFaceDefinitions', () {
      expect(getCellId(0, 0).face, equals(0));
      expect(getCellId(0, 90).face, equals(1));
      expect(getCellId(90, 0).face, equals(2));
      expect(getCellId(0, 180).face, equals(3));
      expect(getCellId(0, -90).face, equals(4));
      expect(getCellId(-90, 0).face, equals(5));
    });

    test('testFromFace', () {
      for (int face = 0; face < 6; ++face) {
        expect(
            S2CellId.fromFace(face),
            equals(S2CellId.fromFacePosLevel(face, 0, 0)));
      }
    });

    test('testParentChildRelationships', () {
      final id = S2CellId.fromFacePosLevel(3, 0x12345678, S2CellId.maxLevel - 4);
      expect(id.isValid, isTrue);
      expect(id.face, equals(3));
      expect(id.pos, equals(0x12345700));
      expect(id.level, equals(S2CellId.maxLevel - 4));
      expect(id.isLeaf, isFalse);

      expect(id.parentAtLevel(id.level), equals(id));
      expect(id.childBeginAtLevel(id.level + 2).pos, equals(0x12345610));
      expect(id.childBegin.pos, equals(0x12345640));
      expect(id.parent.pos, equals(0x12345400));
      expect(id.parentAtLevel(id.level - 2).pos, equals(0x12345000));

      // Check ordering of children relative to parents.
      expect(id.childBegin.lessThan(id), isTrue);
      expect(id.childEnd.greaterThan(id), isTrue);
      expect(id.childEnd, equals(id.childBegin.next.next.next.next));
      expect(id.rangeMin, equals(id.childBeginAtLevel(S2CellId.maxLevel)));
      expect(id.rangeMax.next, equals(id.childEndAtLevel(S2CellId.maxLevel)));

      // Check that cells are represented by the position of their center
      // along the Hilbert curve.
      expect(2 * id.id, equals(id.rangeMin.id + id.rangeMax.id));
    });

    test('testTokens', () {
      // Test a few specific tokens.
      final id1 = S2CellId.fromFace(0);
      expect(id1.toToken(), isNotEmpty);
      expect(id1.toToken().length, lessThanOrEqualTo(16));
      expect(S2CellId.fromToken(id1.toToken()), equals(id1));

      final id2 = S2CellId.fromFacePosLevel(3, 0x12345678, 20);
      expect(S2CellId.fromToken(id2.toToken()), equals(id2));

      // Check that invalid cell ids can be encoded.
      final token = S2CellId.none.toToken();
      expect(S2CellId.fromToken(token), equals(S2CellId.none));
    });

    test('testGetCommonAncestorLevel', () {
      // Two identical cell ids.
      final face0 = S2CellId.fromFace(0);
      final leaf0 = face0.childBeginAtLevel(30);
      expect(face0.getCommonAncestorLevel(face0), equals(0));
      expect(leaf0.getCommonAncestorLevel(leaf0), equals(30));

      // One cell id is a descendant of the other.
      final face5 = S2CellId.fromFace(5);
      expect(leaf0.getCommonAncestorLevel(face0), equals(0));
      expect(face5.getCommonAncestorLevel(face5.childEndAtLevel(30).prev), equals(0));

      // Two cells that have no common ancestor.
      expect(face0.getCommonAncestorLevel(face5), equals(-1));
      expect(
          S2CellId.fromFace(2)
              .childBeginAtLevel(30)
              .getCommonAncestorLevel(S2CellId.fromFace(3).childEndAtLevel(20)),
          equals(-1));

      // Two cells that have a common ancestor distinct from both of them.
      final face5child9 = face5.childBeginAtLevel(9);
      final face0child2 = face0.childBeginAtLevel(2);
      expect(
          face5child9.next.childBeginAtLevel(15).getCommonAncestorLevel(
              face5child9.childBeginAtLevel(20)),
          equals(8));
      expect(
          face0child2.childBeginAtLevel(30).getCommonAncestorLevel(
              face0child2.next.childBeginAtLevel(5)),
          equals(1));
    });

    test('testContainment', () {
      final face0 = S2CellId.fromFace(0);
      final child0 = face0.child(0);
      final child1 = face0.child(1);
      final grandChild00 = child0.child(0);

      // Parent contains children
      expect(face0.contains(child0), isTrue);
      expect(face0.contains(child1), isTrue);
      expect(face0.contains(grandChild00), isTrue);

      // Children do not contain parent
      expect(child0.contains(face0), isFalse);
      expect(grandChild00.contains(face0), isFalse);

      // Siblings do not contain each other
      expect(child0.contains(child1), isFalse);
      expect(child1.contains(child0), isFalse);

      // Intersects tests
      expect(face0.intersects(child0), isTrue);
      expect(child0.intersects(face0), isTrue);
      expect(child0.intersects(child1), isFalse);
    });
  });
}

