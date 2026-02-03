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

/// Common code for geometry tests.
/// Ported from GeometryTestCase.java
library;

import 'dart:typed_data';

import 'package:test/test.dart';

/// How many ULP's (Units in the Last Place) we want to tolerate when comparing
/// two numbers. The gtest framework for C++ also uses 4.
const int maxUlps = 4;

/// Tests that two double values have the same sign and are within 'maxUlps' of each other.
void assertDoubleUlpsWithin(double a, double b, int maxUlps, [String message = '']) {
  // Handle NaN
  if (a.isNaN) {
    fail("'a' is NaN. $message");
  }
  if (b.isNaN) {
    fail("'b' is NaN. $message");
  }

  // Handle exact equality, including +0 == -0 and infinity
  if (a == b) {
    return;
  }

  // If the signs are different, don't compare by ULP
  if (a.sign != b.sign && a != 0 && b != 0) {
    fail('$a and $b are not equal and have different signs. $message');
  }

  // Convert to bits and compare ULPs
  final bitsA = _doubleToBits(a);
  final bitsB = _doubleToBits(b);
  final ulpsDiff = (bitsA - bitsB).abs();

  if (ulpsDiff > maxUlps) {
    fail('$a and $b differ by $ulpsDiff units in the last place, expected <= $maxUlps. $message');
  }
}

/// Convert double to its bit representation for ULP comparison.
/// This handles the sign-magnitude to two's complement conversion.
int _doubleToBits(double d) {
  // Use ByteData to get the raw bits
  final bytes = ByteData(8);
  bytes.setFloat64(0, d, Endian.little);
  var bits = bytes.getInt64(0, Endian.little);
  
  // If negative, convert from sign-magnitude to two's complement
  if (bits < 0) {
    bits = 0x8000000000000000 - bits;
  }
  return bits;
}

/// Tests that two double values are almost equal using ULP-based comparison.
/// "Almost equal" means "a is at most MAX_ULPS (4) ULP's away from b".
void assertAlmostEquals(double a, double b, [String message = '']) {
  assertDoubleUlpsWithin(a, b, maxUlps, message);
}

/// Assert that val1 and val2 are within the given absError of each other.
void assertDoubleNear(double val1, double val2, double absError, [String message = '']) {
  final diff = (val1 - val2).abs();
  if (diff <= absError) {
    return;
  }
  
  if (message.isNotEmpty) {
    message = '$message\n';
  }
  fail('${message}The difference between $val1 and $val2 is $diff, which exceeds $absError by ${diff - absError}.');
}

/// Checks that two doubles are exactly equal.
/// Note that 0.0 exactly equals -0.0.
void assertExactly(double expected, double actual, [String message = '']) {
  if (message.isNotEmpty) {
    expect(actual, equals(expected), reason: message);
  } else {
    expect(actual, equals(expected));
  }
}

/// Succeeds if and only if x is less than y.
void assertLessThan<T extends Comparable<T>>(T x, T y) {
  expect(x.compareTo(y) < 0, isTrue, reason: 'Expected $x < $y but it is not.');
}

/// Succeeds if and only if x is greater than y.
void assertGreaterThan<T extends Comparable<T>>(T x, T y) {
  expect(x.compareTo(y) > 0, isTrue, reason: 'Expected $x > $y but it is not.');
}

/// Succeeds if and only if x is less than or equal to y.
void assertLessOrEqual<T extends Comparable<T>>(T x, T y) {
  expect(x.compareTo(y) <= 0, isTrue, reason: 'Expected $x <= $y but it is not.');
}

/// Succeeds if and only if x is greater than or equal to y.
void assertGreaterOrEqual<T extends Comparable<T>>(T x, T y) {
  expect(x.compareTo(y) >= 0, isTrue, reason: 'Expected $x >= $y but it is not.');
}

/// Succeeds if and only if x is between lo and hi inclusive.
void assertBetween<T extends Comparable<T>>(T x, T lo, T hi) {
  expect(x.compareTo(lo) >= 0, isTrue, reason: 'Expected $x >= $lo but it is not.');
  expect(x.compareTo(hi) <= 0, isTrue, reason: 'Expected $x <= $hi but it is not.');
}

