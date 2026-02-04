// Copyright 2006 Google Inc.
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

import 's1_angle.dart';
import 's1_chord_angle.dart';
import 's2.dart';
import 's2_point.dart';
import 's2_predicates.dart';
import 's2_robust_cross_prod.dart';

/// This class contains various utility functions related to edges. It collects
/// together common code that is needed to implement polygonal geometry such as
/// polylines, loops, and general polygons.
class S2EdgeUtil {
  S2EdgeUtil._();

  /// IEEE floating-point operations have a maximum error of 0.5 ULPS.
  static final S1Angle defaultIntersectionTolerance =
      const S1Angle.radians(12 * S2.dblEpsilon / 2 / 0.866);

  /// The maximum angle between a returned vertex and the nearest point on
  /// the exact edge AB.
  static const double faceClipErrorRadians = 3 * S2.dblEpsilon;

  /// The same angle as faceClipErrorRadians, expressed as a maximum distance
  /// in (u,v)-space.
  static const double faceClipErrorUvDist = 9 * S2.dblEpsilon;

  /// Error in IntersectRect.
  static final double intersectsRectErrorUvDist =
      3 * S2.M_SQRT2 * S2.dblEpsilon;

  /// Error in a clipped point's u- or v-coordinate.
  static const double edgeClipErrorUvCoord = 2.25 * S2.dblEpsilon;

  /// Error in clipped edge.
  static const double edgeClipErrorUvDist = 2.25 * S2.dblEpsilon;

  /// Upper bound on distance from intersection point to true intersection.
  static const double intersectionError = 8 * S2.dblEpsilon;

  /// Error bound for getPointOnLine.
  static final S1Angle getPointOnLineError = S1Angle.radians(
          (4 + (2 / S2.M_SQRT3)) * S2.dblError)
      .add(S2.robustCrossProdError);

  /// Upper bound on distance from point returned by project to the edge AB.
  static final S1Angle projectPerpendicularError = S1Angle.radians(
          (2 + (2 / S2.M_SQRT3)) * S2.dblError)
      .add(S2.robustCrossProdError);

  /// Upper bound on distance from point returned by getPointOnRay to the ray.
  static final S1Angle getPointOnRayPerpendicularError =
      const S1Angle.radians(3 * S2.dblError);

  /// Snap radius for merging edges displaced by intersection error.
  static final S1Angle intersectionMergeRadius =
      const S1Angle.radians(2 * intersectionError);

  /// This is a helper function that does two things. First, it allows the
  /// function template below to compile (the Abs() function normally has
  /// only one argument). Second, it returns the absolute value of the
  /// difference between "a" and "b" when T is a floating-point type
  /// (including double).
  static int robustCrossing(S2Point a0, S2Point a1, S2Point b0, S2Point b1) {
    final crosser = EdgeCrosser.withEdge(a0, a1);
    return crosser.robustCrossing(b0, b1);
  }

  /// Returns true if edge AB crosses edge CD at a point that is interior to
  /// both edges. Properties:
  ///  - The result is symmetric for both edge orderings
  ///  - The result is deterministic
  static bool edgesCross(S2Point a0, S2Point a1, S2Point b0, S2Point b1) {
    return robustCrossing(a0, a1, b0, b1) > 0;
  }

  /// Returns the distance from point X to the edge AB. All arguments should
  /// be unit length.
  static S1Angle getDistance(S2Point x, S2Point a, S2Point b) {
    return S1Angle.radians(
        getDistanceRadians(x, a, b, S2RobustCrossProd.robustCrossProd(a, b)));
  }

