// Copyright 2021 Google Inc.
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
import 's2_edge_util.dart';
import 's2_point.dart';
import 's2_shape.dart';

/// S2ChainInterpolationQuery is a helper class for querying points along an
/// S2Shape's edges (chains of vertices) by spherical angular distances.
///
/// The distance, measured in radians, is computed by accumulating the lengths
/// of the edges of the shape, in the order the edges are stored by the S2Shape.
///
/// If a particular edge chain is specified at the query initialization, then
/// the distances are along that single chain. If no chain is specified, then
/// the interpolated points as a function of distance will have discontinuities
/// at chain boundaries.
///
/// Once the query object is initialized, the complexity of each subsequent
/// query is O(log(m)), where m is the number of edges. The complexity of the
/// constructor and the memory footprint are both O(m).
class S2ChainInterpolationQuery {
  /// The shape being interpolated.
  final S2Shape shape;

  /// Cumulative value 'n' is the total length of edges from the beginning of
  /// the first edge to the end of edge 'n', in radians.
  final List<S1Angle> _cumulativeValues = [];

  /// The first edge id of the chain being interpolated.
  final int _firstEdgeId;

  /// The last edge id of the chain being interpolated.
  final int _lastEdgeId;

  /// Result fields set by findPoint() or findPointAtFraction().
  S2Point? _resultPoint;
  int _resultEdgeId = 0;
  S1Angle? _resultDistance;

  /// Constructs an S2ChainInterpolationQuery for all edge chains of the shape.
  S2ChainInterpolationQuery(S2Shape shape) : this.forChain(shape, -1);

  /// Constructs an S2ChainInterpolationQuery for a specific chain of the shape.
  ///
  /// If a non-negative chainId is supplied, then only edges belonging to that
  /// chain are used. Otherwise edges from all chains are used.
  S2ChainInterpolationQuery.forChain(this.shape, int chainId)
      : _firstEdgeId = chainId >= 0 ? shape.getChainStart(chainId) : 0,
        _lastEdgeId = chainId >= 0
            ? shape.getChainStart(chainId) + shape.getChainLength(chainId) - 1
            : shape.numEdges - 1 {
    assert(chainId < shape.numChains);

    S1Angle cumulativeAngle = S1Angle.zero;
    final edge = MutableEdge();
    for (int i = _firstEdgeId; i <= _lastEdgeId; ++i) {
      _cumulativeValues.add(cumulativeAngle);
      shape.getEdge(i, edge);
      cumulativeAngle = cumulativeAngle.add(S1Angle.fromPoints(edge.a!, edge.b!));
    }
    if (_cumulativeValues.isNotEmpty) {
      _cumulativeValues.add(cumulativeAngle);
    }
  }

  /// Gets the maximum accumulated length from the first vertex to the end of
  /// the last edge. Returns zero for shapes with no edges.
  S1Angle getLength() {
    return _cumulativeValues.isEmpty ? S1Angle.zero : _cumulativeValues.last;
  }

  /// Returns the cumulative length up to the end of the given edge id.
  /// Returns S1Angle.infinity if the edge is outside the interpolated range.
  /// Returns S1Angle.zero if the query is empty.
  S1Angle getLengthAtEdgeEnd(int edgeId) {
    if (_cumulativeValues.isEmpty) {
      return S1Angle.zero;
    }
    if (edgeId < _firstEdgeId || edgeId > _lastEdgeId) {
      return S1Angle.infinity;
    }
    return _cumulativeValues[edgeId - _firstEdgeId + 1];
  }

  /// Returns a slice of the chain from fraction 'a' to fraction 'b'.
  /// Reverses the order if b < a.
  List<S2Point> slice(double a, double b) {
    final result = <S2Point>[];
    addSlice(result, a, b);
    return result;
  }

