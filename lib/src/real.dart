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

/// Provides portable support for exact arithmetic operations on double values,
/// without loss of precision. It stores an array of double values, and
/// operations that require additional bits of precision return Reals with
/// larger arrays.
///
/// Converting a sequence of a dozen arithmetic operations to use Real can take
/// up to 20 times longer than the natural but imprecise approach of using
/// built in double operators like + and *. Compared to other approaches like
/// BigDecimal that consume more memory and typically slow operations down by
/// a factor of 100, that's great, but use of this class should still be avoided
/// when imprecise results will suffice.
///
/// Many of the algorithms in this class were adapted from the multiple
/// components technique for extended 64-bit IEEE 754 floating point precision,
/// as described in:
///
/// "Robust Adaptive Floating-Point Geometric Predicates"
/// Jonathan Richard Shewchuk
/// School of Computer Science
/// Carnegie Mellon University
class Real {
  /// Used to split doubles into two half-length values, for exact multiplication.
  /// The value should be Math.pow(2, Math.ceil(mantissaBits / 2)) + 1.
  static final double _splitter = _computeSplitter();

  static double _computeSplitter() {
    // Find half ulp(1). We could use Math.ulp but it's not supported on GWT.
    double epsilon = 1.0;
    do {
      epsilon *= 0.5;
    } while (1.0 + epsilon != 1.0);
    int mantissaBits = (-math.log(epsilon) / math.ln2).round();
    return (1 << ((mantissaBits + 1) ~/ 2)) + 1.0;
  }

  /// A sequence of ordinary double values, ordered by magnitude in ascending
  /// order, containing no zeroes and with no overlapping base 2 digits.
  final List<double> _values;

  /// Creates a Real based on the given double value.
  Real.fromDouble(double value) : _values = [value];

  Real._(this._values);

  /// Returns the result of a + b, without loss of precision.
  static Real addDoubles(double a, double b) {
    double x = a + b;
    double error = _twoSumError(a, b, x);
    return Real._([error, x]);
  }

  /// Returns the result of a - b, without loss of precision.
  static Real subDoubles(double a, double b) {
    double x = a - b;
    double error = _twoDiffError(a, b, x);
    return Real._([error, x]);
  }

  /// Returns the result of a * b, with minimal loss of precision.
  static Real mulDoubles(double a, double b) {
    double x = a * b;
    double bhi = _splitHigh(b);
    double blo = _splitLow(b, bhi);
    double error = _twoProductError(a, bhi, blo, x);
    return Real._([error, x]);
  }

  /// Returns the result of a * b. An error is thrown if we detect precision loss.
  static Real strictMul(double a, double b) {
    double x = a * b;
    double bhi = _splitHigh(b);
    double blo = _splitLow(b, bhi);
    double error = _twoProductError(a, bhi, blo, x);
    if (_twoProductUnderflowCheck(a, b, x, error)) {
      throw ArithmeticException('twoProductError underflowed');
    }
    return Real._([error, x]);
  }

  /// Returns the result of this + that, without loss of precision.
  Real add(Real that) => _add(this, that, false);

  /// Returns the result of this - that, without loss of precision.
  Real sub(Real that) => _add(this, that, true);

  /// Returns the result of adding together the components of a and b,
  /// inverting each element of b if negateB is true.
  static Real _add(Real a, Real b, bool negateB) {
    double bSign = negateB ? -1.0 : 1.0;
    List<double> result = List<double>.filled(a._values.length + b._values.length, 0.0);
    int aIndex = 0;
    int bIndex = 0;

    double sum;
    double newSum;
    double error;
    if (_smallerMagnitude(a._values[aIndex], b._values[bIndex])) {
      sum = a._values[aIndex++];
    } else {
      sum = bSign * b._values[bIndex++];
    }

    int resultIndex = 0;
    double smaller;
    if ((aIndex < a._values.length) && (bIndex < b._values.length)) {
      if (_smallerMagnitude(a._values[aIndex], b._values[bIndex])) {
        smaller = a._values[aIndex++];
      } else {
        smaller = bSign * b._values[bIndex++];
      }
      newSum = smaller + sum;
      error = _fastTwoSumError(smaller, sum, newSum);
      sum = newSum;
      if (error != 0.0) {
        result[resultIndex++] = error;
      }
      while ((aIndex < a._values.length) && (bIndex < b._values.length)) {
        if (_smallerMagnitude(a._values[aIndex], b._values[bIndex])) {
          smaller = a._values[aIndex++];
        } else {
          smaller = bSign * b._values[bIndex++];
        }
        newSum = sum + smaller;
        error = _twoSumError(sum, smaller, newSum);
        sum = newSum;
        if (error != 0.0) {
          result[resultIndex++] = error;
        }
      }
    }
    while (aIndex < a._values.length) {
      smaller = a._values[aIndex++];
      newSum = sum + smaller;
      error = _twoSumError(sum, smaller, newSum);
      sum = newSum;
      if (error != 0.0) {
        result[resultIndex++] = error;
      }
    }
    while (bIndex < b._values.length) {
      smaller = bSign * b._values[bIndex++];
      newSum = sum + smaller;
      error = _twoSumError(sum, smaller, newSum);
      sum = newSum;
      if (error != 0.0) {
        result[resultIndex++] = error;
      }
    }
    if ((sum != 0.0) || (resultIndex == 0)) {
      result[resultIndex++] = sum;
    }

    if (result.length > resultIndex) {
      result = result.sublist(0, resultIndex);
    }
    return Real._(result);
  }

