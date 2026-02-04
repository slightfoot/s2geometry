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

import 'dart:math';

import 'r1_interval.dart';
import 'r2_rect.dart';
import 's2.dart';
import 's2_cell_id.dart';
import 's2_point.dart';
import 's2_projections.dart';

/// S2PaddedCell represents an S2Cell whose (u,v)-range has been expanded on
/// all sides by a given amount of "padding".
///
/// Unlike S2Cell, its methods and representation are optimized for clipping
/// edges against S2Cell boundaries to determine which cells are intersected
/// by a given set of edges.
class S2PaddedCell {
  /// The cell being padded.
  final S2CellId _id;

  /// UV padding on all sides.
  final double _padding;

  /// Bound in (u,v)-space. Includes padding.
  final R2Rect _bound;

  /// The rectangle in (u,v)-space that belongs to all four padded children.
  /// Computed on demand by the middle() accessor method.
  R2Rect? _middle;

  /// Minimum (i,j)-coordinates of this cell, before padding.
  final int _iLo;
  final int _jLo;

  /// Hilbert curve orientation of this cell.
  final int _orientation;

  /// Level of this cell.
  final int _level;

  /// Construct an S2PaddedCell for the given cell id and padding.
  S2PaddedCell(S2CellId id, double padding)
      : _id = id,
        _padding = padding,
        _bound = _computeBound(id, padding),
        _middle = id.isFace ? _computeMiddle(padding) : null,
        _iLo = _computeILo(id),
        _jLo = _computeJLo(id),
        _orientation = _computeOrientation(id),
        _level = id.isFace ? 0 : id.level;

  static R2Rect _computeBound(S2CellId id, double padding) {
    if (id.isFace) {
      final limit = 1 + padding;
      return R2Rect(R1Interval(-limit, limit), R1Interval(-limit, limit));
    } else {
      final ijo = id.toIJOrientation();
      final i = S2CellId.getI(ijo);
      final j = S2CellId.getJ(ijo);
      return S2CellId.ijLevelToBoundUv(i, j, id.level).expanded(padding);
    }
  }

  static R2Rect? _computeMiddle(double padding) {
    return R2Rect(R1Interval(-padding, padding), R1Interval(-padding, padding));
  }

  static int _computeILo(S2CellId id) {
    if (id.isFace) return 0;
    final ijo = id.toIJOrientation();
    final i = S2CellId.getI(ijo);
    final ijSize = S2CellId.getSizeIJ(id.level);
    return i & -ijSize;
  }

  static int _computeJLo(S2CellId id) {
    if (id.isFace) return 0;
    final ijo = id.toIJOrientation();
    final j = S2CellId.getJ(ijo);
    final ijSize = S2CellId.getSizeIJ(id.level);
    return j & -ijSize;
  }

  static int _computeOrientation(S2CellId id) {
    if (id.isFace) return id.face & 1;
    final ijo = id.toIJOrientation();
    return S2CellId.getOrientation(ijo);
  }

  /// Private constructor to create a new S2PaddedCell for the child at the
  /// given (i,j) position.
  S2PaddedCell._child(
    S2PaddedCell parent,
    int pos,
    int i,
    int j,
  )   : _padding = parent._padding,
        _level = parent._level + 1,
        _id = parent._id.child(pos),
        _iLo = parent._iLo + i * S2CellId.getSizeIJ(parent._level + 1),
        _jLo = parent._jLo + j * S2CellId.getSizeIJ(parent._level + 1),
        _orientation = parent._orientation ^ S2.posToOrientation(pos),
        _bound = _computeChildBound(parent, i, j),
        _middle = null;

  static R2Rect _computeChildBound(S2PaddedCell parent, int i, int j) {
    final middle = parent.middle();
    final bound = R2Rect(
      R1Interval(parent._bound.x.lo, parent._bound.x.hi),
      R1Interval(parent._bound.y.lo, parent._bound.y.hi),
    );
    if (i == 0) {
      bound.x.hi = middle.x.hi;
    } else {
      bound.x.lo = middle.x.lo;
    }
    if (j == 0) {
      bound.y.hi = middle.y.hi;
    } else {
      bound.y.lo = middle.y.lo;
    }
    return bound;
  }

  /// Construct the child of this cell with the given (i,j) index.
  /// The four child cells have indices of (0,0), (0,1), (1,0), (1,1).
  S2PaddedCell childAtIJ(int i, int j) {
    return S2PaddedCell._child(this, S2.ijToPos(_orientation, i * 2 + j), i, j);
  }

  /// Construct the child of this cell with the given Hilbert curve position,
  /// from 0 to 3.
  S2PaddedCell childAtPos(int pos) {
    final ij = S2.posToIJ(_orientation, pos);
    return S2PaddedCell._child(this, pos, ij >> 1, ij & 1);
  }

  /// Returns the ID of this padded cell.
  S2CellId get id => _id;

  /// Returns the padding around this cell.
  double get padding => _padding;

  /// Returns the level of this cell.
  int get level => _level;

  /// Returns the orientation of this cell.
  int get orientation => _orientation;

