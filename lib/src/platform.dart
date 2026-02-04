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

import 'dart:math' as math;
import 'dart:typed_data';

import 'real.dart';
import 's2_point.dart';

/// Platform-specific utilities.
class Platform {
  /// The smallest positive double value that, when added to 1.0, yields a result
  /// different from 1.0.
  static const double dblEpsilon = 2.220446049250313e-16;

  /// Returns the IEEE remainder of x/y.
  static double ieeeRemainder(double x, double y) {
    // Dart doesn't have a built-in IEEEremainder, so we implement it.
    // IEEEremainder(x, y) = x - y * round(x/y)
    final quotient = x / y;
    final n = quotient.roundToDouble();
    return x - n * y;
  }

  /// Returns the next representable double after start in the direction of direction.
  static double nextAfter(double start, double direction) {
    if (start.isNaN || direction.isNaN) return double.nan;
    if (start == direction) return direction;

    if (start == 0.0) {
      // Return smallest positive or negative value
      return direction > 0 ? double.minPositive : -double.minPositive;
    }

    // Use bit manipulation to get next/previous representable value
    final bytes = ByteData(8);
    bytes.setFloat64(0, start, Endian.little);
    var bits = bytes.getInt64(0, Endian.little);

    if ((start > 0) == (direction > start)) {
      bits++;
    } else {
      bits--;
    }

    bytes.setInt64(0, bits, Endian.little);
    return bytes.getFloat64(0, Endian.little);
  }

  /// Returns the number of leading zeros in a 64-bit integer.
  static int numberOfLeadingZeros(int x) {
    if (x == 0) return 64;
    int n = 0;
    if (x <= 0x00000000FFFFFFFF) {
      n += 32;
      x <<= 32;
    }
    if (x <= 0x0000FFFFFFFFFFFF) {
      n += 16;
      x <<= 16;
    }
    if (x <= 0x00FFFFFFFFFFFFFF) {
      n += 8;
      x <<= 8;
    }
    if (x <= 0x0FFFFFFFFFFFFFFF) {
      n += 4;
      x <<= 4;
    }
    if (x <= 0x3FFFFFFFFFFFFFFF) {
      n += 2;
      x <<= 2;
    }
    if (x <= 0x7FFFFFFFFFFFFFFF) {
      n += 1;
    }
    return n;
  }

  /// Returns the number of trailing zeros in a 64-bit integer.
  static int numberOfTrailingZeros(int x) {
    if (x == 0) return 64;
    int n = 0;
    if ((x & 0xFFFFFFFF) == 0) {
      n += 32;
      x >>= 32;
    }
    if ((x & 0xFFFF) == 0) {
      n += 16;
      x >>= 16;
    }
    if ((x & 0xFF) == 0) {
      n += 8;
      x >>= 8;
    }
    if ((x & 0xF) == 0) {
      n += 4;
      x >>= 4;
    }
    if ((x & 0x3) == 0) {
      n += 2;
      x >>= 2;
    }
    if ((x & 0x1) == 0) {
      n += 1;
    }
    return n;
  }

  /// Returns the exponent of a double value.
  static int getExponent(double d) {
    if (d.isNaN || d.isInfinite || d == 0) return 0;
    final bytes = ByteData(8);
    bytes.setFloat64(0, d, Endian.big);
    final bits = bytes.getInt64(0, Endian.big);
    // Extract exponent (bits 52-62) and subtract bias (1023)
    return ((bits >> 52) & 0x7FF) - 1023;
  }

  /// Returns 2^exp as a double.
  static double scalb(double d, int exp) {
    return d * math.pow(2.0, exp);
  }

  /// Returns the unsigned right shift of a 64-bit integer.
  static int unsignedRightShift(int value, int shift) {
    if (shift < 0 || shift >= 64) return 0;
    if (shift == 0) return value;
    // Dart doesn't have unsigned right shift, so we need to handle negative values
    if (value >= 0) {
      return value >> shift;
    }
    // For negative values, we need to mask and shift
    return (value >> shift) & ((1 << (64 - shift)) - 1);
  }

  /// Returns the ULP (Unit in the Last Place) of a double value.
  /// This is the positive distance between this value and the next larger representable value.
  static double ulp(double d) {
    if (d.isNaN) return double.nan;
    if (d.isInfinite) return double.infinity;
    if (d == 0.0) return double.minPositive;

    final dAbs = d.abs();
    final bytes = ByteData(8);
    bytes.setFloat64(0, dAbs, Endian.little);
    var bits = bytes.getInt64(0, Endian.little);
    bits++;
    bytes.setInt64(0, bits, Endian.little);
    return bytes.getFloat64(0, Endian.little) - dAbs;
  }

  /// Returns the sign of the determinant of the matrix constructed from the
  /// three column vectors [a], [b], and [c]. This operation is very robust for
  /// small determinants, but is extremely slow and should only be used if
  /// performance is not a concern or all faster techniques have been exhausted.
  static int sign(S2Point a, S2Point b, S2Point c) {
    try {
      Real bycz = Real.strictMul(b.y, c.z);
      Real bzcy = Real.strictMul(b.z, c.y);
      Real bzcx = Real.strictMul(b.z, c.x);

      Real bxcz = Real.strictMul(b.x, c.z);
      Real bxcy = Real.strictMul(b.x, c.y);
      Real bycx = Real.strictMul(b.y, c.x);

      Real bcx = bycz.sub(bzcy);
      Real bcy = bzcx.sub(bxcz);
      Real bcz = bxcy.sub(bycx);
      Real x = bcx.mul(a.x);
      Real y = bcy.mul(a.y);
      Real z = bcz.mul(a.z);
      return x.add(y).add(z).signum();
    } on ArithmeticException {
      return 0;
    }
  }
}
