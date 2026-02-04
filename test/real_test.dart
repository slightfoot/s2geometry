// Copyright 2014 Google Inc.
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

import 'geometry_test_case.dart';

void main() {
  group('Real', () {
    test('testBasicOperations', () {
      // Test basic creation and doubleValue
      final r1 = Real.fromDouble(1.5);
      expect(r1.doubleValue(), equals(1.5));

      final r2 = Real.fromDouble(2.5);
      expect(r2.doubleValue(), equals(2.5));

      // Test signum
      expect(Real.fromDouble(0.0).signum(), equals(0));
      expect(Real.fromDouble(1.0).signum(), equals(1));
      expect(Real.fromDouble(-1.0).signum(), equals(-1));
    });

    test('testNegate', () {
      final r = Real.fromDouble(3.14);
      final neg = r.negate();
      expect(neg.doubleValue(), equals(-3.14));

      // Double negation should return to original
      expect(neg.negate().doubleValue(), equals(3.14));
    });

    test('testAddDoubles', () {
      // Test exact addition
      final result = Real.addDoubles(1.0, 2.0);
      expect(result.doubleValue(), equals(3.0));

      // Test addition with potentially rounding values
      final r1 = Real.addDoubles(0.1, 0.2);
      // The exact sum of 0.1 + 0.2 in floating point isn't exactly 0.3
      expect(r1.doubleValue(), closeTo(0.3, 1e-15));
    });

    test('testSubDoubles', () {
      final result = Real.subDoubles(5.0, 3.0);
      expect(result.doubleValue(), equals(2.0));

      // Test subtraction with rounding
      final r1 = Real.subDoubles(0.3, 0.1);
      expect(r1.doubleValue(), closeTo(0.2, 1e-15));
    });

    test('testMulDoubles', () {
      final result = Real.mulDoubles(3.0, 4.0);
      expect(result.doubleValue(), equals(12.0));

      final r1 = Real.mulDoubles(2.5, 4.0);
      expect(r1.doubleValue(), equals(10.0));
    });

    test('testAdd', () {
      final r1 = Real.fromDouble(1.0);
      final r2 = Real.fromDouble(2.0);
      final sum = r1.add(r2);
      expect(sum.doubleValue(), equals(3.0));

      // Test with Reals created from addDoubles
      final r3 = Real.addDoubles(0.1, 0.2);
      final r4 = Real.addDoubles(0.3, 0.4);
      final sum2 = r3.add(r4);
      expect(sum2.doubleValue(), closeTo(1.0, 1e-14));
    });

    test('testSub', () {
      final r1 = Real.fromDouble(5.0);
      final r2 = Real.fromDouble(3.0);
      final diff = r1.sub(r2);
      expect(diff.doubleValue(), equals(2.0));
    });

    test('testMul', () {
      final r1 = Real.fromDouble(3.0);
      final result = r1.mul(4.0);
      expect(result.doubleValue(), equals(12.0));

      // Test chained multiplication
      final r2 = Real.fromDouble(2.0);
      final chained = r2.mul(3.0).mul(4.0);
      expect(chained.doubleValue(), equals(24.0));
    });

    test('testStrictMul', () {
      // Test normal case
      final result = Real.strictMul(3.0, 4.0);
      expect(result.doubleValue(), equals(12.0));

      // Test edge case with 1.0
      final isA = Real.strictMul(-2.5, 1.0);
      assertIdentical(isA.doubleValue(), -2.5);

      // Test edge case with 0.0
      final isZero = Real.strictMul(2.5, 0.0);
      assertIdentical(isZero.doubleValue(), 0.0);
    });

    test('testStrictMulUnderflow', () {
      // This should throw ArithmeticException for underflow
      final a = -2.594e-321;
      final b = 0.9991685425907498;

      expect(() => Real.strictMul(a, b), throwsA(isA<ArithmeticException>()));

      // Also test with strictMulDouble
      final realA = Real.fromDouble(a);
      expect(() => realA.strictMulDouble(b), throwsA(isA<ArithmeticException>()));
    });

    test('testSerialArithmetic', () {
      // Test that serial additions and multiplications accumulate correctly
      final rand = math.Random(42);
      Real realSum = Real.fromDouble(0);
      double normalSum = 0;

      for (int i = 0; i < 50; i++) {
        double d = rand.nextDouble();
        realSum = realSum.add(Real.fromDouble(d));
        normalSum += d;
      }

      // Real should be at least as accurate as normal double
      expect(realSum.doubleValue(), closeTo(normalSum, 1e-10));
    });

    test('testToString', () {
      final r = Real.fromDouble(3.14159);
      expect(r.toString(), equals('3.14159'));
    });

    test('testArithmeticExceptionToString', () {
      final ex = ArithmeticException('test error message');
      expect(ex.toString(), equals('ArithmeticException: test error message'));
      expect(ex.message, equals('test error message'));
    });
  });
}

