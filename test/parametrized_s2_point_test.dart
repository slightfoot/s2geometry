// Copyright 2023 Google Inc.
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

/// Port of ParameterizedS2PointTest.java from the Google S2 Geometry Library.
library;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('ParametrizedS2Point', () {
    test('testSimple', () {
      final point = S2Point(1, 1e7, 1e-9);
      final p = ParametrizedS2Point(0.123, point);
      expect(p.time, equals(0.123));
      expect(p.point, equals(point));
    });

    test('testZeroTime', () {
      final point = S2Point(1.0, 0.0, 0.0);
      final p = ParametrizedS2Point(0.0, point);
      expect(p.time, equals(0.0));
      expect(p.point, equals(point));
    });

    test('testNegativeTime', () {
      final point = S2Point(0.0, 1.0, 0.0);
      final p = ParametrizedS2Point(-5.0, point);
      expect(p.time, equals(-5.0));
      expect(p.point, equals(point));
    });

    test('testLargeTime', () {
      final point = S2Point(0.0, 0.0, 1.0);
      final p = ParametrizedS2Point(1e20, point);
      expect(p.time, equals(1e20));
      expect(p.point, equals(point));
    });

    test('testDifferentPoints', () {
      final point1 = S2Point(1.0, 2.0, 3.0);
      final point2 = S2Point(4.0, 5.0, 6.0);
      final p1 = ParametrizedS2Point(1.0, point1);
      final p2 = ParametrizedS2Point(1.0, point2);
      expect(p1.time, equals(p2.time));
      expect(p1.point, isNot(equals(p2.point)));
    });

    test('testDifferentTimes', () {
      final point = S2Point(1.0, 2.0, 3.0);
      final p1 = ParametrizedS2Point(1.0, point);
      final p2 = ParametrizedS2Point(2.0, point);
      expect(p1.time, isNot(equals(p2.time)));
      expect(p1.point, equals(p2.point));
    });
  });
}

