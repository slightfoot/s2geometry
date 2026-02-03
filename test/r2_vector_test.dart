// Copyright 2013 Google Inc. All Rights Reserved.
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

/// Tests for R2Vector.
/// Ported from R2VectorTest.java
library;

import 'package:test/test.dart';
import 'package:s2geometry/s2geometry.dart';

import 'geometry_test_case.dart';

void main() {
  group('R2Vector', () {
    test('testConstructors', () {
      final coordinates = <double>[1.5, 2.5];
      final v = R2Vector.fromArray(coordinates);
      expect(v, equals(R2Vector(1.5, 2.5)));
      assertExactly(1.5, v.x);
      assertExactly(2.5, v.y);
    });

    test('testOrtho', () {
      expect(R2Vector(1, 1), equals(R2Vector(1, -1).ortho()));
      expect(R2Vector(1, -1), equals(R2Vector(-1, -1).ortho()));
      expect(R2Vector(-1, -1), equals(R2Vector(-1, 1).ortho()));
      expect(R2Vector(1, 1), equals(R2Vector(1, -1).ortho()));
    });

    test('testAdd', () {
      expect(R2Vector(5, 5), equals(R2Vector.addStatic(R2Vector(4, 3), R2Vector(1, 2))));
      expect(R2Vector(5, 5), equals(R2Vector(4, 3).add(R2Vector(1, 2))));
    });

    test('testSub', () {
      expect(R2Vector(3, 1), equals(R2Vector.subStatic(R2Vector(4, 3), R2Vector(1, 2))));
      expect(R2Vector(3, 1), equals(R2Vector(4, 3).sub(R2Vector(1, 2))));
    });

    test('testMul', () {
      assertAlmostEquals(12.0, R2Vector.mulStatic(R2Vector(4, 3), 3.0).x);
      assertAlmostEquals(9.0, R2Vector.mulStatic(R2Vector(4, 3), 3.0).y);
      assertAlmostEquals(12.0, R2Vector(4, 3).mul(3.0).x);
      assertAlmostEquals(9.0, R2Vector(4, 3).mul(3.0).y);
    });
  });
}