  /// Appends the chain sliced from fraction 'a' to fraction 'b' to 'result'.
  /// Reverses the order if b < a.
  void addSlice(List<S2Point> result, double a, double b) {
    if (_cumulativeValues.isEmpty) {
      return;
    }

    final int start = result.length;
    final bool reverse = a > b;
    if (reverse) {
      final t = a;
      a = b;
      b = t;
    }

    if (!findPointAtFraction(a)) {
      throw ArgumentError('Invalid value of A: $a');
    }
    final startEdge = resultEdgeId;
    S2Point last = resultPoint;
    result.add(last);

    if (!findPointAtFraction(b)) {
      throw ArgumentError('Invalid value of B: $b');
    }
    final endEdge = resultEdgeId;
    final edge = MutableEdge();
    for (int id = startEdge; id < endEdge; id++) {
      shape.getEdge(id, edge);
      if (last != edge.b!) {
        last = edge.b!;
        result.add(edge.b!);
      }
    }
    result.add(resultPoint);

    if (reverse) {
      _reverseSublist(result, start, result.length);
    }
  }

  static void _reverseSublist<T>(List<T> list, int start, int end) {
    while (start < end - 1) {
      final temp = list[start];
      list[start] = list[end - 1];
      list[end - 1] = temp;
      start++;
      end--;
    }
  }

  /// Computes the S2Point at the given distance along the edges.
  ///
  /// Returns true if the query has at least one edge. Sets resultPoint,
  /// resultEdgeId, and resultDistance which are accessible via the result
  /// accessor methods.
  ///
  /// If the distance exceeds total length, the result is the end vertex.
  /// If the distance is negative, the result is the first vertex.
  bool findPoint(S1Angle distance) {
    if (_cumulativeValues.isEmpty) {
      return false;
    }

    // Binary search to find the lowest cumulative value >= distance.
    final lowerBound = _lowerBound(
        0, _cumulativeValues.length, (i) => _cumulativeValues[i].compareTo(distance) < 0);

    final edge = MutableEdge();
    if (lowerBound == 0) {
      // Corner case: the first vertex at distance = 0.
      shape.getEdge(_firstEdgeId, edge);
      _resultPoint = edge.a;
      _resultEdgeId = _firstEdgeId;
      _resultDistance = _cumulativeValues[0];
    } else if (lowerBound == _cumulativeValues.length) {
      // Corner case: distance exceeds total length, snap to last vertex.
      shape.getEdge(_lastEdgeId, edge);
      _resultPoint = edge.b;
      _resultEdgeId = _lastEdgeId;
      _resultDistance = _cumulativeValues.last;
    } else {
      // Compute the interpolated result from edge vertices.
      _resultEdgeId = lowerBound + _firstEdgeId - 1;
      shape.getEdge(_resultEdgeId, edge);
      _resultDistance = distance;
      // Interpolate by the distance beyond the cumulative distance at start.
      _resultPoint = S2EdgeUtil.getPointOnLine(
          edge.a!, edge.b!, distance.sub(_cumulativeValues[lowerBound - 1]));
    }
    return true;
  }

  /// Computes the S2Point at the given normalized fraction along the edges.
  ///
  /// A fraction of 0 corresponds to the beginning, and 1 to the end.
  /// Returns true if the query has at least one edge.
  bool findPointAtFraction(double fraction) {
    return findPoint(getLength().mul(fraction));
  }

  /// Returns the point from the last query. Valid if findPoint* returned true.
  S2Point get resultPoint => _resultPoint!;

  /// Returns the edge id from the last query. Valid if findPoint* returned true.
  int get resultEdgeId => _resultEdgeId;

  /// Returns the distance from the last query. Valid if findPoint* returned true.
  S1Angle get resultDistance => _resultDistance!;

  /// Binary search returning the first index i in [begin, end) where pred(i)
  /// is false. If pred(i) is true for all i, returns end.
  static int _lowerBound(int begin, int end, bool Function(int) pred) {
    while (begin < end) {
      final mid = begin + ((end - begin) >> 1);
      if (pred(mid)) {
        begin = mid + 1;
      } else {
        end = mid;
      }
    }
    return begin;
  }
}

