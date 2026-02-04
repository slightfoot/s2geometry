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

import 'package:test/test.dart';

import 'package:s2geometry/s2geometry.dart';

void main() {
  group('S2Predicates', () {
    /// Relabeled for brevity in its many, many uses below.
    const double eps = S2.dblEpsilon;

    test('testSignCollinearPoints', () {
      // The following points happen to be *exactly collinear* along a line that
      // is approximately tangent to the surface of the unit sphere. In fact, C
      // is the exact midpoint of the line segment AB. All of these points are
      // close enough to unit length to satisfy S2.isUnitLength.
      final a = S2Point(0.7257192787703683, 0.460588256058891, 0.5110674973050485);
      final b = S2Point(0.7257192746638208, 0.4605882657381817, 0.5110674944131274);
      final c = S2Point(0.7257192767170946, 0.46058826089853633, 0.511067495859088);
      expect(c - a, equals(b - c));
      expect(S2Predicates.sign(a, b, c), isNot(0));
      expect(S2Predicates.sign(b, c, a), equals(S2Predicates.sign(a, b, c)));
      expect(S2Predicates.sign(c, b, a), equals(-S2Predicates.sign(a, b, c)));

      // The points "x1" and "x2" are exactly proportional, i.e. they both lie on
      // a common line through the origin. Both points are considered to be
      // normalized, and in fact they both satisfy (x == x.normalize()).
      // Therefore the triangle (x1, x2, -x1) consists of three distinct points
      // that all lie on a common line through the origin.
      final x1 = S2Point(0.9999999999999999, 1.4901161193847655e-08, 0);
      final x2 = S2Point(1, 1.4901161193847656e-08, 0);
      expect(x1, equals(x1.normalize()));
      expect(x2, equals(x2.normalize()));
      expect(S2Predicates.sign(x1, x2, -x1), isNot(0));
      expect(S2Predicates.sign(x2, -x1, x1), equals(S2Predicates.sign(x1, x2, -x1)));
      expect(S2Predicates.sign(-x1, x2, x1), equals(-S2Predicates.sign(x1, x2, -x1)));

      // Here are two more points that are distinct, exactly proportional, and
      // that satisfy (x == x.normalize()).
      final x3 = S2Point(1, 1, 1).normalize();
      final x4 = x3 * 0.9999999999999999;
      expect(x3, equals(x3.normalize()));
      expect(x4, equals(x4.normalize()));
      expect(x3, isNot(equals(x4)));
      expect(S2Predicates.sign(x3, x4, -x3), isNot(0));

      // The following two points demonstrate that normalize() is not idempotent,
      // i.e. y0.normalize() != y0.normalize().normalize(). Both points satisfy
      // S2.isNormalized(), though, and the two points are exactly proportional.
      final y0 = S2Point(1, 1, 0);
      final y1 = y0.normalize();
      final y2 = y1.normalize();
      expect(y1, isNot(equals(y2)));
      expect(y2, equals(y2.normalize()));
      expect(S2Predicates.sign(y1, y2, -y1), isNot(0));
      expect(S2Predicates.sign(y2, -y1, y1), equals(S2Predicates.sign(y1, y2, -y1)));
      expect(S2Predicates.sign(-y1, y2, y1), equals(-S2Predicates.sign(y1, y2, -y1)));
    });

    test('testSignSymbolicPerturbationCodeCoverage0', () {
      // Given 3 points A, B, C that are exactly coplanar with the origin and
      // where A < B < C in lexicographic order, verifies that ABC is
      // counterclockwise (if expected == 1) or clockwise (if expected == -1).
      void checkSymbolicSign(int expected, S2Point a, S2Point b, S2Point c) {
        expect(a.compareTo(b), lessThan(0));
        expect(a.compareTo(c), lessThan(0));
        expect(a.dotProd(b.crossProd(c)), equals(0.0));

        expect(Sign.expensive(a, b, c, true), equals(expected));
        expect(Sign.expensive(b, c, a, true), equals(expected));
        expect(Sign.expensive(c, a, b, true), equals(expected));
        expect(Sign.expensive(c, b, a, true), equals(-expected));
        expect(Sign.expensive(b, a, c, true), equals(-expected));
        expect(Sign.expensive(a, c, b, true), equals(-expected));
      }

      checkSymbolicSign(1, S2Point(-3, -1, 0), S2Point(-2, 1, 0), S2Point(1, -2, 0));
      checkSymbolicSign(1, S2Point(-6, 3, 3), S2Point(-4, 2, -1), S2Point(-2, 1, 4));
      checkSymbolicSign(1, S2Point(0, -1, -1), S2Point(0, 1, -2), S2Point(0, 2, 1));
    });

    test('testSignSymbolicPerturbationCodeCoverage1', () {
      void checkSymbolicSign(int expected, S2Point a, S2Point b, S2Point c) {
        expect(a.compareTo(b), lessThan(0));
        expect(a.compareTo(c), lessThan(0));
        expect(a.dotProd(b.crossProd(c)), equals(0.0));

        expect(Sign.expensive(a, b, c, true), equals(expected));
        expect(Sign.expensive(b, c, a, true), equals(expected));
        expect(Sign.expensive(c, a, b, true), equals(expected));
        expect(Sign.expensive(c, b, a, true), equals(-expected));
        expect(Sign.expensive(b, a, c, true), equals(-expected));
        expect(Sign.expensive(a, c, b, true), equals(-expected));
      }

      // From this point onward, B or C must be zero, or B is proportional to C.
      checkSymbolicSign(1, S2Point(-1, 2, 7), S2Point(2, 1, -4), S2Point(4, 2, -8));
      checkSymbolicSign(1, S2Point(-4, -2, 7), S2Point(2, 1, -4), S2Point(4, 2, -8));
      checkSymbolicSign(1, S2Point(0, -5, 7), S2Point(0, -4, 8), S2Point(0, -2, 4));
      checkSymbolicSign(1, S2Point(-5, -2, 7), S2Point(0, 0, -2), S2Point(0, 0, -1));
      checkSymbolicSign(1, S2Point(0, -2, 7), S2Point(0, 0, 1), S2Point(0, 0, 2));
    });

    test('testSignSymbolicPerturbationCodeCoverage2', () {
      void checkSymbolicSign(int expected, S2Point a, S2Point b, S2Point c) {
        expect(a.compareTo(b), lessThan(0));
        expect(a.compareTo(c), lessThan(0));
        expect(a.dotProd(b.crossProd(c)), equals(0.0));

        expect(Sign.expensive(a, b, c, true), equals(expected));
        expect(Sign.expensive(b, c, a, true), equals(expected));
        expect(Sign.expensive(c, a, b, true), equals(expected));
        expect(Sign.expensive(c, b, a, true), equals(-expected));
        expect(Sign.expensive(b, a, c, true), equals(-expected));
        expect(Sign.expensive(a, c, b, true), equals(-expected));
      }

      // From this point onward, C must be zero.
      checkSymbolicSign(1, S2Point(-3, 1, 7), S2Point(-1, -4, 1), S2Point(0, 0, 0));
      checkSymbolicSign(1, S2Point(-6, -4, 7), S2Point(-3, -2, 1), S2Point(0, 0, 0));
      checkSymbolicSign(-1, S2Point(0, -4, 7), S2Point(0, -2, 1), S2Point(0, 0, 0));
      checkSymbolicSign(-1, S2Point(-1, -4, 5), S2Point(0, 0, -3), S2Point(0, 0, 0));
      checkSymbolicSign(1, S2Point(0, -4, 5), S2Point(0, 0, -5), S2Point(0, 0, 0));
    });

    test('testAngleContainsVertex', () {
      final a = S2Point(1, 0, 0);
      final b = S2Point(0, 1, 0);
      final refB = S2.refDir(b);

      // Degenerate angle ABA.
      expect(S2Predicates.angleContainsVertex(a, b, a), isFalse);

      // An angle where A == ortho(B).
      expect(S2Predicates.angleContainsVertex(refB, b, a), isTrue);

      // An angle where C == ortho(B).
      expect(S2Predicates.angleContainsVertex(a, b, refB), isFalse);
    });

    test('testSignWithCrossProdExpensiveFallback', () {
      // Test that signWithCrossProd falls back to expensive computation
      // when the triage result is uncertain (near collinear points).
      // Use exactly collinear points that force the expensive path.
      final a = S2Point(0.7257192787703683, 0.460588256058891, 0.5110674973050485);
      final b = S2Point(0.7257192746638208, 0.4605882657381817, 0.5110674944131274);
      final c = S2Point(0.7257192767170946, 0.46058826089853633, 0.511067495859088);
      final aCrossB = a.crossProd(b);
      // Should return non-zero result via expensive fallback
      final result = S2Predicates.signWithCrossProd(a, b, c, aCrossB);
      expect(result, isNot(0));
      // Verify consistency with regular sign
      expect(result, equals(S2Predicates.sign(a, b, c)));
    });
  });
}

