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

import 's2_point.dart';

/// The S2 class is a namespace for constants and static utility functions
/// related to spherical geometry.
///
/// The name "S2" is derived from the mathematical symbol for the
/// two-dimensional unit sphere.
class S2 {
  // Frequently used constants
  static const double pi = math.pi;
  static const double piOver2 = math.pi / 2.0;
  static const double piOver4 = math.pi / 4.0;
  static const double oneOverPi = 1.0 / math.pi;

  /// Inverse of the square root of 2.
  static final double sqrt1Over2 = 1.0 / math.sqrt(2);

  static final double sqrt2 = math.sqrt(2);
  static final double sqrt3 = math.sqrt(3);

  /// The smallest floating-point value x such that (1 + x != 1).
  static const double dblEpsilon = 2.220446049250313E-16;

  /// Maximum rounding error for arithmetic operations.
  static const double dblError = dblEpsilon / 2;

  // Cell orientation flags
  static const int swapMask = 0x01;
  static const int invertMask = 0x02;

  /// Mapping Hilbert traversal order to orientation adjustment mask.
  static const List<int> _posToOrientation = [
    swapMask,
    0,
    0,
    invertMask + swapMask
  ];

  /// Mapping from cell orientation + Hilbert traversal to IJ-index.
  static const List<List<int>> _posToIj = [
    [0, 1, 3, 2], // canonical order
    [0, 2, 3, 1], // axes swapped
    [3, 2, 0, 1], // bits inverted
    [3, 1, 0, 2], // swapped & inverted
  ];

  /// Mapping from Hilbert traversal order + cell orientation to IJ-index.
  static const List<List<int>> _ijToPos = [
    [0, 1, 3, 2], // canonical order
    [0, 3, 1, 2], // axes swapped
    [2, 3, 1, 0], // bits inverted
    [2, 1, 3, 0], // swapped & inverted
  ];

  /// Returns an XOR bit mask indicating how the orientation of a child subcell
  /// is related to the orientation of its parent cell.
  static int posToOrientation(int position) {
    assert(position >= 0 && position < 4);
    return _posToOrientation[position];
  }

  /// Return the IJ-index of the subcell at the given position in the Hilbert
  /// curve traversal with the given orientation.
  static int posToIJ(int orientation, int position) {
    return _posToIj[orientation][position];
  }

  /// Returns the order in which a specified subcell is visited by the Hilbert
  /// curve.
  static int ijToPos(int orientation, int ijIndex) {
    return _ijToPos[orientation][ijIndex];
  }

  /// Return true if the given point is approximately unit length.
  static bool isUnitLength(S2Point p) {
    return (p.norm2 - 1).abs() <= 5 * dblEpsilon;
  }

  /// A unique "origin" point on the sphere for operations that need a fixed
  /// reference point.
  static final S2Point origin = S2Point(
    -0.0099994664350250197,
    0.0025924542609324121,
    0.99994664350250195,
  );

  static const List<S2Point> _orthoBases = [
    S2Point(1, 0.0053, 0.00457),
    S2Point(0.012, 1, 0.00457),
    S2Point(0.012, 0.0053, 1),
  ];

  /// Returns a unit-length vector that is orthogonal to [a].
  static S2Point ortho(S2Point a) {
    int k = a.largestAbsComponent - 1;
    if (k < 0) k = 2;
    return a.crossProd(_orthoBases[k]).normalize();
  }

  /// Return true if two points are within the given distance in radians.
  static bool approxEquals(S2Point a, S2Point b, [double maxErrorRadians = 1e-15]) {
    return a.angle(b) <= maxErrorRadians;
  }

  /// Return true if two doubles are within the given tolerance.
  static bool approxEqualsDouble(double a, double b, [double maxError = 1e-15]) {
    return (a - b).abs() <= maxError;
  }

  /// 1/Pi - inverse of pi.
  static const double m1Pi = 1.0 / math.pi;

  /// Returns the area of the planar triangle ABC.
  /// This is the magnitude of the cross product divided by 2.
  static double area(S2Point a, S2Point b, S2Point c) {
    // Returns the area of the planar triangle. Not to be confused with
    // signedArea which computes the signed (spherical) area.
    final ac = a - c;
    final bc = b - c;
    return 0.5 * ac.crossProd(bc).norm;
  }

  /// Returns the signed area of triangle ABC on the unit sphere.
  /// The sign is positive if the vertices are arranged counterclockwise.
  static double signedArea(S2Point a, S2Point b, S2Point c) {
    // This is based on the formula:
    // signed_area = 2 * atan2(a · (b × c), |a||b||c| + (a·b)|c| + (b·c)|a| + (c·a)|b|)
    final aCrossB = a.crossProd(b);
    return 2 * math.atan2(c.dotProd(aCrossB),
        1 + a.dotProd(b) + b.dotProd(c) + c.dotProd(a));
  }

  // Private constructor - this is a utility class
  S2._();
}