  /// Returns the bound for this cell (including padding.)
  R2Rect get bound => _bound;

  /// Return the "middle" of the padded cell, defined as the rectangle that
  /// belongs to all four children.
  ///
  /// Note that this method is *not* thread-safe, because the return value is
  /// computed on demand and cached.
  R2Rect middle() {
    if (_middle == null) {
      final ijSize = S2CellId.getSizeIJ(_level);
      final u = S2Projections.stToUV(S2Projections.siTiToSt(2 * _iLo + ijSize));
      final v = S2Projections.stToUV(S2Projections.siTiToSt(2 * _jLo + ijSize));
      _middle = R2Rect(
        R1Interval(u - _padding, u + _padding),
        R1Interval(v - _padding, v + _padding),
      );
    }
    return _middle!;
  }

  /// Returns the smallest cell that contains all descendants of this cell
  /// whose bounds intersect [rect].
  ///
  /// For algorithms that use recursive subdivision to find the cells that
  /// intersect a particular object, this method can be used to skip all the
  /// initial subdivision steps where only one child needs to be expanded.
  ///
  /// Results are undefined if [bound] does not intersect the given rectangle.
  S2CellId shrinkToFit(R2Rect rect) {
    final ijSize = S2CellId.getSizeIJ(_level);

    // Quick rejection test
    if (_level == 0) {
      if (rect.x.containsPoint(0.0) || rect.y.containsPoint(0.0)) {
        return _id;
      }
    } else {
      if (rect.x.containsPoint(S2Projections.stToUV(S2Projections.siTiToSt(2 * _iLo + ijSize))) ||
          rect.y.containsPoint(S2Projections.stToUV(S2Projections.siTiToSt(2 * _jLo + ijSize)))) {
        return _id;
      }
    }

    // Expand "rect" by the given padding on all sides
    final padded = rect.expanded(_padding + 1.5 * S2.dblEpsilon);
    final iMin = max(_iLo, S2Projections.stToIj(S2Projections.uvToST(padded.x.lo)));
    final jMin = max(_jLo, S2Projections.stToIj(S2Projections.uvToST(padded.y.lo)));
    final iMax = min(_iLo + ijSize - 1, S2Projections.stToIj(S2Projections.uvToST(padded.x.hi)));
    final jMax = min(_jLo + ijSize - 1, S2Projections.stToIj(S2Projections.uvToST(padded.y.hi)));
    final iXor = iMin ^ iMax;
    final jXor = jMin ^ jMax;

    // Compute the highest bit position where the two i- or j-endpoints differ
    final levelMsb = ((iXor | jXor) << 1) + 1;
    final level = S2CellId.maxLevel - _floorLog2(levelMsb);
    if (level <= _level) {
      return _id;
    }
    return S2CellId.fromFaceIJ(_id.face, iMin, jMin).parentAtLevel(level);
  }

  /// Returns the floor of the log2 of x, assuming x is positive.
  static int _floorLog2(int x) {
    return 63 - _numberOfLeadingZeros(x);
  }

  /// Returns the number of leading zeros in a 64-bit integer.
  static int _numberOfLeadingZeros(int x) {
    if (x == 0) return 64;
    int n = 0;
    if (x & 0xFFFFFFFF00000000 == 0) {
      n += 32;
      x <<= 32;
    }
    if (x & 0xFFFF000000000000 == 0) {
      n += 16;
      x <<= 16;
    }
    if (x & 0xFF00000000000000 == 0) {
      n += 8;
      x <<= 8;
    }
    if (x & 0xF000000000000000 == 0) {
      n += 4;
      x <<= 4;
    }
    if (x & 0xC000000000000000 == 0) {
      n += 2;
      x <<= 2;
    }
    if (x & 0x8000000000000000 == 0) {
      n += 1;
    }
    return n;
  }

  /// Returns the center of this cell.
  S2Point getCenter() {
    final ijSize = S2CellId.getSizeIJ(_level);
    final si = 2 * _iLo + ijSize;
    final ti = 2 * _jLo + ijSize;
    return S2Projections.faceSiTiToXyz(_id.face, si, ti).normalize();
  }

  /// Returns the vertex where the S2 space-filling curve enters this cell.
  S2Point getEntryVertex() {
    var i = _iLo;
    var j = _jLo;
    if ((_orientation & S2.invertMask) != 0) {
      final ijSize = S2CellId.getSizeIJ(_level);
      i += ijSize;
      j += ijSize;
    }
    return S2Projections.faceSiTiToXyz(_id.face, 2 * i, 2 * j).normalize();
  }

  /// Returns the vertex where the S2 space-filling curve exits this cell.
  S2Point getExitVertex() {
    var i = _iLo;
    var j = _jLo;
    final ijSize = S2CellId.getSizeIJ(_level);
    if (_orientation == 0 || _orientation == S2.swapMask + S2.invertMask) {
      i += ijSize;
    } else {
      j += ijSize;
    }
    return S2Projections.faceSiTiToXyz(_id.face, 2 * i, 2 * j).normalize();
  }
}

