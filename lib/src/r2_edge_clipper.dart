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

import 'r1_interval.dart';
import 'r2_edge.dart';
import 'r2_rect.dart';
import 'r2_vector.dart';
import 's2_edge_util.dart';

/// Class to clip edges to rectangular regions in 2D space.
///
/// R2EdgeClipper does not clip exactly or use exact tests to determine boundary
/// crossings. It's possible for points very close to the boundary to falsely
/// test as crossing.
///
/// We use the Cohen-Sutherland algorithm which classifies each endpoint of an
/// edge by which region it falls into relative to the clip region: top, bottom,
/// left and right.
class R2EdgeClipper {
  /// When the magnitudes of the clip region coordinates and the clip points are
  /// less than or equal to 1, this is a bound on the absolute error in each
  /// coordinate of the clipped edge.
  static const double maxUnitClipError = 2 * S2EdgeUtil.edgeClipErrorUvCoord;

  /// An outcode indicating that a vertex is inside the clip region.
  static const int inside = 0x00;

  /// An outcode indicating that a vertex is on the bottom boundary.
  static const int bottom = 0x01;

  /// An outcode indicating that a vertex is on the right boundary.
  static const int right = 0x02;

  /// An outcode indicating that a vertex is on the top boundary.
  static const int top = 0x04;

  /// An outcode indicating that a vertex is on the left boundary.
  static const int left = 0x08;

  /// An outcode indicating that a vertex is outside the clip region.
  static const int outside = 0xFF;

  double _xMin = 0;
  double _xMax = 0;
  double _yMin = 0;
  double _yMax = 0;

  R2Edge? _edge;
  int _lastOutcode = inside;

  /// The clipped edge.
  final R2Edge clippedEdge = R2Edge();

  /// The outcode for the first vertex of the clipped edge.
  int outcode0 = outside;

  /// The outcode for the second vertex of the clipped edge.
  int outcode1 = outside;

  /// Default constructor without setting a clip rectangle.
  R2EdgeClipper();

  /// Constructor that sets the clip rectangle.
  R2EdgeClipper.fromRect(R2Rect rectangle) {
    init(rectangle);
  }

  /// Sets the clip rectangle to the given [rectangle].
  void init(R2Rect rectangle) {
    _xMin = rectangle.x.lo;
    _xMax = rectangle.x.hi;
    _yMin = rectangle.y.lo;
    _yMax = rectangle.y.hi;
  }

  /// Returns the current clipping rectangle.
  R2Rect get clipRect =>
      R2Rect(R1Interval(_xMin, _xMax), R1Interval(_yMin, _yMax));

  /// Clips an edge to the current clip rectangle.
  ///
  /// Returns true when the edge intersected the clip region, false otherwise.
  /// If [connected] is true, the clipper assumes that v1 of the last edge
  /// passed is equal to v0 of the current edge and re-uses calculations.
  bool clipEdge(R2Edge edge, bool connected) {
    outcode0 = outside;
    outcode1 = outside;

    int code0 = connected ? _lastOutcode : _outcode(edge.v0);
    int code1 = _outcode(edge.v1);
    _lastOutcode = code1;

    // If both vertices are in the same outside region, the edge can't
    // intersect the clip region.
    if ((code0 & code1) != inside) {
      return false;
    }

    clippedEdge.init(edge);
    if (code0 != inside) {
      code0 = _clipVertex(clippedEdge.v0, edge, code0);
    }

    if (code1 != inside) {
      code1 = _clipVertex(clippedEdge.v1, edge, code1);
    }

    outcode0 = code0;
    outcode1 = code1;

    return code0 != outside && code1 != outside;
  }

  /// Unconditionally clips an edge to the boundary represented by an outcode.
  ///
  /// REQUIRES: outcode is a power of two (represents a single region)
  void clip(R2Edge edge, int outcode, R2Vector result) {
    _edge = edge;
    assert(outcode > 0);
    assert((outcode & (outcode - 1)) == 0);

    switch (outcode) {
      case bottom:
        _clipBottom(result);
        break;
      case right:
        _clipRight(result);
        break;
      case top:
        _clipTop(result);
        break;
      case left:
        _clipLeft(result);
        break;
      default:
        throw ArgumentError('Invalid outcode: $outcode');
    }
  }