  /// A more efficient version of getDistance() where the cross product of
  /// the endpoints has been precomputed.
  static double getDistanceRadians(
      S2Point x, S2Point a, S2Point b, S2Point aCrossB) {
    // There are three cases. If X is located in the spherical wedge defined
    // by A, B, and the axis A x B, then the closest point is on the segment
    // AB. Otherwise the closest point is either A or B.
    if (S2Point.scalarTripleProduct(a, x, aCrossB) > 0 &&
        S2Point.scalarTripleProduct(b, aCrossB, x) > 0) {
      // The closest point to X lies on the segment AB.
      final sinDist = (x.dotProd(aCrossB) / aCrossB.norm).abs();
      return math.asin(math.min(1.0, sinDist));
    }
    // Otherwise, the closest point is either A or B.
    final linearDist2 = math.min(_distance2(x, a), _distance2(x, b));
    return 2 * math.asin(math.min(1.0, 0.5 * math.sqrt(linearDist2)));
  }

  /// Returns the squared distance from a to b.
  static double _distance2(S2Point a, S2Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return dx * dx + dy * dy + dz * dz;
  }

  /// Returns the point along the edge AB that is closest to the point X.
  static S2Point project(S2Point x, S2Point a, S2Point b) {
    return projectWithCrossProd(x, a, b, S2RobustCrossProd.robustCrossProd(a, b));
  }

  /// Returns the point along the edge AB that is closest to the point X.
  /// This version is slightly more efficient if the cross product of the
  /// two endpoints has been precomputed.
  static S2Point projectWithCrossProd(
      S2Point x, S2Point a, S2Point b, S2Point aCrossB) {
    assert(S2.isUnitLength(a));
    assert(S2.isUnitLength(b));
    assert(S2.isUnitLength(x));

    // Handle case where x equals a or b.
    if (x == a || x == b) {
      return x;
    }

    // Find the closest point to X along the great circle through AB.
    final n = aCrossB.normalize();
    final p = S2RobustCrossProd.robustCrossProd(n, x).crossProd(n).normalize();

    // If this point is on the edge AB, then it's the closest point.
    final pn = p.crossProd(n);
    if (S2Predicates.signWithCrossProd(p, n, a, pn) > 0 &&
        S2Predicates.signWithCrossProd(p, n, b, pn) < 0) {
      return p;
    }

    // Otherwise, the closest point is either A or B.
    return (x.getDistance2(a) <= x.getDistance2(b)) ? a : b;
  }

  /// Returns the normalized point at distance "r" from A along the line AB.
  static S2Point getPointOnLine(S2Point a, S2Point b, S1Angle r) {
    final dir = S2RobustCrossProd.robustCrossProd(a, b).crossProd(a).normalize();
    return getPointOnRay(a, dir, r);
  }

  /// Returns the normalized point at distance "r" from A along the line AB.
  /// Slightly faster than the variant taking an S1Angle.
  static S2Point getPointOnLineChord(S2Point a, S2Point b, S1ChordAngle r) {
    final dir = S2RobustCrossProd.robustCrossProd(a, b).crossProd(a).normalize();
    return getPointOnRayChord(a, dir, r);
  }

  /// Returns the normalized point at distance "r" along the ray with the
  /// given origin and direction.
  static S2Point getPointOnRay(S2Point origin, S2Point dir, S1Angle r) {
    assert(S2.isUnitLength(origin));
    assert(S2.isUnitLength(dir));
    return origin.mul(math.cos(r.radians)).add(dir.mul(math.sin(r.radians))).normalize();
  }

  /// Returns the normalized point at distance "r" along the ray with the
  /// given origin and direction. This version is faster.
  static S2Point getPointOnRayChord(
      S2Point origin, S2Point dir, S1ChordAngle r) {
    assert(S2.isUnitLength(origin));
    assert(S2.isUnitLength(dir));
    return origin
        .mul(S1ChordAngle.cos(r))
        .add(dir.mul(S1ChordAngle.sin(r)))
        .normalize();
  }

  /// Return the normalized point X along the line segment AB whose distance
  /// from A is the given fraction "t" of the distance AB.
  static S2Point interpolate(S2Point a, S2Point b, double t) {
    if (t == 0) return a;
    if (t == 1) return b;
    final ab = S1Angle.fromPoints(a, b);
    return getPointOnLine(a, b, S1Angle.radians(t * ab.radians));
  }

