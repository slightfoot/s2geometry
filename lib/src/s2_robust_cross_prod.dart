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

import 'dart:math' as math;

import 'big_point.dart';
import 'platform.dart';
import 'real.dart';
import 's2.dart';
import 's2_point.dart';

/// Class that implements robustCrossProd which will attempt to calculate the
/// cross product of two S2Points with increasingly precise but expensive
/// methods, as required to get a reliable result.
///
/// Methods used in order:
/// 1. Stable cross product: calculate (b+a) x (b-a) which should be more stable.
/// 2. Check if a == b. If so return some orthogonal S2Point.
/// 3. Calculate the cross product using Real which allows for more precision.
/// 4. Resort to calculating the cross product using BigDecimal-like precision.
/// 5. Lastly, calculate a symbolic cross product.
class S2RobustCrossProd {
  S2RobustCrossProd._();

  /// Return an S2Point "c" that is orthogonal to the given unit-length
  /// S2Points "a" and "b".
  ///
  /// This function is similar to a.crossProd(b) except that it does a better
  /// job of ensuring orthogonality when "a" is nearly parallel to "b", and it
  /// returns a non-zero result even when a == b or a == -b.
  ///
  /// Note: robustCrossProd makes no claims about the magnitude of the
  /// resulting S2Point. If this is important, you must call normalize() on
  /// the result. The result should always be scaled such that you can call
  /// normalize() without risking underflow.
  ///
  /// Properties:
  /// 1. RCP(a,b) != 0 for all a, b
  /// 2. RCP(b,a) == -RCP(a,b) unless a == b or a == -b
  /// 3. RCP(-a,b) == -RCP(a,b) unless a == b or a == -b
  /// 4. RCP(a,-b) == -RCP(a,b) unless a == b or a == -b
  static S2Point robustCrossProd(S2Point a, S2Point b) {
    final result = stableCrossProd(a, b);
    if (result != null) {
      return result;
    }
    return exactCrossProd(a, b);
  }

  /// Attempts to calculate the cross product in four steps. If the inputs are
  /// equal, then return some orthogonal S2Point. Otherwise attempts to compute
  /// a valid result using Reals followed by BigDecimal. If fail, falls back to
  /// doing a symbolically perturbed cross product.
  static S2Point exactCrossProd(S2Point a, S2Point b) {
    // Handle the (a == b) case now, before doing expensive arithmetic.
    if (a == b) {
      return S2.ortho(a);
    }

    final realResult = realCrossProd(a, b);
    if (realResult != null) {
      return realResult;
    }

    final bigResult = bigDecimalCrossProd(a, b);
    if (bigResult != null) {
      return bigResult;
    }

    return symbolicCrossProd(a, b);
  }

  /// Evaluates the cross product of unit-length S2Points "a" and "b" in a
  /// numerically stable way, returning a non-null result if the error in the
  /// result is guaranteed to be at most ROBUST_CROSS_PROD_ERROR.
  static S2Point? stableCrossProd(S2Point a, S2Point b) {
    // We compute the cross product (a - b) x (a + b). Mathematically this is
    // exactly twice the cross product of "a" and "b", but it has the numerical
    // advantage that (a - b) and (a + b) are nearly perpendicular (since "a"
    // and "b" are unit length).
    final result = b.add(a).crossProd(b.sub(a));
    if (result.norm2 < S2.minNorm * S2.minNorm) {
      return null;
    }
    return result;
  }

  /// Calculate the cross product by using Reals which allow for extended
  /// precision compared to simple double operations.
  ///
  /// Returns null if the calculated cross product results in the zero S2Point
  /// or if we detect Real error overflow.
  static S2Point? realCrossProd(S2Point a, S2Point b) {
    try {
      final sum = a.add(b);
      final difference = b.sub(a);

      final cx = Real.strictMul(sum.y, difference.z)
          .sub(Real.strictMul(sum.z, difference.y));
      final cy = Real.strictMul(sum.z, difference.x)
          .sub(Real.strictMul(sum.x, difference.z));
      final cz = Real.strictMul(sum.x, difference.y)
          .sub(Real.strictMul(sum.y, difference.x));
      final realResult = _normalizableFromReal(
          S2Point(cx.doubleValue(), cy.doubleValue(), cz.doubleValue()));

      if (realResult == S2Point.zero || !_isNormalizable(realResult)) {
        return null;
      }
      return realResult;
    } catch (e) {
      return null;
    }
  }

