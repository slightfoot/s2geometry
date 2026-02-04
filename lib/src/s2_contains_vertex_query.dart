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

import 's2.dart';
import 's2_point.dart';
import 's2_predicates.dart';

/// This class determines whether a polygon contains one of its vertices given
/// the edges incident to that vertex.
/// 
/// The result is +1 if the vertex is contained, -1 if it is not contained,
/// and 0 if the incident edges consist of matched sibling pairs (in which
/// case the result cannot be determined locally).
///
/// The "semi-open" boundary model is used to define point containment. This
/// means that if several polygons tile the region around a vertex, then
/// exactly one of those polygons contains that vertex.
///
/// This class is not thread-safe.
class S2ContainsVertexQuery {
  /// The target vertex for which we are determining containment.
  S2Point? _target;

  /// Endpoints of outgoing polygon edges from "target".
  final List<S2Point> _outgoing = [];

  /// Starting points of incoming polygon edges to "target".
  final List<S2Point> _incoming = [];

  /// Creates a contains vertex query. init() must be called before use.
  S2ContainsVertexQuery();

  /// Creates a contains vertex query to determine containment of [target].
  S2ContainsVertexQuery.withTarget(S2Point target) : _target = target;

  /// Initializes the query to determine containment of [target].
  void init(S2Point target) {
    _target = target;
    _outgoing.clear();
    _incoming.clear();
  }

  /// Adds an edge outgoing from target to [v].
  void addOutgoing(S2Point v) {
    _outgoing.add(v);
  }

  /// Adds an edge from [v] incoming to target.
  void addIncoming(S2Point v) {
    _incoming.add(v);
  }

  /// Returns +1 if the target vertex is contained, -1 if it is not contained,
  /// and 0 if the incident edges consisted of matched sibling pairs.
  ///
  /// Throws an assertion error if duplicate unmatched edges incident on the
  /// target are found, which indicates an invalid configuration of edges
  /// around the target vertex. Consider [safeContainsSign] if you are not
  /// sure the polygon is valid.
  int containsSign() {
    final s = safeContainsSign();
    assert(s != null, 'Duplicate edges found');
    return s!;
  }

  /// Returns true if there are any duplicate edges incident on "target",
  /// where matched incoming and outgoing edge pairs cancel out.
  bool duplicateEdges() {
    return safeContainsSign() == null;
  }

  /// Returns null if duplicate unmatched edges incident on the target are
  /// found. Otherwise, returns +1 if the target vertex is contained, -1 if
  /// it is not contained, and 0 if the incident edges consisted of matched
  /// sibling pairs.
  int? safeContainsSign() {
    final target = _target!;
    
    // Find the unmatched edge that is immediately clockwise from S2.refDir(target)
    // but not equal to it. The result is +1 iff this edge is outgoing.
    bool duplicateEdgesFound = false;
    final referenceDir = S2.refDir(target);
    S2Point bestPoint = referenceDir;
    int bestSum = 0;

    // Merge outgoing and incoming lists together, computing a sum of each
    // distinct vertex as the count of outgoing occurrences minus the count
    // of incoming occurrences.
    final outgoing = List<S2Point>.from(_outgoing)..sort();
    final incoming = List<S2Point>.from(_incoming)..sort();

    int out = 0;
    int inIdx = 0;
    while (out < outgoing.length || inIdx < incoming.length) {
      S2Point v;
      int direction;

      if (out == outgoing.length) {
        v = incoming[inIdx];
        direction = -_count(incoming, inIdx);
        inIdx -= direction;
      } else if (inIdx == incoming.length) {
        v = outgoing[out];
        direction = _count(outgoing, out);
        out += direction;
      } else {
        final outPoint = outgoing[out];
        final inPoint = incoming[inIdx];
        final diff = outPoint.compareTo(inPoint);
        if (diff < 0) {
          v = outPoint;
          direction = _count(outgoing, out);
          out += direction;
        } else if (diff > 0) {
          v = inPoint;
          direction = -_count(incoming, inIdx);
          inIdx -= direction;
        } else {
          v = outPoint;
          final outSum = _count(outgoing, out);
          final inSum = _count(incoming, inIdx);
          direction = outSum - inSum;
          out += outSum;
          inIdx += inSum;
        }
      }

      duplicateEdgesFound |= (direction.abs() > 1);
      if (direction == 0) {
        // This is a "matched" edge.
        continue;
      }
      if (S2Predicates.orderedCCW(referenceDir, bestPoint, v, target)) {
        bestPoint = v;
        bestSum = direction;
      }
    }

    return duplicateEdgesFound ? null : bestSum;
  }

  /// Returns the count of vertices equal to vertices[start].
  static int _count(List<S2Point> vertices, int start) {
    final v = vertices[start];
    int sum = 1;
    for (int i = start + 1; i < vertices.length && vertices[i] == v; i++) {
      sum++;
    }
    return sum;
  }
}

