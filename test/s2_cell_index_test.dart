// Copyright 2019 Google Inc. All Rights Reserved.
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

/// Test cases ported from S2CellIndexTest.java.
void main() {
  group('S2CellIndex', () {
    late S2CellIndex index;
    late List<_LabelledCell> contents;

    setUp(() {
      index = S2CellIndex();
      contents = [];
    });

    void addCell(String cellStr, int label) {
      final cellId = S2CellId.fromDebugString(cellStr);
      index.add(cellId, label);
      contents.add(_LabelledCell(cellId, label));
    }

    void addCellId(S2CellId cellId, int label) {
      index.add(cellId, label);
      contents.add(_LabelledCell(cellId, label));
    }

    void addUnion(S2CellUnion cellUnion, int label) {
      index.addCellUnion(cellUnion, label);
      for (int i = 0; i < cellUnion.size; i++) {
        contents.add(_LabelledCell(cellUnion.cellId(i), label));
      }
    }

    void verifyCellIterator() {
      // Verifies that CellIterator visits each (cellId, label) pair exactly once.
      final actual = <_LabelledCell>[];
      final it = index.cells;
      while (!it.done) {
        actual.add(_LabelledCell(it.cellId, it.label));
        it.next();
      }
      _expectEqual(contents, actual);
    }

    void verifyRangeIterators() {
      // Test finish().
      final it = index.ranges;
      it.begin();
      it.finish();
      expect(it.done, isTrue);

      // Also for non-empty ranges.
      final nonEmpty = index.nonEmptyRanges;
      nonEmpty.begin();
      nonEmpty.finish();
      expect(nonEmpty.done, isTrue);

      // Iterate through all ranges and verify prev/next/seek.
      S2CellId prevStart = S2CellId.none;
      S2CellId nonEmptyPrevStart = S2CellId.none;
      it.begin();
      nonEmpty.begin();
      while (!it.done) {
        // Check that seeking in the current range takes us to this range.
        final it2 = index.ranges;
        final start = it.startId;
        it2.seek(it.startId);
        expect(it2.startId, equals(start));
        it2.seek(it.limitId.prev);
        expect(it2.startId, equals(start));

        // And also for non-empty ranges.
        final nonEmpty2 = index.nonEmptyRanges;
        final nonEmptyStart = nonEmpty.startId;
        nonEmpty2.seek(it.startId);
        expect(nonEmpty2.startId, equals(nonEmptyStart));
        nonEmpty2.seek(it.limitId.prev);
        expect(nonEmpty2.startId, equals(nonEmptyStart));

        // Test prev() and next().
        if (it2.prev()) {
          expect(it2.startId, equals(prevStart));
          it2.next();
          expect(it2.startId, equals(start));
        } else {
          expect(it2.startId, equals(start));
          expect(prevStart, equals(S2CellId.none));
        }

        // And also for non-empty ranges.
        if (nonEmpty2.prev()) {
          expect(nonEmpty2.startId, equals(nonEmptyPrevStart));
          nonEmpty2.next();
          expect(nonEmpty2.startId, equals(nonEmptyStart));
        } else {
          expect(nonEmpty2.startId, equals(nonEmptyStart));
          expect(nonEmptyPrevStart, equals(S2CellId.none));
        }

        // Keep the non-empty iterator synchronized.
        if (!it.isEmpty) {
          expect(it.startId, equals(nonEmpty.startId));
          expect(it.limitId, equals(nonEmpty.limitId));
          expect(nonEmpty.done, isFalse);
          nonEmptyPrevStart = nonEmptyStart;
          nonEmpty.next();
        }
        prevStart = start;
        it.next();
      }
      // Verify that NonEmptyRangeIterator is also finished.
      expect(nonEmpty.done, isTrue);
    }

    void verifyIndexContents() {
      // Verifies that RangeIterator and ContentsIterator can be used to determine
      // the exact set of (cellId, label) pairs that contain any leaf cell.
      S2CellId minCellId = S2CellId.begin(S2CellId.maxLevel);
      final range = index.ranges;
      range.begin();
      while (!range.done) {
        expect(range.startId, equals(minCellId));
        expect(minCellId.compareTo(range.limitId), lessThan(0));
        expect(range.limitId.isLeaf, isTrue);
        minCellId = range.limitId;

        // Build a list of expected (cellId, label) pairs for this range.
        final expected = <_LabelledCell>[];
        for (final x in contents) {
          final xMin = x.cellId.rangeMin;
          final xMax = x.cellId.rangeMax;
          if (xMin.compareTo(range.startId) <= 0 &&
              xMax.next.compareTo(range.limitId) >= 0) {
            // The cell contains the entire range.
            expected.add(x);
          } else {
            // Verify that the cell does not intersect the range.
            expect(
                xMin.compareTo(range.limitId.prev) <= 0 &&
                    xMax.compareTo(range.startId) >= 0,
                isFalse);
          }
        }
        final actual = <_LabelledCell>[];
        final contentsIter = index.contents;
        contentsIter.startUnion(range);
        while (!contentsIter.done) {
          actual.add(_LabelledCell(contentsIter.cellId, contentsIter.label));
          contentsIter.next();
        }
        _expectEqual(expected, actual);
        range.next();
      }
      expect(S2CellId.end(S2CellId.maxLevel), equals(minCellId));
    }

    void quadraticValidate() {
      // Verifies that the index computes the correct set of (cellId, label)
      // pairs for every possible leaf cell.
      index.build();
      verifyCellIterator();
      verifyIndexContents();
      verifyRangeIterators();
    }

    void checkIntersection(S2CellUnion target) {
      final expected = <_LabelledCell>[];
      final actual = <_LabelledCell>[];
      final expectedLabels = <int>{};
      final it = index.cells;
      while (!it.done) {
        if (target.intersectsCellId(it.cellId)) {
          expected.add(_LabelledCell(it.cellId, it.label));
          expectedLabels.add(it.label);
        }
        it.next();
      }
      index.visitIntersectingCells(target, (cellId, label) {
        actual.add(_LabelledCell(cellId, label));
        return true;
      });
      _expectEqual(expected, actual);
      final labels = index.getIntersectingLabels(target);
      expect(Set<int>.from(Iterable.generate(labels.size, (i) => labels[i])),
          equals(expectedLabels));
    }

    void expectContents(
        String targetStr, ContentsIterator contentsIter, List<Object> strLabel) {
      // Given an S2CellId "targetStr" in human-readable form, expects that the
      // first leaf cell contained by this target will intersect the exact set
      // of (cellId, label) pairs expected by "strLabel".
      final range = index.ranges;
      range.seek(S2CellId.fromDebugString(targetStr).rangeMin);
      final expected = <_LabelledCell>[];
      final actual = <_LabelledCell>[];
      for (int i = 0; i < strLabel.length; i += 2) {
        expected.add(_LabelledCell(
            S2CellId.fromDebugString(strLabel[i] as String),
            strLabel[i + 1] as int));
      }
      contentsIter.startUnion(range);
      while (!contentsIter.done) {
        actual.add(_LabelledCell(contentsIter.cellId, contentsIter.label));
        contentsIter.next();
      }
      _expectEqual(expected, actual);
    }

    test('testEmpty', () {
      quadraticValidate();
    });

    test('testOneFaceCell', () {
      addCell('0/', 0);
      quadraticValidate();
    });

    test('testOneLeafCell', () {
      addCell('1/012301230123012301230123012301', 12);
      quadraticValidate();
    });

    test('testDuplicateValues', () {
      addCell('0/', 0);
      addCell('0/', 0);
      addCell('0/', 1);
      addCell('0/', 17);
      quadraticValidate();
    });

    test('testDisjointCells', () {
      addCell('0/', 0);
      addCell('3/', 0);
      quadraticValidate();
    });

    test('testNestedCells', () {
      // Tests nested cells, including cases where several cells have the same
      // rangeMin() or rangeMax() and with randomly ordered labels.
      addCell('1/', 3);
      addCell('1/0', 15);
      addCell('1/000', 9);
      addCell('1/00000', 11);
      addCell('1/012', 6);
      addCell('1/01212', 5);
      addCell('1/312', 17);
      addCell('1/31200', 4);
      addCell('1/3120000', 10);
      addCell('1/333', 20);
      addCell('1/333333', 18);
      addCell('5/', 3);
      addCell('5/3', 31);
      addCell('5/3333', 27);
      quadraticValidate();
    });

    test('testRandomCellUnions', () {
      // Construct cell unions from random S2CellIds at random levels.
      final random = math.Random(1);
      for (int i = 0; i < 100; ++i) {
        addUnion(_getRandomCellUnion(random), i);
      }
      quadraticValidate();
    });

    test('testContentsIteratorSuppressesDuplicates', () {
      // Checks that ContentsIterator stops reporting values once it reaches a
      // node of the cell tree that was visited by the previous call to begin().
      addCell('2/1', 1);
      addCell('2/1', 2);
      addCell('2/10', 3);
      addCell('2/100', 4);
      addCell('2/102', 5);
      addCell('2/1023', 6);
      addCell('2/31', 7);
      addCell('2/313', 8);
      addCell('2/3132', 9);
      addCell('3/1', 10);
      addCell('3/12', 11);
      addCell('3/13', 12);
      quadraticValidate();

      final contentsIter = index.contents;
      expectContents('1/123', contentsIter, []);
      expectContents('2/100123', contentsIter,
          ['2/1', 1, '2/1', 2, '2/10', 3, '2/100', 4]);

      // Check that a second call with the same key yields no additional results.
      expectContents('2/100123', contentsIter, []);

      // Check that seeking to a different branch yields only the new values.
      expectContents('2/10232', contentsIter, ['2/102', 5, '2/1023', 6]);

      // Seek to a node with a different root.
      expectContents('2/313', contentsIter, ['2/31', 7, '2/313', 8]);

      // Seek to a descendant of the previous node.
      expectContents('2/3132333', contentsIter, ['2/3132', 9]);

      // Seek to an ancestor of the previous node.
      expectContents('2/213', contentsIter, []);

      // A few more tests of incremental reporting.
      expectContents('3/1232', contentsIter, ['3/1', 10, '3/12', 11]);
      expectContents('3/133210', contentsIter, ['3/13', 12]);
      expectContents('3/133210', contentsIter, []);
      expectContents('5/0', contentsIter, []);

      // Now try moving backwards, which is expected to yield values that were
      // already reported above.
      expectContents('3/13221', contentsIter, ['3/1', 10, '3/13', 12]);
      expectContents('2/31112', contentsIter, ['2/31', 7]);
    });

    test('testIntersectionOptimization', () {
      // Tests various corner cases for the binary search optimization.
      addCell('1/001', 1);
      addCell('1/333', 2);
      addCell('2/00', 3);
      addCell('2/0232', 4);
      index.build();
      checkIntersection(_makeCellUnion(['1/010', '1/3']));
      checkIntersection(_makeCellUnion(['2/010', '2/011', '2/02']));
    });

    test('testIntersectionRandomUnions', () {
      // Construct cell unions from random S2CellIds at random levels.
      final random = math.Random(2);
      for (int i = 0; i < 100; ++i) {
        addUnion(_getRandomCellUnion(random), i);
      }
      index.build();
      // Now repeatedly query a cell union constructed in the same way.
      for (int i = 0; i < 200; ++i) {
        checkIntersection(_getRandomCellUnion(random));
      }
    });

    test('testIntersectionSemiRandomUnions', () {
      // This test also uses random S2CellUnions, but the unions are specially
      // constructed so that interesting cases are more likely to arise.
      final random = math.Random(3);
      for (int iter = 0; iter < 200; iter++) {
        index.clear();
        contents.clear();
        S2CellId id = S2CellId.fromDebugString('1/0123012301230123');
        final unionCells = <S2CellId>[];
        for (int i = 0; i < 100; i++) {
          if (random.nextInt(10) == 0) {
            addCellId(id, i);
          }
          if (random.nextInt(4) == 0) {
            unionCells.add(id);
          }
          if (random.nextBool()) {
            id = id.nextWrap();
          }
          if (random.nextInt(6) == 0 && !id.isFace) {
            id = id.parent;
          }
          if (random.nextInt(6) == 0 && !id.isLeaf) {
            id = id.childBegin;
          }
        }
        final union = S2CellUnion.fromCellIds(unionCells);
        index.build();
        checkIntersection(union);
      }
    });

    test('testLabelsEmptyNormalize', () {
      final labels = Labels();
      labels.normalize();
      expect(labels.size, equals(0));
    });
  });
}