  /// Given three points, returns true if the edges OA, OB, and OC are
  /// encountered in that order while sweeping CCW around the point O. You can
  /// think of this as testing whether A <= B <= C with respect to a continuous
  /// CCW ordering around O.
  static bool orderedCCW(S2Point o, S2Point a, S2Point b, S2Point c) {
    return S2Predicates.orderedCCW(a, b, c, o);
  }

  /// Returns true if there is a crossing between the edges AB and CD,
  /// allowing for vertex crossings.
  static bool edgeOrVertexCrossing(
      S2Point a, S2Point b, S2Point c, S2Point d) {
    final crosser = EdgeCrosser.withEdge(a, b);
    return crosser.edgeOrVertexCrossing(c, d);
  }

  /// Returns true if AB intersects CD at a vertex, handling the case where
  /// vertices coincide.
  static bool vertexCrossing(S2Point a, S2Point b, S2Point c, S2Point d) {
    // If A == C or A == D, we check whether B and the other point are on
    // opposite sides of A. If A == B or C == D (degenerate edge) we return
    // false. Note that we need to be careful about collinear edges.
    if (a == c) return (a != b) && (c != d) && S2Predicates.orderedCCW(b, d, a, S2RobustCrossProd.robustCrossProd(b, d).normalize());
    if (a == d) return (a != b) && (c != d) && S2Predicates.orderedCCW(b, c, a, S2RobustCrossProd.robustCrossProd(b, c).normalize());
    if (b == c) return (a != b) && (c != d) && S2Predicates.orderedCCW(a, d, b, S2RobustCrossProd.robustCrossProd(a, d).normalize());
    if (b == d) return (a != b) && (c != d) && S2Predicates.orderedCCW(a, c, b, S2RobustCrossProd.robustCrossProd(a, c).normalize());
    return false;
  }
}

/// Used to efficiently test a fixed edge AB against an edge chain.
/// To use it, initialize with the edge AB, and call robustCrossing() or
/// edgeOrVertexCrossing() with each edge of the chain.
///
/// This class is NOT thread-safe.
class EdgeCrosser {
  late S2Point _a;
  late S2Point _b;
  late S2Point _aCrossB;

  /// Previous vertex in the vertex chain.
  S2Point? _c;

  /// The orientation of the triangle ACB.
  int _acb = 0;

  /// The orientation of triangle BDA.
  int _bdaReturn = 0;

  /// True if the tangents have been computed.
  bool _haveTangents = false;

  /// Outward-facing tangent at A.
  late S2Point _aTangent;

  /// Outward-facing tangent at B.
  late S2Point _bTangent;

  /// Constructs an uninitialized edge crosser.
  EdgeCrosser();

  /// Convenience constructor that calls init() with the given fixed edge AB.
  EdgeCrosser.withEdge(S2Point a, S2Point b) {
    init(a, b);
  }

  /// Constructor with edge and first chain vertex.
  EdgeCrosser.withEdgeAndVertex(S2Point a, S2Point b, S2Point c) {
    init(a, b);
    restartAt(c);
  }

  /// Initialize this edge crosser with the given endpoints.
  void init(S2Point a, S2Point b) {
    assert(S2.skipAssertions || S2.isUnitLength(a));
    assert(S2.skipAssertions || S2.isUnitLength(b));
    _a = a;
    _b = b;
    _c = null;
    _aCrossB = a.crossProd(b);
    _haveTangents = false;
  }

  /// Returns the first point passed to init.
  S2Point get a => _a;

  /// Returns the second point passed to init.
  S2Point get b => _b;

  /// Returns the last 'c' point checked.
  S2Point? get c => _c;

  /// Returns the approximate normal of the AB edge.
  S2Point get normal => _aCrossB;

