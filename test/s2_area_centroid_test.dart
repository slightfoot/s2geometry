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

/// Port of S2AreaCentroidTest.java from the Google S2 Geometry Library.
library;

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2AreaCentroid', () {
    test('testSimple', () {
      final point = S2Point(0.1, 10.3, 7.5);
      final ac = S2AreaCentroid(5.0, point);
      expect(ac.area, equals(5.0));
      expect(ac.centroid, equals(point));
    });

    test('testZeroArea', () {
      final point = S2Point(1.0, 0.0, 0.0);
      final ac = S2AreaCentroid(0.0, point);
      expect(ac.area, equals(0.0));
      expect(ac.centroid, equals(point));
    });

    test('testNegativeArea', () {
      // Negative area can occur in some edge cases
      final point = S2Point(0.0, 1.0, 0.0);
      final ac = S2AreaCentroid(-1.5, point);
      expect(ac.area, equals(-1.5));
      expect(ac.centroid, equals(point));
    });

    test('testLargeValues', () {
      final point = S2Point(1e15, 1e-15, 1.0);
      final ac = S2AreaCentroid(1e10, point);
      expect(ac.area, equals(1e10));
      expect(ac.centroid!.x, equals(1e15));
      expect(ac.centroid!.y, equals(1e-15));
      expect(ac.centroid!.z, equals(1.0));
    });

    test('testEquality', () {
      final point1 = S2Point(1.0, 2.0, 3.0);
      final point2 = S2Point(1.0, 2.0, 3.0);
      final ac1 = S2AreaCentroid(5.0, point1);
      final ac2 = S2AreaCentroid(5.0, point2);
      // Note: S2AreaCentroid equality depends on S2Point equality
      expect(ac1.area, equals(ac2.area));
      expect(ac1.centroid, equals(ac2.centroid));
    });
  });
}

