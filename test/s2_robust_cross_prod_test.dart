// Copyright 2022 Google Inc.
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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

void main() {
  group('S2RobustCrossProd', () {
    test('testRobustCrossProdBasic', () {
      // Basic orthogonal vectors
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final result = S2RobustCrossProd.robustCrossProd(a, b);

      // Result should be orthogonal to both inputs
      expect(result.dotProd(a).abs(), lessThan(1e-10));
      expect(result.dotProd(b).abs(), lessThan(1e-10));
      expect(result.norm2, greaterThan(0));
    });

    test('testRobustCrossProdAntiSymmetric', () {
      // Test RCP(b,a) == -RCP(a,b)
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final ab = S2RobustCrossProd.robustCrossProd(a, b);
      final ba = S2RobustCrossProd.robustCrossProd(b, a);

      expect(ab.x, closeTo(-ba.x, 1e-10));
      expect(ab.y, closeTo(-ba.y, 1e-10));
      expect(ab.z, closeTo(-ba.z, 1e-10));
    });

    test('testRobustCrossProdEqualPoints', () {
      // When a == b, should return something orthogonal
      final a = S2Point(1, 0, 0).normalize();
      final result = S2RobustCrossProd.robustCrossProd(a, a);

      // Result should be non-zero
      expect(result.norm2, greaterThan(0));

      // Result should be orthogonal to input
      expect(result.dotProd(a).abs(), lessThan(1e-10));
    });

    test('testExactCrossProdEqualPoints', () {
      final a = S2Point(1, 0, 0).normalize();
      final result = S2RobustCrossProd.exactCrossProd(a, a);

      expect(result.norm2, greaterThan(0));
      expect(result.dotProd(a).abs(), lessThan(1e-10));
    });

    test('testStableCrossProdOrthogonalVectors', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final result = S2RobustCrossProd.stableCrossProd(a, b);

      expect(result, isNotNull);
      expect(result!.norm2, greaterThan(0));
    });

    test('testStableCrossProdNearlyParallelVectors', () {
      // Nearly parallel vectors should still work
      final a = S2Point(1, 0, 0);
      final b = S2Point(1, 1e-10, 0).normalize();
      final result = S2RobustCrossProd.stableCrossProd(a, b);

      // May return null for very close vectors, or a valid result
      if (result != null) {
        expect(result.norm2, greaterThan(0));
      }
    });

    test('testRealCrossProd', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final result = S2RobustCrossProd.realCrossProd(a, b);

      expect(result, isNotNull);
      expect(result!.norm2, greaterThan(0));
    });

    test('testBigDecimalCrossProd', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final result = S2RobustCrossProd.bigDecimalCrossProd(a, b);

      expect(result, isNotNull);
      expect(result!.norm2, greaterThan(0));
    });

    test('testSymbolicCrossProdBasic', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final result = S2RobustCrossProd.symbolicCrossProd(a, b);

      expect(result.norm2, greaterThan(0));
    });

    test('testSymbolicCrossProdAntiSymmetric', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final ab = S2RobustCrossProd.symbolicCrossProd(a, b);
      final ba = S2RobustCrossProd.symbolicCrossProd(b, a);

      // Should be antisymmetric
      expect(ab.x, closeTo(-ba.x, 1e-10));
      expect(ab.y, closeTo(-ba.y, 1e-10));
      expect(ab.z, closeTo(-ba.z, 1e-10));
    });

    test('testSymbolicCrossProdZAxis', () {
      // Test with z-axis aligned vectors
      final a = S2Point(0, 0, 1);
      final b = S2Point(1, 0, 0);
      final result = S2RobustCrossProd.symbolicCrossProd(a, b);

      expect(result.norm2, greaterThan(0));
    });

    test('testRobustCrossProdNonZeroResult', () {
      // Test that we always get a non-zero result
      final a = S2Point(0, 0, 1);
      final b = S2Point(0, 0, -1); // Antipodal

      final result = S2RobustCrossProd.robustCrossProd(a, b);
      expect(result.norm2, greaterThan(0));
    });

    test('testSymbolicCrossProdXYNonZero', () {
      // Test _symbolicCrossProdSorted when b.x != 0 or b.y != 0
      final a = S2Point(0, 0, 1);
      final b = S2Point(0.5, 0.5, 0).normalize();
      final result = S2RobustCrossProd.symbolicCrossProd(a, b);
      expect(result.norm2, greaterThan(0));
    });

    test('testSymbolicCrossProdZOnly', () {
      // Test _symbolicCrossProdSorted when b.z != 0 and b.x == b.y == 0
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 0, 1);
      final result = S2RobustCrossProd.symbolicCrossProd(a, b);
      expect(result.norm2, greaterThan(0));
    });

    test('testStableCrossProdReturnsNull', () {
      // Test that stableCrossProd returns null for nearly identical vectors
      final a = S2Point(1, 0, 0);
      final result = S2RobustCrossProd.stableCrossProd(a, a);
      expect(result, isNull);
    });

    test('testRealCrossProdReturnsNullForIdentical', () {
      // Test realCrossProd for identical unit vectors
      final a = S2Point(1, 0, 0);
      final result = S2RobustCrossProd.realCrossProd(a, a);
      // May return null because result would be zero
      expect(result, isNull);
    });

    test('testBigDecimalCrossProdIdentical', () {
      // Test bigDecimalCrossProd for identical points
      final a = S2Point(1, 0, 0);
      final result = S2RobustCrossProd.bigDecimalCrossProd(a, a);
      // May return null because result would be zero
      expect(result, isNull);
    });

    test('testRobustCrossProdNearlyOpposite', () {
      // Test nearly opposite points (a ~= -b)
      final a = S2Point(1, 0, 0);
      final b = S2Point(-1, 1e-15, 0).normalize();
      final result = S2RobustCrossProd.robustCrossProd(a, b);
      expect(result.norm2, greaterThan(0));
    });

    test('testExactCrossProdFallthrough', () {
      // Test that exactCrossProd goes through various fallback methods
      final a = S2Point(1, 1e-100, 0).normalize();
      final b = S2Point(1, 2e-100, 0).normalize();
      final result = S2RobustCrossProd.exactCrossProd(a, b);
      expect(result.norm2, greaterThan(0));
    });

    test('testSymbolicCrossProdOrderDependence', () {
      // Test that symbolic cross prod uses correct ordering
      final a = S2Point(0.3, 0.4, 0.5).normalize();
      final b = S2Point(0.5, 0.4, 0.3).normalize();

      final ab = S2RobustCrossProd.symbolicCrossProd(a, b);
      final ba = S2RobustCrossProd.symbolicCrossProd(b, a);

      // Should be antisymmetric
      expect(ab.x + ba.x, closeTo(0, 1e-10));
      expect(ab.y + ba.y, closeTo(0, 1e-10));
      expect(ab.z + ba.z, closeTo(0, 1e-10));
    });

    test('testDiagonalVectors', () {
      // Test with diagonal vectors
      final a = S2Point(1, 1, 0).normalize();
      final b = S2Point(1, -1, 0).normalize();

      final result = S2RobustCrossProd.robustCrossProd(a, b);
      expect(result.norm2, greaterThan(0));
      // Result should point in z direction
      expect(result.z.abs(), greaterThan(result.x.abs()));
      expect(result.z.abs(), greaterThan(result.y.abs()));
    });
  });
}

