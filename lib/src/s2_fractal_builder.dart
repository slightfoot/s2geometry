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

import 'matrix.dart';
import 'r2_vector.dart';
import 's1_angle.dart';
import 's2.dart';
import 's2_point.dart';

/// A simple class that generates "Koch snowflake" fractals.
///
/// There is an option to control the fractal dimension (between 1.0 and 2.0);
/// values between 1.02 and 1.50 are reasonable simulations of various coastlines.
/// The default dimension (about 1.26) corresponds to the standard Koch snowflake.
/// (The west coast of Britain has a fractal dimension of approximately 1.25)
///
/// The fractal is obtained by starting with an equilateral triangle and
/// recursively subdividing each edge into four segments of equal length.
/// Therefore the shape at level 'n' consists of 3 * (4^n) edges.
///
/// Multi-level fractals are also supported: if you set minLevel to a non-negative
/// value, then the recursive subdivision has an equal probability of stopping
/// at any of the levels between the given min and max (inclusive).
class S2FractalBuilder {
  int _maxLevel = -1;

  /// Value set by user.
  int _minLevelArg = -1;

  /// Actual min level (depends on maxLevel).
  int _minLevel = -1;

  /// Standard Koch curve dimension: log(4) / log(3).
  double _dimension = math.log(4) / math.log(3);

  /// The ratio of the sub-edge length to the original edge length at each
  /// subdivision step.
  double _edgeFraction = 0;

  /// The distance from the original edge to the middle vertex at each
  /// subdivision step, as a fraction of the original edge length.
  double _offsetFraction = 0;

  final math.Random _rand;

  /// You must call [setMaxLevel] or [setLevelForApproxMaxEdges] before
  /// calling [makeVertices].
  S2FractalBuilder(this._rand) {
    _computeOffsets();
  }

  /// Sets the maximum subdivision level for the fractal.
  void setMaxLevel(int maxLevel) {
    if (maxLevel < 0) {
      throw ArgumentError('maxLevel must be >= 0');
    }
    _maxLevel = maxLevel;
    _computeMinLevel();
  }

  /// Sets the minimum subdivision level for the fractal.
  ///
  /// The default value of -1 causes the min and max levels to be the same.
  /// A minLevel of 0 should be avoided since this creates a significant chance
  /// that none of the three original edges will be subdivided at all.
  void setMinLevel(int minLevelArg) {
    if (minLevelArg < -1) {
      throw ArgumentError('minLevel must be >= -1');
    }
    _minLevelArg = minLevelArg;
    _computeMinLevel();
  }

  void _computeMinLevel() {
    if (_minLevelArg >= 0 && _minLevelArg <= _maxLevel) {
      _minLevel = _minLevelArg;
    } else {
      _minLevel = _maxLevel;
    }
  }

  /// Sets the fractal dimension.
  ///
  /// The default value of approximately 1.26 corresponds to the standard Koch
  /// curve. The value must lie in the range [1.0, 2.0].
  void setFractalDimension(double dimension) {
    if (dimension < 1.0 || dimension > 2.0) {
      throw ArgumentError('dimension must be in range [1.0, 2.0]');
    }
    _dimension = dimension;
    _computeOffsets();
  }

  void _computeOffsets() {
    _edgeFraction = math.pow(4.0, -1.0 / _dimension).toDouble();
    _offsetFraction = math.sqrt(_edgeFraction - 0.25);
  }

  /// Sets the min level to produce approximately the given number of edges.
  void setLevelForApproxMinEdges(int minEdges) {
    setMinLevel(_levelFromEdges(minEdges));
  }

  /// Sets the max level to produce approximately the given number of edges.
  void setLevelForApproxMaxEdges(int maxEdges) {
    setMaxLevel(_levelFromEdges(maxEdges));
  }

  /// Returns level from values in the range [1.5 * (4 ^ n), 6 * (4 ^ n)].
  static int _levelFromEdges(int edges) {
    return (0.5 * math.log(edges / 3.0) / math.log(2)).ceil();
  }