  /// Call this method when your chain 'jumps' to a new place.
  void restartAt(S2Point c) {
    assert(S2.skipAssertions || S2.isUnitLength(c));
    _c = c;
    _acb = -Sign.triageWithCrossProd(_aCrossB, c);
  }

  /// Returns +1 if there is a crossing, -1 if there is no crossing, and 0
  /// if two points from different edges are the same.
  int robustCrossingFromD(S2Point d) {
    assert(S2.skipAssertions || S2.isUnitLength(d));
    final bda = Sign.triageWithCrossProd(_aCrossB, d);
    if (_acb == -bda && bda != 0) {
      _c = d;
      _acb = -bda;
      return -1;
    }
    _bdaReturn = bda;
    return _robustCrossingInternal(d);
  }

  /// As robustCrossingFromD, but restarts at c if that is not the previous
  /// endpoint.
  int robustCrossing(S2Point c, S2Point d) {
    if (!identical(_c, c)) {
      restartAt(c);
    }
    return robustCrossingFromD(d);
  }

  /// Returns true if AB crosses CD, either within the edge or by a vertex
  /// crossing at a shared vertex.
  bool edgeOrVertexCrossingFromD(S2Point d) {
    final c2 = _c;
    final crossing = robustCrossingFromD(d);
    if (crossing < 0) return false;
    if (crossing > 0) return true;
    return c2 != null && S2EdgeUtil.vertexCrossing(_a, _b, c2, d);
  }

  /// Returns true if AB crosses CD, either within the edge or by a vertex
  /// crossing at a shared vertex. Restarts at c if that is not the previous
  /// endpoint.
  bool edgeOrVertexCrossing(S2Point c, S2Point d) {
    if (!identical(_c, c)) {
      restartAt(c);
    }
    return edgeOrVertexCrossingFromD(d);
  }

  int _robustCrossingInternal(S2Point d) {
    final result = _robustCrossingInternal2(d);
    _c = d;
    _acb = -_bdaReturn;
    return result;
  }

  int _robustCrossingInternal2(S2Point d) {
    // At this point it is still very likely that CD does not cross AB.
    if (!_haveTangents) {
      final norm = S2RobustCrossProd.robustCrossProd(_a, _b).normalize();
      _aTangent = _a.crossProd(norm);
      _bTangent = norm.crossProd(_b);
      _haveTangents = true;
    }

    final kError = (1.5 + 1 / math.sqrt(3)) * S2.dblEpsilon;
    final c = _c!;
    if ((c.dotProd(_aTangent) > kError && d.dotProd(_aTangent) > kError) ||
        (c.dotProd(_bTangent) > kError && d.dotProd(_bTangent) > kError)) {
      return -1;
    }

    // Eliminate cases where two vertices from different edges are equal.
    if (_a == c || _a == d || _b == c || _b == d) {
      return 0;
    }

    // Eliminate cases where an input edge is degenerate.
    if (_a == _b || c == d) {
      return -1;
    }

    // Otherwise it's time to break out the big guns.
    if (_acb == 0) {
      _acb = -Sign.expensive(_a, _b, c, true);
      assert(_acb != 0);
    }
    if (_bdaReturn == 0) {
      _bdaReturn = Sign.expensive(_a, _b, d, true);
      assert(_bdaReturn != 0);
    }
    if (_bdaReturn != _acb) {
      return -1;
    }

    final cCrossD = c.crossProd(d);
    final cbd = -_sign(c, d, _b, cCrossD);
    assert(cbd != 0);
    if (cbd != _acb) {
      return -1;
    }

    final dac = _sign(c, d, _a, cCrossD);
    assert(dac != 0);
    return (dac == _acb) ? 1 : -1;
  }

  static int _sign(S2Point a, S2Point b, S2Point c, S2Point aCrossB) {
    int ccw = Sign.triageWithCrossProd(aCrossB, c);
    if (ccw == 0) {
      ccw = Sign.expensive(a, b, c, true);
    }
    return ccw;
  }
}
