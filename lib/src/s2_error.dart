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

/// An error code and text string describing the first error encountered
/// during a validation process.
class S2Error {
  S2ErrorCode _code = S2ErrorCode.noError;
  String _text = '';

  /// Prepares an S2Error instance for reuse by resetting it to its original state.
  void clear() {
    _code = S2ErrorCode.noError;
    _text = '';
  }

  /// Sets the error code and text description.
  /// 
  /// The description is formatted using a simple format string where %s
  /// placeholders are replaced with the string representation of the
  /// corresponding argument.
  void init(S2ErrorCode code, String format, [List<Object>? args]) {
    _code = code;
    if (args == null || args.isEmpty) {
      _text = format;
    } else {
      _text = _lenientFormat(format, args);
    }
  }

  /// Returns the code of this error.
  S2ErrorCode get code => _code;

  /// Returns true if this error's code is NO_ERROR.
  bool get ok => _code == S2ErrorCode.noError;

  /// Returns the text string.
  String get text => _text;

  @override
  String toString() {
    if (_code == S2ErrorCode.noError) {
      return 'OK';
    }
    return '${_code.name}: $_text';
  }

  /// Simple format function that replaces %s and %d with string representations
  /// of the arguments.
  static String _lenientFormat(String format, List<Object> args) {
    var result = format.replaceAll('%d', '%s');
    var argIndex = 0;
    final buffer = StringBuffer();
    var i = 0;
    while (i < result.length) {
      if (i + 1 < result.length && result[i] == '%' && result[i + 1] == 's') {
        if (argIndex < args.length) {
          buffer.write(args[argIndex].toString());
          argIndex++;
        } else {
          buffer.write('[missing argument]');
        }
        i += 2;
      } else {
        buffer.write(result[i]);
        i++;
      }
    }
    return buffer.toString();
  }
}

/// Numeric values for S2 errors.
enum S2ErrorCode {
  /// No problems detected.
  noError(0),

  // Generic errors, not specific to geometric objects:
  /// Unknown error.
  unknown(1000),
  /// Operation is not implemented.
  unimplemented(1001),
  /// Argument is out of range.
  outOfRange(1002),
  /// Invalid argument (other than a range error).
  invalidArgument(1003),
  /// Object is not in the required state.
  failedPrecondition(1004),
  /// An internal invariant has failed.
  internal(1005),
  /// Data loss or corruption.
  dataLoss(1006),
  /// A resource has been exhausted.
  resourceExhausted(1007),
  /// Operation was cancelled.
  cancelled(1008),

  // Error codes that apply to more than one type of geometry:
  /// Vertex is not unit length.
  notUnitLength(1),
  /// There are two identical vertices.
  duplicateVertices(2),
  /// There are two antipodal vertices.
  antipodalVertices(3),
  /// Edges of a chain aren't continuous.
  notContinuous(4),
  /// Vertex has value that's inf or NaN.
  invalidVertex(5),

  // S2Loop errors:
  /// Loop with fewer than 3 vertices.
  loopNotEnoughVertices(100),
  /// Loop has a self-intersection.
  loopSelfIntersection(101),

  // S2Polygon / S2Shape errors:
  /// Two polygon loops share an edge.
  polygonLoopsShareEdge(200),
  /// Two polygon loops cross.
  polygonLoopsCross(201),
  /// Polygon has an empty loop.
  polygonEmptyLoop(202),
  /// Non-full polygon has a full loop.
  polygonExcessFullLoop(203),
  /// Inconsistent loop orientations were detected.
  polygonInconsistentLoopOrientations(204),
  /// Loop depths don't correspond to any valid nesting hierarchy.
  polygonInvalidLoopDepth(205),
  /// Actual polygon nesting does not correspond to the nesting given in the loop depths.
  polygonInvalidLoopNesting(206),
  /// Shape dimension isn't valid.
  invalidDimension(207),
  /// Interior split by holes.
  splitInterior(208),
  /// Geometry overlaps where it shouldn't.
  overlappingGeometry(209),

  // S2Builder errors:
  /// The S2Builder snap function moved a vertex by more than the specified snap radius.
  builderSnapRadiusTooSmall(300),
  /// S2Builder expected all edges to have siblings, but some were missing.
  builderMissingExpectedSiblingEdges(301),
  /// S2Builder found an unexpected degenerate edge.
  builderUnexpectedDegenerateEdge(302),
  /// S2Builder found a vertex with (indegree != outdegree).
  builderEdgesDoNotFormLoops(303),
  /// The edges provided to S2Builder cannot be assembled into a polyline.
  builderEdgesDoNotFormPolyline(304),
  /// There was an attempt to assemble a polygon from degenerate geometry.
  builderIsFullPredicateNotSpecified(305),

  /// User defined error codes start here.
  userDefinedStart(1000000),
  /// User defined error codes end here.
  userDefinedEnd(9999999);

  final int code;

  const S2ErrorCode(this.code);
}

