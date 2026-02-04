// Copyright 2024 Google Inc. All Rights Reserved.
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

/// Test data generator for random points.
class _TestData {
  final math.Random _random;

  _TestData([int seed = 1]) : _random = math.Random(seed);

  int nextInt(int max) => _random.nextInt(max);

  S2Point getRandomPoint() {
    final u = _random.nextDouble() * 2 - 1;
    final theta = _random.nextDouble() * 2 * math.pi;
    final r = math.sqrt(1 - u * u);
    return S2Point(r * math.cos(theta), r * math.sin(theta), u);
  }
}

/// Unit tests for MutableS2Point and MutableS2PointList.
void main() {
  late _TestData data;

  setUp(() {
    data = _TestData();
  });

  group('MutableS2Point', () {
    test('testMutableS2PointImpl', () {
      final p123 = S2Point(1, 2, 3);
      final p234 = S2Point(2, 3, 4);
      final mutablePoint = MutableS2PointImpl();
      expect(mutablePoint.isEqualTo(p123), isFalse);
      mutablePoint.setFromPoint(p123);
      expect(mutablePoint.isEqualTo(p123), isTrue);
      expect(mutablePoint.isEqualTo(p234), isFalse);
      mutablePoint.set(2, 3, 4);
      expect(mutablePoint.isEqualTo(p234), isTrue);
      expect(mutablePoint.isEqualTo(p123), isFalse);
      expect(mutablePoint.getX(), equals(2.0));
      expect(mutablePoint.getY(), equals(3.0));
      expect(mutablePoint.getZ(), equals(4.0));
    });

    test('testMutableS2PointCompare', () {
      final pair = MutableS2PointList.pair();

      // Test where point 1 is greater than point 0, comparison only needs to consider X.
      pair.setFromS2Point(0, S2Point(1, 2, 3));
      pair.setFromS2Point(1, S2Point(2, 3, 4));

      expect(pair.getAt(0).compareTo(pair.getAt(1)) < 0, isTrue);
      expect(pair.getAt(1).compareTo(pair.getAt(0)) > 0, isTrue);
      expect(pair.getAt(0).compareTo(pair.getAt(0)), equals(0));

      // Same comparisons, but on the list directly
      expect(pair.compare(0, 1) < 0, isTrue);
      expect(pair.compare(1, 0) > 0, isTrue);
      expect(pair.compare(0, 0), equals(0));

      // Test where point 1 is less than point 0, with equal X, tie-breaking on Y.
      pair.setFromS2Point(1, S2Point(1, 1, 1));
      expect(pair.getAt(0).compareTo(pair.getAt(1)) > 0, isTrue);
      expect(pair.getAt(1).compareTo(pair.getAt(0)) < 0, isTrue);
      expect(pair.getAt(1).compareTo(pair.getAt(1)), equals(0));

      // Same comparisons, but on the list directly
      expect(pair.compare(0, 1) > 0, isTrue);
      expect(pair.compare(1, 0) < 0, isTrue);
      expect(pair.compare(1, 1), equals(0));

      // Test tie-break on Z.
      pair.setFromS2Point(0, S2Point(1, 1, 0));
      expect(pair.getAt(0).compareTo(pair.getAt(1)) < 0, isTrue);
      expect(pair.getAt(1).compareTo(pair.getAt(0)) > 0, isTrue);

      // Same comparisons, but on the list directly
      expect(pair.compare(0, 1) < 0, isTrue);
      expect(pair.compare(1, 0) > 0, isTrue);
    });

    test('testListGetAndSet', () {
      final list = MutableS2PointList.pair();
      expect(list.size, equals(2));
      list.setFromS2Point(0, S2Point(1, 2, 3));
      list.setFromS2Point(1, S2Point(2, 3, 4));

      final mutablePoint = list.newElement();
      list.get(0, mutablePoint);
      expect(mutablePoint.isEqualTo(S2Point(1, 2, 3)), isTrue);
      list.get(1, mutablePoint);
      expect(mutablePoint.isEqualTo(S2Point(2, 3, 4)), isTrue);

      // Test the MutableS2Point interface provided by getAt().
      final inList = list.getAt(0);
      expect(inList.isEqualTo(S2Point(1, 2, 3)), isTrue);
      inList.set(2, 3, 4);
      expect(inList.isEqualToMutable(list.getAt(1)), isTrue);
      inList.setFromPoint(S2Point(1, 0, 1));
      expect(list.getAt(0).isEqualTo(S2Point(1, 0, 1)), isTrue);
      inList.setFromPoint(S2Point(2, 3, 4));
      expect(list.isEqualToAt(0, S2Point(2, 3, 4)), isTrue);
      list.set(1, inList);
      expect(list.isEqualToAt(1, S2Point(2, 3, 4)), isTrue);
    });

    test('testMoreListOperations', () {
      final list = MutableS2PointList();
      expect(list.isEmpty, isTrue);
      list.addCoords(1, 2, 3);
      list.addCoords(2, 3, 4);
      expect(list.isEmpty, isFalse);

      // Get a list entry as an S2Point and check it.
      final immutablePoint = list.getImmutable(1);
      final expectedPoint = S2Point(2, 3, 4);
      expect(immutablePoint.equalsPoint(expectedPoint), isTrue);

      final mutablePoint = list.newElement();

      // Access to entries outside of the range throws an exception.
      expect(() => list.getAt(2), throwsRangeError);
      expect(() => list.getImmutable(2), throwsRangeError);
      expect(() => list.setFromS2Point(2, S2Point(1, 2, 3)), throwsRangeError);
      expect(() => list.get(2, mutablePoint), throwsRangeError);

      list.addS2Point(S2Point(3, 4, 5));
      expect(list.size, equals(3));
      expect(list.getAt(2).isEqualTo(S2Point(3, 4, 5)), isTrue);

      // Test the various isEqualTo methods
      final p0 = list.newElement();
      list.get(0, p0);
      expect(list.isEqualToMutableAt(0, p0), isTrue);
      expect(list.isEqualToMutableAt(1, p0), isFalse);

      list.get(0, mutablePoint);
      expect(mutablePoint.isEqualToMutable(p0), isTrue);

      expect(list.isEqualToIndices(0, 0), isTrue);
      expect(list.isEqualToIndices(1, 0), isFalse);

      expect(list.isEqualToMutableAt(2, p0), isFalse);
      expect(list.isEqualToIndices(0, 2), isFalse);
      list.copy(0, 2);
      expect(list.isEqualToMutableAt(2, p0), isTrue);
      expect(list.isEqualToIndices(0, 2), isTrue);
    });

    test('testAccessInvalidMutableS2Point', () {
      final list = MutableS2PointList.withSize(3);
      list.setFromS2Point(0, S2Point(0, 0, 1));
      list.setFromS2Point(1, S2Point(0, 0, 1));
      list.setFromS2Point(2, S2Point(0, 0, 2));

      final inList = list.getAt(0);
      expect(inList.isEqualTo(S2Point(0, 0, 1)), isTrue);

      // After clear(), the MutableS2Point 'inList' is no longer valid, although that's not checked.
      list.clear();
      expect(list.size, equals(0));
      // inList is not actually "in" the list any more, but the array is still there.
      expect(inList.isEqualTo(S2Point(0, 0, 1)), isTrue);
      // Add a point (as coordinates) at index 0, which is what inList is pointing at.
      list.addCoords(1, 1, 1);
      // Now inList is valid again, but has different contents.
      expect(inList.isEqualTo(S2Point(1, 1, 1)), isTrue);
    });

    test('testCopyConstructor', () {
      // Size zero, default capacity.
      final l1 = MutableS2PointList();
      l1.addS2Point(S2Point(1, 2, 3));
      l1.addS2Point(S2Point(2, 3, 4));
      expect(l1.size, equals(2));
      expect(l1.capacity, equals(MutableS2PointList.defaultCapacity));

      // Copy constructor.
      final l2 = MutableS2PointList.from(l1);

      // Size and capacity of the copied list should both be 2.
      expect(l2.size, equals(2));
      expect(l2.capacity, equals(2));
      // And contents should be the same.
      expect(l2.getAt(0).isEqualTo(S2Point(1, 2, 3)), isTrue);
      expect(l2.getAt(1).isEqualTo(S2Point(2, 3, 4)), isTrue);

      // Enlarge the copied list, and verify that the capacity increases to the next power of two.
      l2.enlarge(5);
      expect(l2.size, equals(5));
      expect(l2.capacity, equals(8));
    });

    test('testAsMutablePointList', () {
      final mutablePointList = MutableS2PointList();
      mutablePointList.addCoords(1, 2, 3);
      mutablePointList.addCoords(2, 3, 4);
      mutablePointList.addCoords(3, 4, 5);

      final asList = mutablePointList.asList();
      expect(asList.length, equals(3));
      expect(asList[0].isEqualTo(S2Point(1, 2, 3)), isTrue);
      expect(asList[1].isEqualTo(S2Point(2, 3, 4)), isTrue);
      expect(asList[2].isEqualTo(S2Point(3, 4, 5)), isTrue);

      // Verify that set() works
      final newValue = mutablePointList.newElement();
      newValue.set(4, 5, 6);
      asList[1] = newValue;
      expect(mutablePointList.getAt(1).isEqualTo(S2Point(4, 5, 6)), isTrue);
    });

    test('testAsPointList', () {
      final mutablePointList = MutableS2PointList();
      mutablePointList.addCoords(1, 2, 3);
      mutablePointList.addCoords(2, 3, 4);
      mutablePointList.addCoords(3, 4, 5);

      final asPointList = mutablePointList.asPointList();
      expect(asPointList.length, equals(3));
      expect(asPointList[0].equalsPoint(S2Point(1, 2, 3)), isTrue);
      expect(asPointList[1].equalsPoint(S2Point(2, 3, 4)), isTrue);
      expect(asPointList[2].equalsPoint(S2Point(3, 4, 5)), isTrue);

      // Verify that set() works
      asPointList[1] = S2Point(4, 5, 6);
      expect(mutablePointList.getAt(1).isEqualTo(S2Point(4, 5, 6)), isTrue);
    });

    test('testPullIterator', () {
      final mutablePointList = MutableS2PointList();
      mutablePointList.addCoords(1, 2, 3);
      mutablePointList.addCoords(2, 3, 4);
      mutablePointList.addCoords(3, 4, 5);

      final mutablePoint = mutablePointList.newElement();
      final it = mutablePointList.iterator(mutablePoint);

      // The mutablePoint isn't set until pull() is called, so has uninitialized contents.
      expect(mutablePoint.isEqualTo(S2Point(0, 0, 0)), isTrue);
      expect(it.pull(), isTrue);
      expect(mutablePoint.isEqualTo(S2Point(1, 2, 3)), isTrue);
      expect(it.pull(), isTrue);
      expect(mutablePoint.isEqualTo(S2Point(2, 3, 4)), isTrue);
      expect(it.pull(), isTrue);
      expect(mutablePoint.isEqualTo(S2Point(3, 4, 5)), isTrue);
      expect(it.pull(), isFalse);
    });

    test('testMutablePointListForEach', () {
      // Set up a list of 10 points, (0,0,0), (1,0,0), ... (9,0,0).
      final list = MutableS2PointList();
      for (int i = 0; i < 10; i++) {
        list.addCoords(i.toDouble(), 0, 0);
      }

      int counter = 0;

      // Visit all the points as coordinates.
      expect(list.forEachPoint((x, y, z) {
        // Verify that entries are visited in order.
        final xi = x.round();
        expect(counter, equals(xi));
        counter++;
        return true; // Don't stop visiting.
      }), isTrue);
      expect(counter, equals(10));

      // Reset the counter and visit some of the points as coordinates, stopping early.
      counter = 0;
      expect(list.forEachPoint((x, y, z) {
        // Verify that entries are visited in order.
        final xi = x.round();
        expect(counter, equals(xi));
        counter++;
        return (xi != 8); // Stop visiting when we see the ninth point, with x=8.
      }), isFalse);
      expect(counter, equals(9));

      // Visit all the points as index and coordinates.
      counter = 0;
      expect(list.forEachIndexedPoint((i, x, y, z) {
        // Verify that entries are visited in order.
        final xi = x.round();
        expect(counter, equals(xi));
        expect(xi, equals(i));
        counter++;
        return true; // Don't stop visiting.
      }), isTrue);
      expect(counter, equals(10));

      // Same again but stop early.
      counter = 0;
      expect(list.forEachIndexedPoint((i, x, y, z) {
        // Verify that entries are visited in order.
        final xi = x.round();
        expect(counter, equals(xi));
        expect(xi, equals(i));
        counter++;
        return (xi != 8); // Stop visiting when we see the ninth point, with x=8.
      }), isFalse);
      expect(counter, equals(9));
    });

    test('testRandomSequences', () {
      for (int i = 0; i < 100; i++) {
        final length = data.nextInt(500);
        final pointArrayList = <S2Point>[];

        // Test with various initial capacities, but always with initial size zero.
        MutableS2PointList mutablePointList;
        final capacityCase = data.nextInt(4);
        switch (capacityCase) {
          case 0:
            mutablePointList = MutableS2PointList(); // Default capacity.
            break;
          case 1:
            mutablePointList = MutableS2PointList.ofCapacity(0); // Capacity zero.
            break;
          case 2:
            mutablePointList = MutableS2PointList.ofCapacity(length); // Capacity == length.
            break;
          case 3:
            mutablePointList = MutableS2PointList.ofCapacity(length + 16); // Capacity > length.
            break;
          default:
            throw AssertionError('Unexpected case: ${data.nextInt(3)}');
        }

        // Add 'length' random points to the list.
        for (int j = 0; j < length; j++) {
          final point = data.getRandomPoint();
          pointArrayList.add(point);
          mutablePointList.addS2Point(point);
        }
        assertEqualLists(pointArrayList, mutablePointList);

        // Truncate both lists. Might be a no-op if they're already shorter.
        if (pointArrayList.length > 100) {
          pointArrayList.removeRange(100, pointArrayList.length);
        }
        mutablePointList.truncate(100);
        assertEqualLists(pointArrayList, mutablePointList);

        // Modify the contents of both lists.
        for (int j = 0; j < pointArrayList.length; j++) {
          final point = data.getRandomPoint();
          pointArrayList[j] = point;
          mutablePointList.setFromS2Point(j, point);
        }
        assertEqualLists(pointArrayList, mutablePointList);

        // Sort both lists.
        pointArrayList.sort();
        mutablePointList.sort();
        assertEqualLists(pointArrayList, mutablePointList);
      }
    });
  });
}

void assertEqualLists(List<S2Point> expected, MutableS2PointList actual) {
  expect(actual.size, equals(expected.length));
  for (int i = 0; i < expected.length; i++) {
    expect(actual.isEqualToAt(i, expected[i]), isTrue);
  }
}