  /// Returns true if the magnitude of a is less than the magnitude of b.
  static bool _smallerMagnitude(double a, double b) {
    return (b > a) == (b > -a);
  }

  /// Returns the result of this * scale, without loss of precision.
  Real mul(double scale) => _mul(scale, false);

  /// Returns the result of this * scale. Throws if precision loss detected.
  Real strictMulDouble(double scale) => _mul(scale, true);

  Real _mul(double scale, bool isStrict) {
    List<double> result = List<double>.filled(_values.length * 2, 0.0);
    double scaleHigh = _splitHigh(scale);
    double scaleLow = _splitLow(scale, scaleHigh);
    double quotient = _values[0] * scale;
    double error = _twoProductError(_values[0], scaleHigh, scaleLow, quotient);
    if (isStrict && _twoProductUnderflowCheck(_values[0], scale, quotient, error)) {
      throw ArithmeticException('twoProductError underflowed');
    }
    int resultIndex = 0;
    if (error != 0) {
      result[resultIndex++] = error;
    }
    for (int i = 1; i < _values.length; i++) {
      double term = _values[i] * scale;
      double termError = _twoProductError(_values[i], scaleHigh, scaleLow, term);
      if (isStrict && _twoProductUnderflowCheck(_values[0], scale, quotient, termError)) {
        throw ArithmeticException('twoProductError underflowed');
      }

      double sum = quotient + termError;
      error = _twoSumError(quotient, termError, sum);
      if (error != 0) {
        result[resultIndex++] = error;
      }
      quotient = term + sum;
      error = _fastTwoSumError(term, sum, quotient);
      if (error != 0) {
        result[resultIndex++] = error;
      }
    }
    if ((quotient != 0.0) || (resultIndex == 0)) {
      result[resultIndex++] = quotient;
    }
    if (result.length > resultIndex) {
      result = result.sublist(0, resultIndex);
    }
    return Real._(result);
  }

  /// Returns the negative of this number.
  Real negate() {
    List<double> copy = List<double>.filled(_values.length, 0.0);
    for (int i = _values.length - 1; i >= 0; i--) {
      copy[i] = -_values[i];
    }
    return Real._(copy);
  }

  /// Returns the signum of this number more quickly than via doubleValue().
  int signum() {
    double msb = _values[_values.length - 1];
    if (msb > 0) {
      return 1;
    } else if (msb < 0) {
      return -1;
    } else {
      return 0;
    }
  }

  /// Returns the double value nearest this Real.
  double doubleValue() {
    // Since the components are guaranteed to have no overlapping digits, we
    // could simply sum them without loss of precision... but to return a
    // double we truncate to the 53 bits of the largest exponent.
    double sum = 0;
    for (double value in _values) {
      sum += value;
    }
    return sum;
  }

  @override
  String toString() => doubleValue().toString();

  // Helper methods

  /// Returns the error in the sum x=a+b, when |a|>=|b|.
  static double _fastTwoSumError(double a, double b, double x) {
    return b - (x - a);
  }

  /// Returns the error in the sum x=a+b, when the relative magnitudes of a and
  /// b are not known in advance.
  static double _twoSumError(double a, double b, double x) {
    double error = x - a;
    return (a - (x - error)) + (b - error);
  }

  /// Returns the error in the difference x=a-b.
  static double _twoDiffError(double a, double b, double x) {
    double error = a - x;
    return (a - (x + error)) + (error - b);
  }

  /// Returns the high split for the given value.
  static double _splitHigh(double a) {
    double c = _splitter * a;
    return c - (c - a);
  }

  /// Returns the low split for the given value and previously-computed high
  /// split as returned by _splitHigh.
  static double _splitLow(double a, double ahi) {
    return a - ahi;
  }

  /// Returns the error in the product x=a*b, with precomputed splits for b.
  static double _twoProductError(double a, double bhi, double blo, double x) {
    double ahi = _splitHigh(a);
    double alo = _splitLow(a, ahi);
    double err1 = x - (ahi * bhi);
    double err2 = err1 - (alo * bhi);
    double err3 = err2 - (ahi * blo);
    return (alo * blo) - err3;
  }

  /// Returns true iff _twoProductError underflows.
  static bool _twoProductUnderflowCheck(double a, double b, double x, double error) {
    if (error == 0.0) {
      // First situation.
      bool operandEqualsOutput = (a == x) || (b == x);
      bool operandsNotOne = (a != 1.0) && (b != 1.0);
      bool operandsNotZero = (a != 0.0) && (b != 0.0);
      if (operandEqualsOutput && operandsNotOne && operandsNotZero) {
        return true;
      }
      // Second situation.
      bool xIsZero = x == 0.0;
      if (operandsNotZero && xIsZero) {
        return true;
      }
    }
    return false;
  }
}

/// Exception thrown when arithmetic operations fail due to precision issues.
class ArithmeticException implements Exception {
  final String message;
  ArithmeticException(this.message);

  @override
  String toString() => 'ArithmeticException: $message';
}

