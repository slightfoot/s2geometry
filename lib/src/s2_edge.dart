// Copyright 2011 Google Inc.
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
import 's2_shape.dart';

/// An immutable directed edge from one S2Point to another S2Point.
class S2Edge implements S2Shape {
  final S2Point _start;
  final S2Point _end;

  /// Creates an edge from [start] to [end].
  S2Edge(this._start, this._end);

  /// Returns the start point of the edge.
  S2Point get start => _start;

  /// Returns the end point of the edge.
  S2Point get end => _end;

  @override
  String toString() =>
      'Edge: (${_start.toDegreesString()} -> ${_end.toDegreesString()})';

  @override
  int get hashCode => _start.hashCode - _end.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! S2Edge) return false;
    return _start == other._start && _end == other._end;
  }

  // S2Shape implementation

  @override
  int get numEdges => 1;

  @override
  void getEdge(int index, MutableEdge result) {
    assert(index == 0);
    result.set(_start, _end);
  }

  @override
  bool get hasInterior => false;

  @override
  bool get containsOrigin => false;

  @override
  int get numChains => 1;

  @override
  int getChainStart(int chainId) {
    RangeError.checkValidIndex(chainId, [0], 'chainId', numChains);
    return 0;
  }

  @override
  int getChainLength(int chainId) {
    RangeError.checkValidIndex(chainId, [0], 'chainId', numChains);
    return 1;
  }

  @override
  void getChainEdge(int chainId, int offset, MutableEdge result) {
    // getChainLength validates chainId
    RangeError.checkValidIndex(offset, [0], 'offset', getChainLength(chainId));
    result.set(_start, _end);
  }

  @override
  S2Point getChainVertex(int chainId, int edgeOffset) {
    RangeError.checkValidIndex(chainId, [0], 'chainId', numChains);
    RangeError.checkValidIndex(edgeOffset, [0, 0], 'edgeOffset', 2);
    return edgeOffset == 0 ? _start : _end;
  }

  @override
  void getChainPosition(int edgeId, ChainPosition result) {
    assert(edgeId == 0);
    result.set(0, 0);
  }

  @override
  int get dimension => 1;

  // These are defined in S2Shape with default implementations, but Dart
  // requires explicit overrides for abstract class implementations
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

