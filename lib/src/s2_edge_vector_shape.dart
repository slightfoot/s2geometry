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

import 's2_edge.dart';
import 's2_point.dart';
import 's2_shape.dart';

/// S2EdgeVectorShape is a one-dimensional S2Shape representing a set of
/// unrelated edges. Each edge is in its own chain. As a one-dimensional shape,
/// it contains no area and has no interior. Edges may be degenerate, with equal
/// start and end points.
///
/// It is mainly used for testing, but it can also be useful if you have, say,
/// a collection of polylines and don't care about memory efficiency (since this
/// class would store most of the vertices twice.) If the vertices are already
/// stored somewhere else, you would be better off writing your own subclass of
/// S2Shape that points to the existing vertex data rather than copying it.
class S2EdgeVectorShape implements S2Shape {
  final List<S2Edge> _edges = [];

  /// Default constructor creates a vector with no edges.
  S2EdgeVectorShape();

  /// Convenience constructor for creating a vector of length 1.
  S2EdgeVectorShape.single(S2Point a, S2Point b) {
    add(a, b);
  }

  /// Adds an edge to the vector. Degenerate edges are not allowed here.
  void add(S2Point a, S2Point b) {
    if (a == b) {
      throw ArgumentError('Degenerate edge not allowed in add(). Use addDegenerate() instead.');
    }
    _edges.add(S2Edge(a, b));
  }

  /// Adds a degenerate edge to the vector. Note that degenerate edges are
  /// invalid in some contexts. They may be differentiated from points as they
  /// have dimension 1.
  void addDegenerate(S2Point a) {
    _edges.add(S2Edge(a, a));
  }

  /// Returns the edge at the given index.
  S2Edge operator [](int index) => _edges[index];

  /// Returns the number of edges.
  int get length => _edges.length;

  // S2Shape implementation

  @override
  int get numEdges => _edges.length;

  @override
  void getEdge(int index, MutableEdge result) {
    final edge = _edges[index];
    result.set(edge.start, edge.end);
  }

  @override
  bool get hasInterior => false;

  @override
  bool get containsOrigin => false;

  @override
  int get numChains => _edges.length;

  @override
  int getChainStart(int chainId) {
    RangeError.checkValidIndex(chainId, _edges, 'chainId', numChains);
    return chainId;
  }

  @override
  int getChainLength(int chainId) {
    RangeError.checkValidIndex(chainId, _edges, 'chainId', numChains);
    return 1;
  }

  @override
  void getChainEdge(int chainId, int offset, MutableEdge result) {
    RangeError.checkValidIndex(offset, [0], 'offset', getChainLength(chainId));
    getEdge(chainId, result);
  }

  @override
  void getChainPosition(int edgeId, ChainPosition result) {
    // Each edge is its own single-element chain.
    result.set(edgeId, 0);
  }

  @override
  S2Point getChainVertex(int chainId, int edgeOffset) {
    // Every chain has two vertices.
    RangeError.checkValidIndex(edgeOffset, [0, 0], 'edgeOffset', 2);
    final edge = _edges[chainId];
    return edgeOffset == 0 ? edge.start : edge.end;
  }

  @override
  int get dimension => 1;

  @override
  bool get isEmpty => numEdges == 0 && (dimension < 2 || numChains == 0);

  @override
  bool get isFull => numEdges == 0 && dimension == 2 && numChains > 0;

  @override
  ReferencePoint get referencePoint {
    assert(dimension == 2);
    return ReferencePoint.origin(containsOrigin);
  }
}

