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

/// Verifies R1Interval.
/// Ported from R1IntervalTest.java
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

/// Test all of the interval operations on the given pair of intervals.
///
/// [expected] is a sequence of "T" and "F" characters corresponding to the
/// expected results of contains(), interiorContains(), intersects(), and
/// interiorIntersects() respectively.
void testIntervalOps(R1Interval x, R1Interval y, String expected) {
  expect(x.contains(y), equals(expected[0] == 'T'));
  expect(x.interiorContains(y), equals(expected[1] == 'T'));
  expect(x.intersects(y), equals(expected[2] == 'T'));
  expect(x.interiorIntersects(y), equals(expected[3] == 'T'));
  expect(x.contains(y), equals(x.union(y) == x));
  expect(x.intersects(y), equals(!x.intersection(y).isEmpty));
}

void main() {
  group('R1Interval', () {
    test('testBasics', () {
      // Constructors and accessors.
      final unit = R1Interval(0, 1);
      final negunit = R1Interval(-1, 0);
      assertExactly(0, unit.lo);
      assertExactly(1, unit.hi);
      assertExactly(-1, negunit.getValue(R1IntervalEndpoint.lo));
      assertExactly(-1, negunit.getValue(R1IntervalEndpoint.lo));
      assertExactly(0, negunit.getValue(R1IntervalEndpoint.hi));
      final ten = R1Interval(0, 0);
      ten.setValue(R1IntervalEndpoint.hi, 10);
      expect(ten, equals(R1Interval(0, 10)));
      ten.lo = -10;
      expect(ten, equals(R1Interval(-10, 10)));
      ten.hi = 0;
      expect(ten, equals(R1Interval(-10, 0)));
      ten.set(0, 10);
      expect(ten, equals(R1Interval(0, 10)));

      // is_empty()
      final half = R1Interval(0.5, 0.5);
      expect(unit.isEmpty, isFalse);
      expect(half.isEmpty, isFalse);
      final empty = R1Interval.empty();
      expect(empty.isEmpty, isTrue);

      // Equality.
      expect(empty == empty, isTrue);
      expect(unit == unit, isTrue);
      expect(unit == empty, isFalse);
      expect(R1Interval(1, 2) == R1Interval(1, 3), isFalse);

      // Check that the default R1Interval is identical to Empty().
      final defaultEmpty = R1Interval.init();
      expect(defaultEmpty.isEmpty, isTrue);
      assertExactly(empty.lo, defaultEmpty.lo);
      assertExactly(empty.hi, defaultEmpty.hi);

      // getCenter(), getLength()
      assertExactly(0.5, unit.getCenter());
      assertExactly(0.5, half.getCenter());
      assertExactly(1.0, negunit.getLength());
      assertExactly(0.0, half.getLength());
      expect(empty.getLength() < 0, isTrue);

      // contains(double), interiorContains(double)
      expect(unit.containsPoint(0.5), isTrue);
      expect(unit.interiorContainsPoint(0.5), isTrue);
      expect(unit.containsPoint(0), isTrue);
      expect(unit.interiorContainsPoint(0), isFalse);
      expect(unit.containsPoint(1), isTrue);
      expect(unit.interiorContainsPoint(1), isFalse);

      // contains(R1Interval), interiorContains(R1Interval)
      // intersects(R1Interval), interiorIntersects(R1Interval)
      testIntervalOps(empty, empty, 'TTFF');
      testIntervalOps(empty, unit, 'FFFF');
      testIntervalOps(unit, half, 'TTTT');
      testIntervalOps(unit, unit, 'TFTT');
      testIntervalOps(unit, empty, 'TTFF');
      testIntervalOps(unit, negunit, 'FFTF');
      testIntervalOps(unit, R1Interval(0, 0.5), 'TFTT');
      testIntervalOps(half, R1Interval(0, 0.5), 'FFTF');

      // addPoint()
      var r = empty;
      r = r.addPoint(5);
      assertExactly(5, r.lo);
      assertExactly(5, r.hi);
      r = r.addPoint(-1);
      assertExactly(-1, r.lo);
      assertExactly(5, r.hi);
      r = r.addPoint(0);
      assertExactly(-1, r.lo);
      assertExactly(5, r.hi);

      // unionInternal()
      r = R1Interval.empty();
      r.unionInternal(5);
      assertExactly(5, r.lo);
      assertExactly(5, r.hi);
      r.unionInternal(-1);
      assertExactly(-1, r.lo);
      assertExactly(5, r.hi);
      r.unionInternal(0);
      assertExactly(-1, r.lo);
      assertExactly(5, r.hi);

      // clampPoint()
      assertExactly(0.3, R1Interval(0.1, 0.4).clampPoint(0.3));
      assertExactly(0.1, R1Interval(0.1, 0.4).clampPoint(-7.0));
      assertExactly(0.4, R1Interval(0.1, 0.4).clampPoint(0.6));

      // fromPointPair()
      expect(R1Interval(4, 4), equals(R1Interval.fromPointPair(4, 4)));
      expect(R1Interval(-2, -1), equals(R1Interval.fromPointPair(-1, -2)));
      expect(R1Interval(-5, 3), equals(R1Interval.fromPointPair(-5, 3)));

      // expanded()
      expect(empty.expanded(0.45), equals(empty));
      expect(unit.expanded(0.5), equals(R1Interval(-0.5, 1.5)));
      expect(unit.expanded(-0.5), equals(R1Interval(0.5, 0.5)));
      expect(unit.expanded(-0.51).isEmpty, isTrue);
      expect(unit.expanded(-0.51).expanded(0.51).isEmpty, isTrue);

      // union(), intersection()
      expect(R1Interval(99, 100).union(empty), equals(R1Interval(99, 100)));
      expect(empty.union(R1Interval(99, 100)), equals(R1Interval(99, 100)));
      expect(R1Interval(5, 3).union(R1Interval(0, -2)).isEmpty, isTrue);
      expect(R1Interval(0, -2).union(R1Interval(5, 3)).isEmpty, isTrue);
      expect(unit.union(unit), equals(unit));
      expect(unit.union(negunit), equals(R1Interval(-1, 1)));
      expect(negunit.union(unit), equals(R1Interval(-1, 1)));
      expect(half.union(unit), equals(unit));
      expect(unit.intersection(half), equals(half));
      expect(unit.intersection(negunit), equals(R1Interval(0, 0)));
      expect(negunit.intersection(half).isEmpty, isTrue);
      expect(unit.intersection(empty).isEmpty, isTrue);
      expect(empty.intersection(unit).isEmpty, isTrue);
    });

    test('testApproxEquals', () {
      // Choose two values kLo and kHi such that it's okay to shift an endpoint by kLo (i.e., the
      // resulting interval is equivalent) but not by kHi. The kLo bound is a bit closer to epsilon
      // in Java compared to C++.
      final kLo = 2 * S2.dblEpsilon; // < max_error default
      final kHi = 6 * S2.dblEpsilon; // > max_error default

      // Empty intervals.
      final empty = R1Interval.empty();
      expect(empty.approxEquals(empty), isTrue);
      expect(R1Interval(0, 0).approxEquals(empty), isTrue);
      expect(empty.approxEquals(R1Interval(0, 0)), isTrue);
      expect(R1Interval(1, 1).approxEquals(empty), isTrue);
      expect(empty.approxEquals(R1Interval(1, 1)), isTrue);
      expect(empty.approxEquals(R1Interval(0, 1)), isFalse);
      expect(empty.approxEquals(R1Interval(1, 1 + 2 * kLo)), isTrue);
      expect(empty.approxEquals(R1Interval(1, 1 + 2 * kHi)), isFalse);

      // Singleton intervals.
      expect(R1Interval(1, 1).approxEquals(R1Interval(1, 1)), isTrue);
      expect(R1Interval(1, 1).approxEquals(R1Interval(1 - kLo, 1 - kLo)), isTrue);
      expect(R1Interval(1, 1).approxEquals(R1Interval(1 + kLo, 1 + kLo)), isTrue);
      expect(R1Interval(1, 1).approxEquals(R1Interval(1 - kHi, 1)), isFalse);
      expect(R1Interval(1, 1).approxEquals(R1Interval(1, 1 + kHi)), isFalse);
      expect(R1Interval(1, 1).approxEquals(R1Interval(1 - kLo, 1 + kLo)), isTrue);
      expect(R1Interval(0, 0).approxEquals(R1Interval(1, 1)), isFalse);

      // Other intervals.
      expect(R1Interval(1 - kLo, 2 + kLo).approxEquals(R1Interval(1, 2)), isTrue);
      expect(R1Interval(1 + kLo, 2 - kLo).approxEquals(R1Interval(1, 2)), isTrue);
      expect(R1Interval(1 - kHi, 2 + kLo).approxEquals(R1Interval(1, 2)), isFalse);
      expect(R1Interval(1 + kHi, 2 - kLo).approxEquals(R1Interval(1, 2)), isFalse);
      expect(R1Interval(1 - kLo, 2 + kHi).approxEquals(R1Interval(1, 2)), isFalse);
      expect(R1Interval(1 + kLo, 2 - kHi).approxEquals(R1Interval(1, 2)), isFalse);
    });

    test('testOpposites', () {
      expect(R1IntervalEndpoint.hi.opposite, equals(R1IntervalEndpoint.lo));
      expect(R1IntervalEndpoint.lo.opposite, equals(R1IntervalEndpoint.hi));
      expect(R1IntervalEndpoint.lo.opposite.opposite, equals(R1IntervalEndpoint.lo));
      expect(R1IntervalEndpoint.hi.opposite.opposite, equals(R1IntervalEndpoint.hi));
    });

    test('testUppercaseEndpoints', () {
      // Test uppercase endpoint aliases
      expect(R1IntervalEndpoint.LO.opposite, equals(R1IntervalEndpoint.hi));
      expect(R1IntervalEndpoint.HI.opposite, equals(R1IntervalEndpoint.lo));
      final interval = R1Interval(1, 5);
      expect(interval.getValue(R1IntervalEndpoint.LO), equals(1.0));
      expect(interval.getValue(R1IntervalEndpoint.HI), equals(5.0));
      interval.setValue(R1IntervalEndpoint.LO, 2);
      expect(interval.lo, equals(2.0));
      interval.setValue(R1IntervalEndpoint.HI, 10);
      expect(interval.hi, equals(10.0));
    });

    test('testGetDirectedHausdorffDistance', () {
      final empty = R1Interval.empty();
      final unit = R1Interval(0, 1);
      final larger = R1Interval(-1, 2);

      // Empty interval has distance 0
      expect(empty.getDirectedHausdorffDistance(unit), equals(0.0));
      // Distance to empty interval is maxFinite
      expect(unit.getDirectedHausdorffDistance(empty), equals(double.maxFinite));
      // Same interval has distance 0
      expect(unit.getDirectedHausdorffDistance(unit), equals(0.0));
      // Larger interval contains unit - distance is 0
      expect(unit.getDirectedHausdorffDistance(larger), equals(0.0));
      // Unit doesn't fully cover larger
      expect(larger.getDirectedHausdorffDistance(unit), greaterThan(0.0));
    });

    test('testSetEmpty', () {
      final interval = R1Interval(1, 5);
      expect(interval.isEmpty, isFalse);
      interval.setEmpty();
      expect(interval.isEmpty, isTrue);
    });

    test('testUnionInternalInterval', () {
      // Union with empty
      final r1 = R1Interval(1, 5);
      final empty = R1Interval.empty();
      r1.unionInternalInterval(empty);
      expect(r1, equals(R1Interval(1, 5)));

      // Empty unioned with non-empty
      final r2 = R1Interval.empty();
      r2.unionInternalInterval(R1Interval(2, 4));
      expect(r2, equals(R1Interval(2, 4)));

      // Two non-empty intervals
      final r3 = R1Interval(1, 3);
      r3.unionInternalInterval(R1Interval(2, 5));
      expect(r3, equals(R1Interval(1, 5)));
    });

    test('testIntersectionInternal', () {
      final r = R1Interval(0, 10);
      r.intersectionInternal(R1Interval(5, 15));
      expect(r, equals(R1Interval(5, 10)));

      final r2 = R1Interval(0, 5);
      r2.intersectionInternal(R1Interval(10, 15));
      expect(r2.isEmpty, isTrue);
    });

    test('testExpandedInternal', () {
      final r = R1Interval(5, 10);
      r.expandedInternal(2);
      expect(r, equals(R1Interval(3, 12)));

      final r2 = R1Interval(0, 10);
      r2.expandedInternal(-3);
      expect(r2, equals(R1Interval(3, 7)));
    });

    test('testHashCode', () {
      final empty1 = R1Interval.empty();
      final empty2 = R1Interval.empty();
      expect(empty1.hashCode, equals(empty2.hashCode));

      final interval1 = R1Interval(1, 5);
      final interval2 = R1Interval(1, 5);
      expect(interval1.hashCode, equals(interval2.hashCode));

      final interval3 = R1Interval(2, 6);
      expect(interval1.hashCode, isNot(equals(interval3.hashCode)));
    });

    test('testToString', () {
      final interval = R1Interval(1.5, 3.5);
      final str = interval.toString();
      expect(str, contains('1.5'));
      expect(str, contains('3.5'));
    });

    test('testCopyConstructor', () {
      final original = R1Interval(2, 8);
      final copy = R1Interval.copy(original);
      expect(copy, equals(original));
      original.lo = 0;
      expect(copy.lo, equals(2.0)); // copy is independent
    });

    test('testCenterAndLengthGetters', () {
      final interval = R1Interval(2, 6);
      expect(interval.center, equals(4.0));
      expect(interval.length, equals(4.0));
    });

    test('testEqualityWithNonInterval', () {
      final interval = R1Interval(1, 5);
      expect(interval == "not an interval", isFalse);
    });

    // Note: Java serialization test is not applicable to Dart
  });
}
