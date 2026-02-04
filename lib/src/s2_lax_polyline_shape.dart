// Copyright 2019 Google Inc.
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

import 's2_point.dart';
import 's2_polyline.dart';
import 's2_shape.dart';

/// S2LaxPolylineShape represents a polyline or a collection of polylines
/// (a multipolyline). When representing a single polyline, it is similar to
/// S2Polyline, except that consecutive duplicate vertices are allowed, and
/// the representation is slightly more compact since this class does not
/// implement S2Region.
///
/// Polylines with fewer than two vertices do not define any edges, and
/// attempting to create an S2LaxPolylineShape with a single vertex discards
/// the vertex, resulting in an empty polyline.
///
/// To create an S2LaxPolylineShape representing a degenerate edge, use two
/// identical vertices.
class S2LaxPolylineShape implements S2Shape {
  /// An empty polyline with no edges.
  static final S2LaxPolylineShape empty = S2LaxPolylineShape._([]);

  final List<S2Point> _vertices;

  /// Private constructor. Use factory methods instead.
  S2LaxPolylineShape._(this._vertices);

  /// Creates a lax polyline from the given vertices.
  /// Input consisting of zero or one vertex produces an empty line.
  factory S2LaxPolylineShape.create(Iterable<S2Point> vertices) {
    final list = vertices.toList();
    if (list.length < 2) {
      return empty;
    }
    return S2LaxPolylineShape._(list);
  }

  /// Creates a lax polyline from an S2Polyline by copying its data.
  /// Single-vertex S2Polylines, which represent a degenerate edge, are
  /// converted to the S2LaxPolylineShape representation which uses two
  /// identical vertices.
  factory S2LaxPolylineShape.fromPolyline(S2Polyline line) {
    if (line.numVertices == 1) {
      return S2LaxPolylineShape._([line.vertex(0), line.vertex(0)]);
    }
    return S2LaxPolylineShape.create(line.vertices);
  }

  /// Returns the number of vertices in this polyline.
  int get numVertices => _vertices.length;

  /// Returns the vertex at the given index.
  S2Point vertex(int index) => _vertices[index];

  /// Returns all vertices as an unmodifiable list.
  List<S2Point> get vertices => List.unmodifiable(_vertices);

  // S2Shape implementation

  @override
  int get dimension => 1;

  @override
  bool get hasInterior => false;

  @override
  bool get containsOrigin => false;

  @override
  int get numEdges => _vertices.isEmpty ? 0 : _vertices.length - numChains;

  @override
  int get numChains => _vertices.isEmpty ? 0 : 1;

  @override
  bool get isEmpty => numEdges == 0;

  @override
  bool get isFull => false;

  @override
  void getEdge(int edgeId, MutableEdge result) {
    result.set(_vertices[edgeId], _vertices[edgeId + 1]);
  }

  @override
  int getChainStart(int chainId) {
    assert(chainId == 0);
    return 0;
  }

  @override
  int getChainLength(int chainId) {
    assert(chainId == 0);
    return numEdges;
  }

  @override
  void getChainEdge(int chainId, int offset, MutableEdge result) {
    assert(chainId == 0);
    getEdge(offset, result);
  }

  @override
  void getChainPosition(int edgeId, ChainPosition result) {
    result.set(0, edgeId);
  }

  @override
  S2Point getChainVertex(int chainId, int edgeOffset) {
    assert(chainId == 0);
    return _vertices[edgeOffset];
  }

  @override
  ReferencePoint get referencePoint {
    assert(dimension == 2);
    return ReferencePoint.origin(containsOrigin);
  }
}