  /// Returns a lower bound on the ratio (Rmin / R), where 'R' is the radius
  /// passed to [makeVertices], and 'Rmin' is the minimum distance from the
  /// fractal boundary to its center.
  double minRadiusFactor() {
    // The minimum radius is attained at one of the vertices created by the
    // first subdivision step as long as the dimension is not too small.
    const kMinDimensionForMinRadiusAtLevel1 = 1.0852230903040407;
    if (_dimension >= kMinDimensionForMinRadiusAtLevel1) {
      return math.sqrt(1 + 3 * _edgeFraction * (_edgeFraction - 1));
    }
    return 0.5;
  }

  /// Returns the ratio (Rmax / R), where 'R' is the radius passed to
  /// [makeVertices] and 'Rmax' is the maximum distance from the fractal
  /// boundary to its center.
  double maxRadiusFactor() {
    return math.max(1.0, _offsetFraction * math.sqrt(3) + 0.5);
  }

  void _getR2Vertices(List<R2Vector> vertices) {
    // The Koch "snowflake" consists of three Koch curves whose initial edges
    // form an equilateral triangle.
    final v0 = R2Vector(1.0, 0.0);
    final v1 = R2Vector(-0.5, math.sqrt(3) / 2);
    final v2 = R2Vector(-0.5, -math.sqrt(3) / 2);
    _getR2VerticesHelper(v0, v1, 0, vertices);
    _getR2VerticesHelper(v1, v2, 0, vertices);
    _getR2VerticesHelper(v2, v0, 0, vertices);
  }

  /// Given the two endpoints (v0, v4) of an edge, recursively subdivide the
  /// edge to the desired level, and insert all vertices of the resulting curve
  /// up to but not including the endpoint "v4".
  void _getR2VerticesHelper(
      R2Vector v0, R2Vector v4, int level, List<R2Vector> vertices) {
    // The second expression should return 'true' once every
    // (maxLevel - level + 1) calls.
    if (level >= _minLevel && (_rand.nextInt(_maxLevel - level + 1) == 0)) {
      // Stop subdivision at this level.
      vertices.add(v0);
      return;
    }
    // Otherwise compute the intermediate vertices v1, v2, and v3.
    final dir = v4 - v0;
    // v1 = v0 + edgeFraction * dir
    final v1 = v0 + dir * _edgeFraction;
    // v2 = 0.5 * (v0 + v4) - offsetFraction * dir.ortho()
    final v2 = (v0 + v4) * 0.5 - dir.ortho() * _offsetFraction;
    // v3 = v4 - edgeFraction * dir
    final v3 = v4 - dir * _edgeFraction;

    // And recurse on the four sub-edges.
    _getR2VerticesHelper(v0, v1, level + 1, vertices);
    _getR2VerticesHelper(v1, v2, level + 1, vertices);
    _getR2VerticesHelper(v2, v3, level + 1, vertices);
    _getR2VerticesHelper(v3, v4, level + 1, vertices);
  }

  /// Returns the vertices for a fractal loop centered around the z-axis of the
  /// given coordinate frame, with the first vertex in the direction of the
  /// positive x-axis, and the given nominal radius.
  List<S2Point> makeVertices(Matrix frame, S1Angle nominalRadius) {
    final r2Vertices = <R2Vector>[];
    _getR2Vertices(r2Vertices);
    final vertices = <S2Point>[];
    for (var i = 0; i < r2Vertices.length; ++i) {
      // Convert each vertex to polar coordinates.
      final v = r2Vertices[i];
      final theta = math.atan2(v.y, v.x);
      final radius = nominalRadius.radians * v.norm;

      // We construct the loop in the given frame coordinates, with the center
      // at (0, 0, 1). For a loop of radius 'r', the loop vertices have the form
      // (x, y, z) where x^2 + y^2 = sin(r) and z = cos(r). The distance on the
      // sphere (arc length) from each vertex to the center is acos(cos(r)) = r.
      final z = math.cos(radius);
      final r = math.sin(radius);
      final p = S2Point(r * math.cos(theta), r * math.sin(theta), z);
      vertices.add(S2.rotate(p, frame));
    }
    return vertices;
  }
}

