// Copyright 2018 Google Inc.
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
import 's2.dart';
import 's2_point.dart';

/// A collection of geometric predicates core to the robustness of the S2 library.
///
/// In particular:
/// - [sign]: Compute the orientation of a triple of points as clockwise (-1),
///   collinear (0), or counter-clockwise (1).
class S2Predicates {
  /// Maximum rounding error of a 64 bit double.
  static const double dblErr = S2.dblError;

  /// Rounding error of numeric type used for computation.
  static const double _tErr = dblErr;

  S2Predicates._();

  /// Returns +1 if the points A, B, C are counterclockwise, -1 if the points
  /// are clockwise, and 0 if any two points are the same.
  ///
  /// This function is essentially like taking the sign of the determinant of
  /// ABC, except that it has additional logic to make sure that the above
  /// properties hold even when the three points are coplanar, and to deal with
  /// the limitations of floating-point arithmetic.
  ///
  /// Sign satisfies the following conditions:
  /// 1. sign(a,b,c) == 0 iff a==b || b==c || c==a
  /// 2. sign(b,c,a) == sign(a,b,c), for all a,b,c
  /// 3. sign(c,b,a) == -sign(a,b,c), for all a,b,c
  static int sign(S2Point a, S2Point b, S2Point c) {
    return Sign.sign(a, b, c, true);
  }

  /// If precomputed cross-product of A and B is available, this version of
  /// sign is more efficient.
  static int signWithCrossProd(S2Point a, S2Point b, S2Point c, S2Point aCrossB) {
    int sign = Sign.triageWithCrossProd(aCrossB, c);
    if (sign == 0) {
      sign = Sign.expensive(a, b, c, true);
    }
    return sign;
  }

  /// Return true if the edges OA, OB, and OC are encountered in that order
  /// while sweeping CCW around the point O.
  ///
  /// REQUIRES: a != o && b != o && c != o
  static bool orderedCCW(S2Point a, S2Point b, S2Point c, S2Point o) {
    // The last inequality below is ">" rather than ">=" so that we return true
    // if A == B or B == C, and otherwise false if A == C.
    int sum = 0;
    if (sign(b, o, a) >= 0) {
      ++sum;
    }
    if (sign(c, o, b) >= 0) {
      ++sum;
    }
    if (sign(a, o, c) > 0) {
      ++sum;
    }
    return sum >= 2;
  }

  /// Returns true if the angle ABC contains its vertex B.
  ///
  /// REQUIRES: a != b && b != c.
  static bool angleContainsVertex(S2Point a, S2Point b, S2Point c) {
    assert(a != b);
    assert(b != c);
    return !orderedCCW(S2.refDir(b), c, a, b);
  }

  /// Returns the same result as signum, or 0 if 'value' is within 'error' of 0.
  static int _signum(double value, double error) {
    return value > error ? 1 : (value < -error ? -1 : 0);
  }
}

/// Tests of whether three points represent a left turn (+1), right turn (-1),
/// or neither (0).
class Sign {
  Sign._();

  /// Returns +1 if the points are definitely CCW, -1 if they are definitely CW,
  /// and 0 if two points are identical or the result is uncertain.
  static int triage(S2Point a, S2Point b, S2Point c) {
    const double kMaxDetError = 1.6e-15; // 2 * 14 * 2**-54
    double det = S2Point.scalarTripleProduct(c, a, b);
    if (det >= kMaxDetError) {
      return 1;
    }
    if (det <= -kMaxDetError) {
      return -1;
    }
    return 0;
  }

  /// Version of triage that takes a precomputed cross product.
  static int triageWithCrossProd(S2Point aCrossB, S2Point c) {
    double kMaxDetError = 1.8274 * Platform.dblEpsilon;
    double det = aCrossB.dotProd(c);
    if (det > kMaxDetError) {
      return 1;
    }
    if (det < -kMaxDetError) {
      return -1;
    }
    return 0;
  }

  /// Returns the sign of the turn ABC.
  static int sign(S2Point a, S2Point b, S2Point c, bool perturb) {
    int sign = triage(a, b, c);
    if (sign == 0) {
      sign = expensive(a, b, c, perturb);
    }
    return sign;
  }

  /// Returns the sign of the determinant using more expensive techniques.
  static int expensive(S2Point a, S2Point b, S2Point c, bool perturb) {
    // Return zero if and only if two points are the same.
    if (a == b || b == c || c == a) {
      return 0;
    }

    int sign = stable(a, b, c);
    if (sign != 0) {
      return sign;
    }

    return exact(a, b, c, perturb);
  }

