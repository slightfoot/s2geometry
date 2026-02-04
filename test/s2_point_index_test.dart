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

void main() {
  group('S2PointIndex', () {
    late S2PointIndex<int> index;
    late Map<PointIndexEntry<int>, int> contents;
    late math.Random random;

    setUp(() {
      index = S2PointIndex<int>();
      contents = {};
      random = math.Random(1);
    });

    S2Point getRandomPoint() {
      final u = random.nextDouble() * 2 - 1;
      final theta = random.nextDouble() * 2 * math.pi;
      final r = math.sqrt(1 - u * u);
      return S2Point(r * math.cos(theta), r * math.sin(theta), u);
    }

    void add(S2Point point, int data) {
      final entry = S2PointIndex.createEntry<int>(point, data);
      index.addEntry(entry);
      contents[entry] = (contents[entry] ?? 0) + 1;
    }

    void verify() {
      final entries = <PointIndexEntry<int>, int>{};
      for (final it = index.iterator; !it.done; it.next()) {
        final entry = it.entry!;
        entries[entry] = (entries[entry] ?? 0) + 1;
      }
      expect(entries, equals(contents));
    }

    test('testEntryOrdering', () {
      final point = S2Point(1, 0, 0);
      final xposEntry1 = S2PointIndex.createEntry<int>(point, 1);
      final xposEntry2 = S2PointIndex.createEntry<int>(point, 2);
      final xposEntry2b = S2PointIndex.createEntry<int>(point, 2);
      final xposEntryNull = S2PointIndex.createEntry<int>(point, null);
      final xposEntryNullb = S2PointIndex.createEntry<int>(point, null);

      // Ordering by different data values is stable with stableOrder().
      expect(PointIndexEntry.stableOrder<int>().call(xposEntry1, xposEntry2), equals(-1));
      expect(PointIndexEntry.stableOrder<int>().call(xposEntry2, xposEntry1), equals(1));
      // Ordering by different data values is not stable with order().
      expect(PointIndexEntry.order<int>().call(xposEntry1, xposEntry2), equals(-1));
      expect(PointIndexEntry.order<int>().call(xposEntry2, xposEntry1), equals(-1));

      // Null is always first for both order() and stableOrder().
      expect(PointIndexEntry.stableOrder<int>().call(xposEntryNull, xposEntry1), equals(-1));
      expect(PointIndexEntry.stableOrder<int>().call(xposEntry1, xposEntryNull), equals(1));
      expect(PointIndexEntry.order<int>().call(xposEntryNull, xposEntry1), equals(-1));
      expect(PointIndexEntry.order<int>().call(xposEntry1, xposEntryNull), equals(1));

      // Identical instances for both order() and stableOrder().
      expect(PointIndexEntry.stableOrder<int>().call(xposEntry2, xposEntry2), equals(0));
      expect(PointIndexEntry.stableOrder<int>().call(xposEntryNull, xposEntryNull), equals(0));
      expect(PointIndexEntry.order<int>().call(xposEntry2, xposEntry2), equals(0));
      expect(PointIndexEntry.order<int>().call(xposEntryNull, xposEntryNull), equals(0));

      // Equal instances for both order() and stableOrder().
      expect(PointIndexEntry.stableOrder<int>().call(xposEntry2, xposEntry2b), equals(0));
      expect(PointIndexEntry.stableOrder<int>().call(xposEntryNull, xposEntryNullb), equals(0));
      expect(PointIndexEntry.order<int>().call(xposEntry2, xposEntry2b), equals(0));
      expect(PointIndexEntry.order<int>().call(xposEntryNull, xposEntryNullb), equals(0));
    });

    test('testPositioningIteratorEmpty', () {
      final it = index.iterator;
      expect(it.atBegin, isTrue);
      expect(it.done, isTrue);

      expect(it.next(), isFalse);
      expect(it.prev(), isFalse);
    });

    test('testPositioningIteratorSingleElement', () {
      add(getRandomPoint(), 0);
      verify();

      final it = index.iterator;
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
      final e0 = it.entry;
      expect(e0, isNotNull);

      // prev() when atBegin() should return false, stay at element 0.
      expect(it.prev(), isFalse);
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
      expect(it.entry, same(e0));

      // next() from element 0 returns false, but makes done() true and entry() null.
      expect(it.next(), isFalse);
      expect(it.atBegin, isFalse);
      expect(it.done, isTrue);
      expect(it.entry, isNull);

      // prev() from done() should move back to the single element.
      expect(it.prev(), isTrue);
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
      expect(it.entry, same(e0));

      // prev() when atBegin() should return false, stay at element 0.
      expect(it.prev(), isFalse);
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
      expect(it.entry, same(e0));
    });

    test('testPositioningIteratorThreeElements', () {
      add(getRandomPoint(), 2);
      add(getRandomPoint(), 0);
      add(getRandomPoint(), 1);
      verify();

      final it = index.iterator;
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
      final e0 = it.entry;
      expect(e0, isNotNull);

      // prev() when atBegin() should return false, stay at element 0.
      expect(it.prev(), isFalse);
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
      expect(it.entry, same(e0));

      // next() from element 0 moves to element 1.
      expect(it.next(), isTrue);
      expect(it.atBegin, isFalse);
      expect(it.done, isFalse);
      final e1 = it.entry;
      expect(it.entry, same(e1));

      // prev() from element 1 should move back to element 0.
      expect(it.prev(), isTrue);
      expect(it.atBegin, isTrue);
      expect(it.done, isFalse);
      expect(it.entry, same(e0));

      // next() twice takes us to the last element, but we are not done() yet.
      expect(it.next(), isTrue);
      expect(it.entry, same(e1));
      expect(it.next(), isTrue);
      expect(it.atBegin, isFalse);
      expect(it.done, isFalse);
      final e2 = it.entry;
      expect(e2, isNotNull);
      expect(e2, isNot(same(e0)));
      expect(e2, isNot(same(e1)));

      // prev() from element 2 should move back to element 1.
      expect(it.prev(), isTrue);
      expect(it.atBegin, isFalse);
      expect(it.done, isFalse);
      expect(it.entry, same(e1));

      // next to element 2
      expect(it.next(), isTrue);
      expect(it.atBegin, isFalse);
      expect(it.done, isFalse);
      expect(it.entry, same(e2));

      // next() when on the last element returns false, but makes done() true and entry() null.
      expect(it.next(), isFalse);
      expect(it.atBegin, isFalse);
      expect(it.done, isTrue);
      expect(it.entry, isNull);

      // prev() from done() should move back to the last element.
      expect(it.prev(), isTrue);
      expect(it.atBegin, isFalse);
      expect(it.done, isFalse);
      expect(it.entry, same(e2));

      // finish() should move position "past the last" and make entry() return null.
      it.finish();
      expect(it.atBegin, isFalse);
      expect(it.done, isTrue);
      expect(it.entry, isNull);

      // prev() from finish() should move back to the last element.
      it.prev();
      expect(it.atBegin, isFalse);
      expect(it.done, isFalse);
      expect(it.entry, isNotNull);
      expect(it.entry, same(e2));
    });

    void checkIteratorMethods() {
      final it = index.iterator;
      expect(it.atBegin, isTrue);
      if (index.numPoints > 0) {
        expect(it.entry, isNotNull);
        expect(it.done, isFalse);
      } else {
        expect(it.entry, isNull);
        expect(it.done, isTrue);
      }

      // Try to go to the position after the first.
      final moved = it.next();
      if (index.numPoints > 1) {
        expect(moved, isTrue);
        expect(it.atBegin, isFalse);
      } else {
        expect(moved, isFalse);
        expect(it.atBegin, isTrue);
      }
      if (index.numPoints > 0) {
        expect(it.entry, isNotNull);
      } else {
        expect(it.entry, isNull);
      }

      // Go to the end of the index.
      it.finish();
      expect(it.done, isTrue);
      expect(it.entry, isNull);

      // Try to go to the position previous to the end.
      final moved2 = it.prev();
      if (index.numPoints < 2) {
        expect(moved2, isFalse);
      } else {
        expect(moved2, isTrue);
      }
      if (index.numPoints > 0) {
        final entry = it.entry;
        expect(entry, isNotNull);
      } else {
        expect(it.entry, isNull);
      }

      // Iterate through all the cells in the index.
      S2CellId prev = S2CellId.none;
      S2CellId minCell = S2CellId.begin(S2CellId.maxLevel);
      for (it.restart(); !it.done; it.next()) {
        final id = it.cellId;
        expect(id, equals(S2CellId.fromPoint(it.entry!.point!)));

        final it2 = index.iterator;
        if (id == prev) {
          it2.seek(id);
        }

        // Generate a cellunion that covers the range of empty leaf cells between
        // the last cell and this one. Then make sure that seeking to any of those
        // cells takes us to the immediately following cell.
        final skipped = S2CellUnion();
        skipped.initFromBeginEnd(minCell, id.rangeMin);
        for (int i = 0; i < skipped.size; ++i) {
          it2.seek(skipped.cellId(i));
          expect(it2.cellId, equals(id));
        }
        // Test prev(), next(), seek(), and seekForward().
        if (prev.isValid) {
          expect(it.atBegin, isFalse);
          final it2copy = it.copy();
          it2copy.prev();
          expect(it2copy.cellId, equals(prev));
          it2copy.next();
          expect(it2copy.cellId, equals(id));
          it2copy.seek(prev);
          expect(it2copy.cellId, equals(prev));
          it2copy.seekForward(id);
          expect(it2copy.cellId, equals(id));
          it2copy.seekForward(prev);
          expect(it2copy.cellId, equals(id));
        }
        prev = id;
        minCell = id.rangeMax.next;
      }
    }

    test('testNoPoints', () {
      checkIteratorMethods();
    });

    test('testEntryComparatorAndTreeSetContains', () {
      final e1 = S2PointIndex.createEntry<String>(getRandomPoint(), '1');
      final e2 = S2PointIndex.createEntry<String>(getRandomPoint(), '2');
      final e3 = S2PointIndex.createEntry<String>(getRandomPoint(), '3');

      final order = PointIndexEntry.order<String>();
      expect(order(e1, e1), equals(0));
      expect(order(e2, e2), equals(0));
      expect(order(e1, e2), isNot(equals(0)));
      expect(order(e2, e1), isNot(equals(0)));

      final stringIndex = S2PointIndex<String>();
      stringIndex.addEntry(e1);
      stringIndex.addEntry(e2);

      // Verify entries can be found
      var found1 = false;
      var found2 = false;
      var found3 = false;
      for (final it = stringIndex.iterator; !it.done; it.next()) {
        if (it.entry == e1) found1 = true;
        if (it.entry == e2) found2 = true;
        if (it.entry == e3) found3 = true;
      }
      expect(found1, isTrue);
      expect(found2, isTrue);
      expect(found3, isFalse);
    });

    test('testRandomPoints', () {
      for (int i = 0; i < 3; ++i) {
        add(getRandomPoint(), random.nextInt(100));
      }
      verify();

      for (int i = 0; i < 1000; ++i) {
        add(getRandomPoint(), random.nextInt(100));
      }
      verify();
      checkIteratorMethods();
    });

    test('testEntryEquality', () {
      final point = getRandomPoint();
      const data = 10;
      var entry = S2PointIndex.createEntry<int>(point, data);
      var entry2 = S2PointIndex.createEntry<int>(point, data);
      expect(entry, equals(entry2));
      entry2 = S2PointIndex.createEntry<int>(point, 20);
      expect(entry == entry2, isFalse);
      entry2 = S2PointIndex.createEntry<int>(point, null);
      expect(entry == entry2, isFalse);
      expect(entry2 == entry, isFalse);
      entry = S2PointIndex.createEntry<int>(point, null);
      expect(entry, equals(entry2));
    });
  });
}