  /// Returns a logical or of the outcodes indicating which clip region
  /// boundaries the point falls outside of, or [inside] if the point is
  /// inside the clip region.
  int _outcode(R2Vector uv) {
    int code = 0;
    if (uv.x < _xMin) {
      code |= left;
    } else if (uv.x > _xMax) {
      code |= right;
    }
    if (uv.y < _yMin) {
      code |= bottom;
    } else if (uv.y > _yMax) {
      code |= top;
    }
    return code;
  }

  /// Finds the intersection point between an edge and the bottom clip edge.
  void _clipBottom(R2Vector intersection) {
    intersection.set(_interpolateX(_yMin), _yMin);
  }

  /// Finds the intersection point between an edge and the right clip edge.
  void _clipRight(R2Vector intersection) {
    intersection.set(_xMax, _interpolateY(_xMax));
  }

  /// Finds the intersection point between an edge and the top clip edge.
  void _clipTop(R2Vector intersection) {
    intersection.set(_interpolateX(_yMax), _yMax);
  }

  /// Finds the intersection point between an edge and the left clip edge.
  void _clipLeft(R2Vector intersection) {
    intersection.set(_xMin, _interpolateY(_xMin));
  }

  /// Interpolates Y between two endpoints based on an X coordinate.
  double _interpolateY(double x) {
    final v0 = _edge!.v0;
    final v1 = _edge!.v1;
    return S2EdgeUtil.interpolateDouble(x, v0.x, v1.x, v0.y, v1.y);
  }

  /// Interpolates X between two endpoints based on a Y coordinate.
  double _interpolateX(double y) {
    final v0 = _edge!.v0;
    final v1 = _edge!.v1;
    return S2EdgeUtil.interpolateDouble(y, v0.y, v1.y, v0.x, v1.x);
  }

  /// Clips a vertex of an edge based on its outcode and returns an outcode
  /// representing the boundary that the vertex was clipped to. If the edge
  /// fell outside the clipping region, then [outside] is returned.
  int _clipVertex(R2Vector v0, R2Edge edge, int code) {
    _edge = edge;
    assert(code != inside);
    assert(code != outside);

    // Simple regions just refer to a single side of a boundary, so they only
    // have to be clipped once. Power of two outcodes are simple.
    if ((code & (code - 1)) == 0) {
      clip(edge, code, v0);

      // Return outside if the vertex is still outside the clip region,
      // otherwise return the boundary we clipped to.
      if (_outcode(v0) != inside) {
        return outside;
      }
      return code;
    }

    // If the vertex is in one of the corners we may have to clip it twice.
    final va = R2Vector.origin();
    final vb = R2Vector.origin();
    int outa;
    int outb;

    // Use if-else instead of switch because Dart doesn't allow binary
    // operators in constant case patterns.
    if (code == (top | left)) {
      outa = top;
      outb = left;
      _clipTop(va);
      _clipLeft(vb);
    } else if (code == (top | right)) {
      outa = top;
      outb = right;
      _clipTop(va);
      _clipRight(vb);
    } else if (code == (bottom | left)) {
      outa = bottom;
      outb = left;
      _clipBottom(va);
      _clipLeft(vb);
    } else if (code == (bottom | right)) {
      outa = bottom;
      outb = right;
      _clipBottom(va);
      _clipRight(vb);
    } else {
      throw StateError('Invalid outcode: $code');
    }

    if (_outcode(va) == inside) {
      v0.setFrom(va);
      return outa;
    }

    if (_outcode(vb) == inside) {
      v0.setFrom(vb);
      return outb;
    }

    // Neither clipped point landed inside the clip region.
    return outside;
  }
}
