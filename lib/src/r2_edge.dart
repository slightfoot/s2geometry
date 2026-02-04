// Copyright 2024 Google Inc.
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

import 'r2_vector.dart';

/// An R2Edge is a mutable edge in two-dimensional space.
class R2Edge {
  final R2Vector v0 = R2Vector.origin();
  final R2Vector v1 = R2Vector.origin();

  /// Creates a new mutable edge with both endpoints initially at (0, 0).
  R2Edge();

  /// Initializes this edge endpoints to be copies of the given endpoints.
  void initFromPoints(R2Vector newV0, R2Vector newV1) {
    v0.setFrom(newV0);
    v1.setFrom(newV1);
  }

  /// Sets this edge endpoints to be copies of the current endpoints of the
  /// given edge.
  void init(R2Edge edge) {
    v0.setFrom(edge.v0);
    v1.setFrom(edge.v1);
  }

  /// Alias for [init] to match Java API.
  void initFromEdge(R2Edge edge) {
    init(edge);
  }

  /// Returns true if the current endpoints of this edge have exactly the 
  /// same values as the current endpoints of the given other edge.
  bool isEqualTo(R2Edge other) {
    return v0 == other.v0 && v1 == other.v1;
  }

  /// Mutable objects should not implement equals(). Use [isEqualTo] to 
  /// compare the current values of two R2Edges.
  @override
  bool operator ==(Object other) {
    throw UnsupportedError('R2Edge is mutable and does not support ==.');
  }

  /// Mutable objects should not implement hashCode().
  @override
  int get hashCode {
    throw UnsupportedError('R2Edge is mutable and does not support hashCode.');
  }

  @override
  String toString() => 'R2Edge($v0, $v1)';
}

