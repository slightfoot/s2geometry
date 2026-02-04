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

import 'r1_interval.dart';
import 's1_angle.dart';
import 's1_chord_angle.dart';
import 's1_interval.dart';
import 's2.dart';
import 's2_latlng.dart';
import 's2_latlng_rect.dart';
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

  /// If the distance from X to the edge AB is less than "minDist", this
  /// method updates "minDist" and returns the new value. Otherwise "minDist"
  /// is unchanged and the same reference is returned. The "minDist" argument
  /// must be non-negative.
  ///
  /// This method is faster than getDistance() when used with an S1ChordAngle
  /// because it can avoid computing the actual distance in many cases.
  static S1ChordAngle updateMinDistance(
      S2Point x, S2Point a, S2Point b, S1ChordAngle minDist) {
    // Compute the chord angle from x to the edge AB.
    final dist = S1ChordAngle.fromS1Angle(getDistance(x, a, b));
    if (dist.compareTo(minDist) < 0) {
      return dist;
    }
    return minDist;
  }

  /// Returns the maximum error in the result of updateMinDistance,
  /// assuming that all input points are normalized to within the bounds
  /// guaranteed by S2Point.normalize().
  static double getUpdateMinDistanceMaxError(S1ChordAngle dist) {
    // There are two cases for the maximum error, depending on whether the
    // closest point is interior to the edge.
    return math.max(
        _getUpdateMinInteriorDistanceMaxError(dist), dist.s2PointConstructorMaxError);
  }

  /// Returns the maximum error in the result of updateMinInteriorDistance,
  /// assuming that all input points are normalized.
  static double _getUpdateMinInteriorDistanceMaxError(S1ChordAngle distance) {
    // If a point is more than 90 degrees from an edge, then the minimum
    // distance is always to one of the endpoints, not to the edge interior.
    if (distance.compareTo(S1ChordAngle.right) >= 0) {
      return 0.0;
    }

    // This bound includes all sources of error.
    final b = math.min(1.0, 0.5 * distance.length2);
    final aVal = math.sqrt(b * (2 - b));
    return ((2.5 + 2 * S2.M_SQRT3 + 8.5 * aVal) * aVal +
            (2 + 2 * S2.M_SQRT3 / 3 + 6.5 * (1 - b)) * b +
            (23 + 16 / S2.M_SQRT3) * S2.dblEpsilon) *
        S2.dblEpsilon;
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

  /// Interpolates a value along a linear mapping.
  ///
  /// Given a value [x] in the range [a, b], interpolates the corresponding
  /// value in the range [a1, b1]. For accuracy near both endpoints, the
  /// interpolation is performed from whichever endpoint is closer to x.
  ///
  /// Requires: a != b
  static double interpolateDouble(
      double x, double a, double b, double a1, double b1) {
    assert(a != b);
    // To get results that are accurate near both A and B, we interpolate
    // starting from the closer of the two points.
    if ((a - x).abs() <= (b - x).abs()) {
      return a1 + (b1 - a1) * ((x - a) / (b - a));
    } else {
      return b1 + (a1 - b1) * ((x - b) / (a - b));
    }
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

  /// This class computes a bounding rectangle that contains all edges defined
  /// by a vertex chain v0, v1, v2, ... All vertices must be unit length.
  /// Note that the bounding rectangle of an edge can be larger than the
  /// bounding rectangle of its endpoints, e.g. consider an edge that passes
  /// through the north pole.
  static RectBounder rectBounder() => RectBounder();
}

/// Computes a bounding rectangle for a vertex chain.
class RectBounder {
  S2LatLngRect _bound = S2LatLngRect.empty();
  S2Point? _a;
  S2LatLng? _aLatLng;

  RectBounder();

  /// The accumulated bound.
  S2LatLngRect get bound => _bound;

  /// Add a vertex to the chain.
  void addPoint(S2Point b) {
    final bLatLng = S2LatLng.fromPoint(b);
    if (_bound.isEmpty) {
      _bound = S2LatLngRect.fromPoint(bLatLng);
    } else {
      _addInternal(b, bLatLng);
    }
    _a = b;
    _aLatLng = bLatLng;
  }

  void _addInternal(S2Point b, S2LatLng bLatLng) {
    final a = _a!;
    final aLatLng = _aLatLng!;

    // N = 2 * (A x B)
    final n = a.sub(b).crossProd(a.add(b));
    double nNorm = n.norm;

    if (nNorm < 1.91346e-15) {
      // A and B are nearly identical or nearly antipodal
      if (a.dotProd(b) < 0) {
        _bound = S2LatLngRect.full();
      } else {
        _bound = _bound.union(S2LatLngRect.fromPointPair(aLatLng, bLatLng));
      }
      return;
    }

    // Compute longitude range
    final lngAB = S1Interval.fromPointPair(
        aLatLng.lng.radians, bLatLng.lng.radians);
    S1Interval lng = lngAB;
    if (lngAB.length >= math.pi - 2 * S2.dblEpsilon) {
      lng = S1Interval.full();
    }

    // Compute latitude range
    R1Interval latAB = R1Interval(
        math.min(aLatLng.lat.radians, bLatLng.lat.radians),
        math.max(aLatLng.lat.radians, bLatLng.lat.radians));

    // Check if edge crosses plane through N and Z-axis
    final m = n.crossProd(S2Point.zPos);
    double mDotA = m.dotProd(a);
    double mDotB = m.dotProd(b);
    double mError = 6.06638e-16 * nNorm + 6.83174e-31;

    if (mDotA * mDotB < 0 || mDotA.abs() <= mError || mDotB.abs() <= mError) {
      // Minimum/maximum latitude may occur in edge interior
      double maxLat = math.min(
          S2.piOver2,
          3 * S2.dblEpsilon +
              math.atan2(math.sqrt(n.x * n.x + n.y * n.y), n.z.abs()));

      double latBudget = 2 * math.asin(0.5 * a.sub(b).norm * math.sin(maxLat));
      double maxDelta = 0.5 * (latBudget - latAB.length) + S2.dblEpsilon;

      if (mDotA <= mError && mDotB >= -mError) {
        latAB = R1Interval(latAB.lo, math.min(maxLat, latAB.hi + maxDelta));
      }
      if (mDotB <= mError && mDotA >= -mError) {
        latAB = R1Interval(math.max(-maxLat, latAB.lo - maxDelta), latAB.hi);
      }
    }

    _bound = _bound.union(S2LatLngRect(latAB, lng));
  }
}
