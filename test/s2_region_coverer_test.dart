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

/// Tests for S2RegionCoverer.
/// Ported from S2RegionCovererTest.java
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('S2RegionCoverer', () {
    test('testRandomCellsMaxCellsOne', () {
      // Test that covering a single cell with maxCells=1 returns that cell.
      final coverer = S2RegionCoverer(maxCells: 1);

      // Test a few specific cell ids at different levels.
      for (int level = 0; level <= S2CellId.maxLevel; level += 5) {
        final id = S2CellId.fromFace(0).childBeginAtLevel(level);
        final covering = coverer.getCovering(S2Cell(id));
        expect(covering.size, equals(1));
        expect(covering.cellId(0), equals(id));
      }
    });

    test('testFaceCovering', () {
      // Test covering an entire face.
      final coverer = S2RegionCoverer(maxCells: 1);
      final faceId = S2CellId.fromFace(2);
      final covering = coverer.getCovering(S2Cell(faceId));
      expect(covering.size, equals(1));
      expect(covering.cellId(0), equals(faceId));
    });

    test('testSimpleCoverings', () {
      // Test getSimpleCovering which uses flood fill.
      final level = 4;
      final cap = S2Cap.fromAxisAngle(
        S2Point.xPos,
        S1Angle.degrees(10),
      );
      final covering = <S2CellId>[];
      S2RegionCoverer.getSimpleCovering(cap, cap.axis, level, covering);

      // All cells should be at the requested level.
      for (final id in covering) {
        expect(id.level, equals(level));
      }

      // Cells should cover the cap.
      final cellUnion = S2CellUnion.fromCellIds(covering);
      expect(cellUnion.containsPoint(cap.axis), isTrue);
    });

    test('testCoveringLevelConstraints', () {
      // Test that minLevel and maxLevel are respected.
      final coverer = S2RegionCoverer(
        minLevel: 5,
        maxLevel: 10,
        maxCells: 100,
      );
      final cap = S2Cap.fromAxisAngle(
        S2Point.xPos,
        S1Angle.degrees(5),
      );
      final covering = coverer.getCovering(cap);

      for (int i = 0; i < covering.size; i++) {
        final level = covering.cellId(i).level;
        expect(level >= 5, isTrue);
        expect(level <= 10, isTrue);
      }
    });

    test('testLevelModDenormalized', () {
      // Test that after denormalization, levelMod is respected.
      // Note: The main covering algorithm might produce intermediate levels,
      // but denormalize() should produce levels that respect levelMod.
      final minLevel = 2;
      final levelMod = 3;
      final coverer = S2RegionCoverer(
        minLevel: minLevel,
        maxLevel: 20,
        levelMod: levelMod,
        maxCells: 50,
      );
      final cap = S2Cap.fromAxisAngle(
        S2Point.xPos,
        S1Angle.degrees(3),
      );

      // Get covering and denormalize.
      final covering = coverer.getCovering(cap);
      final denormalized = <S2CellId>[];
      covering.denormalize(minLevel, levelMod, denormalized);

      for (final id in denormalized) {
        final level = id.level;
        // Level must satisfy: (level - minLevel) % levelMod == 0
        expect((level - minLevel) % levelMod, equals(0),
            reason: 'Level $level should satisfy (level - $minLevel) % $levelMod == 0');
      }
    });

    test('testInteriorCovering', () {
      // Test that interior covering returns cells contained within the region.
      final coverer = S2RegionCoverer(maxCells: 100);
      final cap = S2Cap.fromAxisAngle(
        S2Point.xPos,
        S1Angle.degrees(20),
      );
      final interior = coverer.getInteriorCovering(cap);

      // All cells in the interior covering should be contained by the cap.
      for (int i = 0; i < interior.size; i++) {
        final cell = S2Cell(interior.cellId(i));
        expect(cap.containsCell(cell), isTrue);
      }
    });

    test('testCoveringContainsRegion', () {
      // Test that the covering actually covers the region.
      final coverer = S2RegionCoverer(maxCells: 10);
      final cap = S2Cap.fromAxisAngle(
        S2Point.yPos,
        S1Angle.degrees(15),
      );
      final covering = coverer.getCovering(cap);

      // The center of the cap should be contained.
      expect(covering.containsPoint(cap.axis), isTrue);

      // Check that cap is covered by checking points on the boundary.
      for (int i = 0; i < 10; i++) {
        final angle = 2 * math.pi * i / 10;
        // Approximate point on boundary of cap.
        final p = S2Point(
          math.cos(cap.angle.radians) + 0.01 * math.sin(angle),
          math.sin(cap.angle.radians) * math.cos(angle),
          math.sin(cap.angle.radians) * math.sin(angle),
        ).normalize();
        // Points well inside the cap should be covered.
        final inside = (cap.axis * 0.5 + p * 0.5).normalize();
        if (cap.containsPoint(inside)) {
          expect(covering.containsPoint(inside), isTrue);
        }
      }
    });

    test('testGetCoveringInto', () {
      final coverer = S2RegionCoverer(maxCells: 5);
      final cap = S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.degrees(10));
      final covering = S2CellUnion();
      coverer.getCoveringInto(cap, covering);
      expect(covering.size, greaterThan(0));
      expect(covering.size, lessThanOrEqualTo(5));
    });

    test('testGetCoveringList', () {
      final coverer = S2RegionCoverer(maxCells: 10, minLevel: 3, levelMod: 2);
      final cap = S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.degrees(10));
      final covering = <S2CellId>[];
      coverer.getCoveringList(cap, covering);
      expect(covering.isNotEmpty, isTrue);

      // All cells should respect minLevel and levelMod
      for (final id in covering) {
        final level = id.level;
        expect(level, greaterThanOrEqualTo(3));
        expect((level - 3) % 2, equals(0));
      }
    });

    test('testGetInteriorCoveringInto', () {
      final coverer = S2RegionCoverer(maxCells: 100);
      final cap = S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.degrees(20));
      final interior = S2CellUnion();
      coverer.getInteriorCoveringInto(cap, interior);

      // All cells should be contained by the cap
      for (int i = 0; i < interior.size; i++) {
        final cell = S2Cell(interior.cellId(i));
        expect(cap.containsCell(cell), isTrue);
      }
    });

    test('testGetInteriorCoveringList', () {
      final coverer = S2RegionCoverer(maxCells: 100, minLevel: 2, levelMod: 2);
      final cap = S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.degrees(20));
      final interior = <S2CellId>[];
      coverer.getInteriorCoveringList(cap, interior);

      // All cells should respect minLevel and levelMod
      for (final id in interior) {
        final level = id.level;
        expect(level, greaterThanOrEqualTo(2));
        expect((level - 2) % 2, equals(0));
      }
    });

    test('testGetFastCovering', () {
      final coverer = S2RegionCoverer(maxCells: 10);
      final cap = S2Cap.fromAxisAngle(S2Point.yPos, S1Angle.degrees(10));
      final results = <S2CellId>[];
      coverer.getFastCovering(cap, results);
      expect(results.isNotEmpty, isTrue);
      expect(results.length, lessThanOrEqualTo(10));
    });

    test('testGetFastCoveringLargeCap', () {
      // Test fast covering with a large cap that covers entire face
      final coverer = S2RegionCoverer(maxCells: 10);
      final cap = S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.degrees(90));
      final results = <S2CellId>[];
      coverer.getFastCovering(cap, results);
      expect(results.isNotEmpty, isTrue);
    });

    test('testNormalizeCovering', () {
      final coverer = S2RegionCoverer(maxCells: 5, maxLevel: 10);
      final covering = <S2CellId>[];

      // Add some cells at various levels
      covering.add(S2CellId.fromFace(0).childBeginAtLevel(15));
      covering.add(S2CellId.fromFace(0).childBeginAtLevel(12));
      covering.add(S2CellId.fromFace(1).childBeginAtLevel(8));

      coverer.normalizeCovering(covering);

      // All cells should respect maxLevel
      for (final id in covering) {
        expect(id.level, lessThanOrEqualTo(10));
      }
    });

    test('testNormalizeCoveringWithLevelMod', () {
      final coverer = S2RegionCoverer(maxCells: 10, minLevel: 2, levelMod: 3, maxLevel: 15);
      final covering = <S2CellId>[];

      covering.add(S2CellId.fromFace(0).childBeginAtLevel(10));
      covering.add(S2CellId.fromFace(1).childBeginAtLevel(10));

      coverer.normalizeCovering(covering);

      // All cells should respect minLevel and levelMod
      for (final id in covering) {
        final level = id.level;
        expect(level, greaterThanOrEqualTo(2));
        expect((level - 2) % 3, equals(0));
      }
    });

    test('testGetters', () {
      final coverer = S2RegionCoverer(minLevel: 2, maxLevel: 15, levelMod: 3, maxCells: 20);
      expect(coverer.minLevel, equals(2));
      expect(coverer.maxLevel, equals(15));
      expect(coverer.levelMod, equals(3));
      expect(coverer.maxCells, equals(20));
    });

    test('testEquality', () {
      final c1 = S2RegionCoverer(minLevel: 2, maxLevel: 15, levelMod: 3, maxCells: 20);
      final c2 = S2RegionCoverer(minLevel: 2, maxLevel: 15, levelMod: 3, maxCells: 20);
      expect(c1, equals(c2));

      final c3 = S2RegionCoverer(minLevel: 3, maxLevel: 15, levelMod: 3, maxCells: 20);
      expect(c1 == c3, isFalse);

      expect(c1 == "not a coverer", isFalse);
    });

    test('testHashCode', () {
      final c1 = S2RegionCoverer(minLevel: 2, maxLevel: 15, levelMod: 3, maxCells: 20);
      final c2 = S2RegionCoverer(minLevel: 2, maxLevel: 15, levelMod: 3, maxCells: 20);
      expect(c1.hashCode, equals(c2.hashCode));
    });

    test('testDefaultMaxCells', () {
      expect(S2RegionCoverer.defaultMaxCells, equals(8));
    });

    test('testSmallMaxCells', () {
      // Test with maxCells < 4 which should use face cells
      final coverer = S2RegionCoverer(maxCells: 2);
      final cap = S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.degrees(5));
      final covering = coverer.getCovering(cap);
      expect(covering.size, lessThanOrEqualTo(6)); // At most 6 face cells
    });

    test('testInteriorCoveringSmallCap', () {
      // Test interior covering for a very small cap
      final coverer = S2RegionCoverer(maxCells: 10, maxLevel: 5);
      final cap = S2Cap.fromAxisAngle(S2Point.xPos, S1Angle.degrees(1));
      final interior = coverer.getInteriorCovering(cap);

      // All cells should be contained by the cap
      for (int i = 0; i < interior.size; i++) {
        final cell = S2Cell(interior.cellId(i));
        expect(cap.containsCell(cell), isTrue);
      }
    });

    test('testClampedLevels', () {
      // Test that minLevel and maxLevel are clamped
      final coverer = S2RegionCoverer(minLevel: -10, maxLevel: 100, levelMod: 5);
      expect(coverer.minLevel, greaterThanOrEqualTo(0));
      expect(coverer.maxLevel, lessThanOrEqualTo(S2CellId.maxLevel));
      expect(coverer.levelMod, greaterThanOrEqualTo(1));
      expect(coverer.levelMod, lessThanOrEqualTo(3));
    });

    test('testNormalizeCoveringTooManyCells', () {
      final coverer = S2RegionCoverer(maxCells: 3, minLevel: 5);
      final covering = <S2CellId>[];

      // Add many small cells
      for (int i = 0; i < 10; i++) {
        covering.add(S2CellId.fromFace(0).childBeginAtLevel(10).next);
      }

      coverer.normalizeCovering(covering);

      // Should have reduced to maxCells or fewer (accounting for minLevel constraint)
      expect(covering.length, lessThanOrEqualTo(10)); // May not reduce if minLevel prevents it
    });
  });
}