  /// Compute the determinant in a numerically stable way.
  static int stable(S2Point a, S2Point b, S2Point c) {
    S2Point ab = b - a;
    S2Point bc = c - b;
    S2Point ca = a - c;
    double ab2 = ab.norm2;
    double bc2 = bc.norm2;
    double ca2 = ca.norm2;

    // Compute the determinant with the longest edge as the "base".
    const double detErrorMultiplier = 3.2321 * Platform.dblEpsilon;
    double det;
    double maxError;
    if (ab2 >= bc2 && ab2 >= ca2) {
      det = -S2Point.scalarTripleProduct(c, ca, bc);
      maxError = detErrorMultiplier * math.sqrt(ca2 * bc2);
    } else if (bc2 >= ca2) {
      det = -S2Point.scalarTripleProduct(a, ab, ca);
      maxError = detErrorMultiplier * math.sqrt(ab2 * ca2);
    } else {
      det = -S2Point.scalarTripleProduct(b, bc, ab);
      maxError = detErrorMultiplier * math.sqrt(bc2 * ab2);
    }
    return S2Predicates._signum(det, maxError);
  }

  /// Computes the determinant using exact arithmetic and/or symbolic perturbations.
  static int exact(S2Point a, S2Point b, S2Point c, bool perturb) {
    assert(a != b);
    assert(b != c);
    assert(c != a);

    // Use Platform.sign() which uses Real class for exact arithmetic.
    int sign = Platform.sign(a, b, c);
    if (sign != 0) {
      return sign;
    }

    // Sort the 3 points in lexicographic order, keeping track of the sign
    // of the permutation.
    int permSign = 1;
    if (a.compareTo(b) > 0) {
      S2Point t = a;
      a = b;
      b = t;
      permSign = -permSign;
    }
    if (b.compareTo(c) > 0) {
      S2Point t = b;
      b = c;
      c = t;
      permSign = -permSign;
    }
    if (a.compareTo(b) > 0) {
      S2Point t = a;
      a = b;
      b = t;
      permSign = -permSign;
    }
    assert(S2.skipAssertions || (a.compareTo(b) < 0 && b.compareTo(c) < 0));

    // Handle NaN values.
    if (a.x.isNaN || a.y.isNaN || a.z.isNaN ||
        b.x.isNaN || b.y.isNaN || b.z.isNaN ||
        c.x.isNaN || c.y.isNaN || c.z.isNaN) {
      return -permSign;
    }

    // Check the determinant using BigPoint, which provides exact arithmetic.
    final BigPoint xa = BigPoint.fromS2Point(a);
    final BigPoint xb = BigPoint.fromS2Point(b);
    final BigPoint xc = BigPoint.fromS2Point(c);
    final BigPoint xbc = xb.crossProd(xc);
    sign = _doubleSign(xbc.dotProd(xa));
    if (sign != 0) {
      return permSign * sign;
    }

    // If !perturb, then the caller has requested no SoS tie breaking.
    if (!perturb) {
      return 0;
    }

    // Resort to symbolic perturbations.
    sign = sos(xa, xb, xc, xbc);
    assert(sign != 0);
    return permSign * sign;
  }

  /// Returns the sign of the determinant using Simulation of Simplicity.
  static int sos(BigPoint a, BigPoint b, BigPoint c, BigPoint bc) {
    assert(a.compareTo(b) < 0);
    assert(b.compareTo(c) < 0);

    int sign = bc.zSignum; // da[2]
    if (sign != 0) return sign;

    sign = bc.ySignum; // da[1]
    if (sign != 0) return sign;

    sign = bc.xSignum; // da[0]
    if (sign != 0) return sign;

    sign = _doubleSign(c.x * a.y - c.y * a.x); // db[2]
    if (sign != 0) return sign;

    sign = _doubleSign(c.x); // db[2] * da[1]
    if (sign != 0) return sign;

    sign = -_doubleSign(c.y); // db[2] * da[0]
    if (sign != 0) return sign;

    sign = _doubleSign(c.z * a.x - c.x * a.z); // db[1]
    if (sign != 0) return sign;

    sign = _doubleSign(c.z); // db[1] * da[0]
    if (sign != 0) return sign;

    sign = _doubleSign(a.x * b.y - a.y * b.x); // dc[2]
    if (sign != 0) return sign;

    sign = -_doubleSign(b.x); // dc[2] * da[1]
    if (sign != 0) return sign;

    sign = _doubleSign(b.y); // dc[2] * da[0]
    if (sign != 0) return sign;

    sign = _doubleSign(a.x); // dc[2] * db[1]
    if (sign != 0) return sign;

    return 1; // dc[2] * db[1] * da[0]
  }

  /// Returns the sign of a double value as an int (-1, 0, or 1).
  static int _doubleSign(double value) {
    return value > 0 ? 1 : (value < 0 ? -1 : 0);
  }
}