  /// Calculate the cross product by using BigPoint which allows for increased
  /// precision compared to simple double operations.
  static S2Point? bigDecimalCrossProd(S2Point a, S2Point b) {
    final ba = BigPoint.fromS2Point(a);
    final bb = BigPoint.fromS2Point(b);
    final axb = ba.crossProd(bb);
    final normalizable = _normalizeFromBigPoint(axb);
    if (normalizable == S2Point.zero) {
      return null;
    }
    return normalizable;
  }

  /// Calculate a symbolically perturbed cross product.
  static S2Point symbolicCrossProd(S2Point a, S2Point b) {
    if (a.lessThan(b)) {
      return _ensureNormalizable(_symbolicCrossProdSorted(a, b));
    }
    return _ensureNormalizable(_symbolicCrossProdSorted(b, a)).neg();
  }

  /// Returns the cross product of "a" and "b" after symbolic perturbations.
  /// (These perturbations only affect the result if "a" and "b" are exactly
  /// collinear, e.g. if a == -b or a == (1+eps) * b.)
  static S2Point _symbolicCrossProdSorted(S2Point a, S2Point b) {
    // The following code uses the same symbolic perturbation model as
    // S2Predicates.sign. See S2RobustCrossProd.java for full explanation.
    if (b.x != 0 || b.y != 0) {
      // da[2]
      return S2Point(-b.y, b.x, 0);
    }
    if (b.z != 0) {
      // da[1]
      return S2Point(b.z, 0, 0); // Note that b.x == 0.
    }
    // None of the remaining cases can occur in practice, because we can only
    // get to this point if b = (0, 0, 0).
    if (a.x != 0 || a.y != 0) {
      // db[2]
      return S2Point(a.y, -a.x, 0);
    }
    // The following coefficient is always non-zero.
    return const S2Point(1, 0, 0); // db[2] * da[1]
  }

  /// Scales an S2Point as necessary to ensure that the result can be
  /// normalized without loss of precision due to floating-point underflow.
  ///
  /// REQUIRES: p != (0, 0, 0)
  static S2Point _ensureNormalizable(S2Point point) {
    if (_isNormalizable(point)) {
      return point;
    }
    // We can't just scale by a fixed factor because the smallest representable
    // double is 2**-1074, so if we multiplied by 2**(1074 - 242) then the
    // result might be so large that we couldn't square it without overflow.
    //
    // Note that we must scale by a power of two to avoid rounding errors.
    final pmax =
        math.max(point.x.abs(), math.max(point.y.abs(), point.z.abs()));
    final factor = math.pow(2, -1 - Platform.getExponent(pmax)).toDouble();
    return point.mul(factor);
  }

  /// Returns a normalizable S2Point from an S2Point obtained by real
  /// calculations. It scales the result as necessary to ensure that the
  /// result can be normalized without loss of precision due to floating-point
  /// underflow.
  static S2Point _normalizableFromReal(S2Point point) {
    if (_isNormalizable(point)) {
      return point;
    }

    final largestAbs =
        math.max(point.x.abs(), math.max(point.y.abs(), point.z.abs()));

    return S2Point(
        point.x / largestAbs, point.y / largestAbs, point.z / largestAbs);
  }

  /// Returns a normalized S2Point from a BigPoint. It scales the result as
  /// necessary to ensure that the result can be normalized without loss of
  /// precision due to floating-point underflow.
  static S2Point _normalizeFromBigPoint(BigPoint bp) {
    final noScaling = bp.toS2Point();
    if (_isNormalizable(noScaling)) {
      return noScaling;
    }

    // Find the maximum exponent among non-zero components
    int? maxExponent;

    if (bp.x != 0) {
      maxExponent = Platform.getExponent(bp.x.abs());
    }
    if (bp.y != 0) {
      final yExp = Platform.getExponent(bp.y.abs());
      if (maxExponent == null || yExp > maxExponent) {
        maxExponent = yExp;
      }
    }
    if (bp.z != 0) {
      final zExp = Platform.getExponent(bp.z.abs());
      if (maxExponent == null || zExp > maxExponent) {
        maxExponent = zExp;
      }
    }

    if (maxExponent == null) {
      return S2Point.zero;
    }

    // Scale so largest component is between 0.5 and 1
    final factor = math.pow(2, -maxExponent - 1).toDouble();
    return S2Point(bp.x * factor, bp.y * factor, bp.z * factor);
  }

  /// Returns true if the given S2Point's magnitude is large enough such that
  /// the angle to another S2Point of the same magnitude can be measured using
  /// angle() without loss of precision due to floating-point underflow.
  static bool _isNormalizable(S2Point point) {
    // The fastest way to ensure this is to test whether the largest component
    // of the result has a magnitude of at least 2**-242.
    return math.max(point.x.abs(), math.max(point.y.abs(), point.z.abs())) >=
        math.pow(2, -242);
  }
}

