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

import 's2.dart';
import 's2_point.dart';

/// S2Shape is an abstract base class that defines a shape as a collection of
/// edges, which are organized in chains.
///
/// Typically it wraps some other geometric object in order to provide access
/// to its edges without duplicating the edge data.
abstract class S2Shape {
  /// Returns the number of edges in this shape.
  int get numEdges;

  /// Returns the edge for the given edgeId in [result].
  void getEdge(int edgeId, MutableEdge result);

  /// Returns true if this shape has an interior.
  bool get hasInterior;

  /// Returns true if this shape contains [S2.origin].
  bool get containsOrigin;

  /// Returns the number of contiguous edge chains in the shape.
  int get numChains;

  /// Returns the first edge id corresponding to the edge chain for the given
  /// chain id.
  int getChainStart(int chainId);

  /// Returns the number of edge ids corresponding to the edge chain for the
  /// given chain id.
  int getChainLength(int chainId);

  /// Returns the edge for the given chain id and offset in [result].
  void getChainEdge(int chainId, int offset, MutableEdge result);

  /// Finds the chain containing the given edge, and returns the position of
  /// that edge as a (chainId, offset) pair in [result].
  void getChainPosition(int edgeId, ChainPosition result);

  /// Returns the start point of the edge at the given chain and offset.
  S2Point getChainVertex(int chainId, int edgeOffset);

  /// Returns the dimension of the geometry represented by this shape.
  /// - 0: Point geometry
  /// - 1: Polyline geometry
  /// - 2: Polygon geometry
  int get dimension;

  /// Returns true if the shape contains no points.
  bool get isEmpty => numEdges == 0 && (dimension < 2 || numChains == 0);

  /// Returns true if the shape contains all points on the sphere.
  bool get isFull => numEdges == 0 && dimension == 2 && numChains > 0;

  /// Returns a reference point for this shape.
  ReferencePoint get referencePoint {
    assert(dimension == 2);
    return ReferencePoint(S2.origin, containsOrigin);
  }
}

/// A simple receiver for the endpoints of an edge.
class MutableEdge {
  /// The start point of this edge.
  S2Point? a;

  /// The end point of this edge.
  S2Point? b;

  /// Creates a new MutableEdge.
  MutableEdge([this.a, this.b]);

  /// Creates a new MutableEdge with the given endpoints.
  factory MutableEdge.of(S2Point a, S2Point b) => MutableEdge(a, b);

  /// Returns the current start point of this edge.
  S2Point? get start => a;

  /// Returns the current end point of this edge.
  S2Point? get end => b;

  /// Returns true if this edge is degenerate (endpoints are equal).
  bool get isDegenerate => a != null && b != null && a == b;

  /// Returns true if this edge has the given point as either endpoint.
  bool hasEndpoint(S2Point point) =>
      (a != null && a == point) || (b != null && b == point);

  /// Returns true if this edge has the same endpoints as [other].
  bool isEqualTo(MutableEdge other) =>
      a != null && b != null && a == other.a && b == other.b;

  /// Returns true if this edge has the reversed endpoints as [other].
  bool isSiblingOf(MutableEdge other) =>
      a != null && b != null && a == other.b && b == other.a;

  /// Updates the endpoints of this edge.
  void set(S2Point start, S2Point end) {
    a = start;
    b = end;
  }

  /// Exchanges the endpoints of this edge.
  void reverse() {
    final t = a;
    a = b;
    b = t;
  }

  /// Returns a string representation in degrees.
  String toDegreesString() =>
      '${a?.toDegreesString() ?? 'null'}-${b?.toDegreesString() ?? 'null'}';

  @override
  String toString() => toDegreesString();
}

/// The position of an edge within an S2Shape's edge chains.
class ChainPosition {
  int chainId = 0;
  int offset = 0;

  /// Sets this position's chainId and offset.
  void set(int chainId, int offset) {
    this.chainId = chainId;
    this.offset = offset;
  }

  /// Returns true if this has the same chainId and offset as [other].
  bool isEqualTo(ChainPosition other) =>
      chainId == other.chainId && offset == other.offset;
}

/// A point with a known containment relationship.
class ReferencePoint {
  final S2Point point;
  final bool contained;

  /// Creates a reference point.
  const ReferencePoint(this.point, this.contained);

  /// Creates a reference point at the origin.
  factory ReferencePoint.origin(bool contained) =>
      ReferencePoint(S2.origin, contained);

  /// Returns true if this point equals [p].
  bool equalsPoint(S2Point p) => point == p;

  @override
  bool operator ==(Object other) =>
      other is ReferencePoint &&
      point == other.point &&
      contained == other.contained;

  @override
  int get hashCode => Object.hash(point, contained);
}

