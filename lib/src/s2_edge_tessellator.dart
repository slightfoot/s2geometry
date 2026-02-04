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

import 's1_angle.dart';
import 's1_chord_angle.dart';
import 's2_edge_util.dart';
import 's2_point.dart';
import 'r2_vector.dart';
import 'projection.dart';

/// Given an edge in some 2D projection (e.g., Mercator), S2EdgeTessellator
/// converts the edge into a chain of spherical geodesic edges such that the
/// maximum distance between the original edge and the geodesic edge chain is
/// at most "tolerance". Similarly, it can convert a spherical geodesic edge
/// into a chain of edges in a given 2D projection such that the maximum
/// distance between the geodesic edge and the chain of projected edges is at
/// most "tolerance".
///
/// Tessellation is implemented by subdividing the edge until the estimated
/// maximum error is below the given tolerance.
class S2EdgeTessellator {
  /// The interpolation fraction at which the two edges are evaluated in order
  /// to measure the error between them.
  static const double _interpolationFraction = 0.31215691082248315;

  /// The following is the value of E1(x0) == E2(x0).
  static const double _scaleFactor = 0.8382999256988851;

  /// Returns the minimum supported tolerance (which corresponds to a distance
  /// less than one micrometer on the Earth's surface).
  static final S1Angle minTolerance = S1Angle.radians(1e-13);

  final Projection _projection;
  final S1ChordAngle _scaledTolerance;

  /// Constructs an S2EdgeTessellator using the given projection and error
  /// tolerance.
  S2EdgeTessellator(this._projection, S1Angle tolerance)
      : _scaledTolerance = S1ChordAngle.fromS1Angle(
            S1Angle.max(minTolerance, tolerance) * _scaleFactor);

  /// Converts the spherical geodesic edge AB to a chain of planar edges in
  /// the given projection and appends the corresponding vertices to [vertices].
  ///
  /// This method can be called multiple times with the same output list to
  /// convert an entire polyline or loop. All vertices of the first edge are
  /// appended, but the first vertex of each subsequent edge is omitted (and
  /// must match the last vertex of the previous edge).
  void appendProjected(S2Point a, S2Point b, List<R2Vector> vertices) {
    R2Vector pa = _projection.project(a);
    if (vertices.isEmpty) {
      vertices.add(pa);
    } else {
      pa = _projection.wrapDestination(vertices.last, pa);
      assert(vertices.last == pa, 'Appended edges must form a chain');
    }
    R2Vector pb = _projection.project(b);
    _appendProjectedHelper(pa, a, pb, b, vertices);
  }

  /// Converts the planar edge AB in the given projection to a chain of
  /// spherical geodesic edges and appends the vertices to [vertices].
  ///
  /// This method can be called multiple times with the same output list to
  /// convert an entire polyline or loop. All vertices of the first edge are
  /// appended, but the first vertex of each subsequent edge is omitted (and
  /// is required to match that last vertex of the previous edge).
  void appendUnprojected(R2Vector pa, R2Vector pb, List<S2Point> vertices) {
    S2Point a = _projection.unproject(pa);
    S2Point b = _projection.unproject(pb);
    if (vertices.isEmpty) {
      vertices.add(a);
    } else {
      // Note that coordinate wrapping can create a small amount of error.
      assert(_approxEquals(vertices.last, a), 'Appended edges must form a chain');
    }
    _appendUnprojectedHelper(pa, a, pb, b, vertices);
  }

  /// Helper for appendProjected.
  void _appendProjectedHelper(
      R2Vector pa, S2Point a, R2Vector pbIn, S2Point b, List<R2Vector> vertices) {
    R2Vector pb = _projection.wrapDestination(pa, pbIn);
    if (_estimateMaxError(pa, a, pb, b).lessOrEquals(_scaledTolerance)) {
      vertices.add(pb);
    } else {
      S2Point mid = (a + b).normalize();
      R2Vector projectedMid =
          _projection.wrapDestination(pa, _projection.project(mid));
      _appendProjectedHelper(pa, a, projectedMid, mid, vertices);
      _appendProjectedHelper(projectedMid, mid, pb, b, vertices);
    }
  }

  /// Helper for appendUnprojected.
  void _appendUnprojectedHelper(
      R2Vector pa, S2Point a, R2Vector pbIn, S2Point b, List<S2Point> vertices) {
    R2Vector pb = _projection.wrapDestination(pa, pbIn);
    if (_estimateMaxError(pa, a, pb, b).lessOrEquals(_scaledTolerance)) {
      vertices.add(b);
    } else {
      R2Vector projectedMid = Projection.interpolate(0.5, pa, pb);
      S2Point mid = _projection.unproject(projectedMid);
      _appendUnprojectedHelper(pa, a, projectedMid, mid, vertices);
      _appendUnprojectedHelper(projectedMid, mid, pb, b, vertices);
    }
  }

  /// Estimates the maximum error between the geodesic and projected edges.
  S1ChordAngle _estimateMaxError(R2Vector pa, S2Point a, R2Vector pb, S2Point b) {
    if (a.dotProd(b) < -1e-14) {
      return S1ChordAngle.infinity;
    }

    final double t1 = _interpolationFraction;
    final double t2 = 1 - _interpolationFraction;
    final S2Point mid1 = S2EdgeUtil.interpolate(a, b, t1);
    final S2Point mid2 = S2EdgeUtil.interpolate(a, b, t2);
    S2Point projectedMid1 =
        _projection.unproject(Projection.interpolate(t1, pa, pb));
    S2Point projectedMid2 =
        _projection.unproject(Projection.interpolate(t2, pa, pb));
    S1ChordAngle mid1Angle = S1ChordAngle(mid1, projectedMid1);
    S1ChordAngle mid2Angle = S1ChordAngle(mid2, projectedMid2);
    return S1ChordAngle.max(mid1Angle, mid2Angle);
  }

  /// Approximate equality check for S2Points.
  bool _approxEquals(S2Point a, S2Point b) {
    return S1ChordAngle(a, b).radians < 1e-14;
  }
}