S2CellUnion _getRandomCellUnion(math.Random random) {
  final cells = <S2CellId>[];
  for (int j = 0; j < 10; j++) {
    cells.add(_getRandomCellId(random));
  }
  return S2CellUnion.fromCellIds(cells);
}

S2CellId _getRandomCellId(math.Random random) {
  // Generate random i, j coordinates
  final face = random.nextInt(6);
  final level = random.nextInt(S2CellId.maxLevel + 1);
  final i = random.nextInt(S2CellId.maxSize);
  final j = random.nextInt(S2CellId.maxSize);
  return S2CellId.fromFaceIJ(face, i, j).parentAtLevel(level);
}

S2CellUnion _makeCellUnion(List<String> strs) {
  final cells = <S2CellId>[];
  for (final str in strs) {
    cells.add(S2CellId.fromDebugString(str));
  }
  return S2CellUnion.fromCellIds(cells);
}

void _expectEqual(List<_LabelledCell> expected, List<_LabelledCell> actual) {
  // Verifies that "expected" and "actual" have the same contents.
  expected.sort((a, b) {
    final cmp = a.cellId.compareTo(b.cellId);
    if (cmp != 0) return cmp;
    return a.label.compareTo(b.label);
  });
  actual.sort((a, b) {
    final cmp = a.cellId.compareTo(b.cellId);
    if (cmp != 0) return cmp;
    return a.label.compareTo(b.label);
  });
  expect(actual.length, equals(expected.length));
  for (int i = 0; i < expected.length; i++) {
    expect(actual[i].cellId, equals(expected[i].cellId));
    expect(actual[i].label, equals(expected[i].label));
  }
}

class _LabelledCell {
  final S2CellId cellId;
  final int label;

  _LabelledCell(this.cellId, this.label);

  @override
  String toString() => '${cellId.toToken()}=$label';
}

