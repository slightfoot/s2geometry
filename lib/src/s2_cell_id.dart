// Copyright 2005 Google Inc. All Rights Reserved.
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
import 's2.dart';
import 's2_latlng.dart';
import 's2_point.dart';
import 's2_projections.dart';

/// An S2CellId is a 64-bit unsigned integer that uniquely identifies a cell
/// in the S2 cell decomposition.
///
/// The encoding format:
/// - 3 bits for face (0..5)
/// - 61 bits for position (center of cell on Hilbert curve)
///
/// The lowest set bit indicates the level: for a cell at level k, the bit at
/// position 2*(MAX_LEVEL-k) is set.
class S2CellId implements Comparable<S2CellId> {
  // Constants
  static const int faceBits = 3;
  static const int numFaces = 6;
  static const int maxLevel = 30;
  static const int posBits = 2 * maxLevel + 1;
  static const int maxSize = 1 << maxLevel;

  /// The maximum unsigned 64-bit integer value.
  static const int maxUnsigned = -1; // 0xFFFFFFFFFFFFFFFF as signed

  // Lookup table constants
  static const int _lookupBits = 4;
  static const int _swapMask = 0x01;
  static const int _invertMask = 0x02;
  static const int _lookupMask = (1 << _lookupBits) - 1;

  // Lookup tables for converting between (i,j) and Hilbert curve position
  static final List<int> _lookupPos = List<int>.filled(1 << (2 * _lookupBits + 2), 0);
  static final List<int> _lookupIJ = List<int>.filled(1 << (2 * _lookupBits + 2), 0);

  // Static initialization
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (!_initialized) {
      _initLookupCell(0, 0, 0, 0, 0, 0);
      _initLookupCell(0, 0, 0, _swapMask, 0, _swapMask);
      _initLookupCell(0, 0, 0, _invertMask, 0, _invertMask);
      _initLookupCell(0, 0, 0, _swapMask | _invertMask, 0, _swapMask | _invertMask);
      _initialized = true;
    }
  }

  static void _initLookupCell(
      int level, int i, int j, int origOrientation, int pos, int orientation) {
    if (level == _lookupBits) {
      int ij = (i << _lookupBits) + j;
      _lookupPos[(ij << 2) + origOrientation] = (pos << 2) + orientation;
      _lookupIJ[(pos << 2) + origOrientation] = (ij << 2) + orientation;
    } else {
      level++;
      i <<= 1;
      j <<= 1;
      pos <<= 2;
      for (int subPos = 0; subPos < 4; subPos++) {
        int ij = S2.posToIJ(orientation, subPos);
        int orientationMask = S2.posToOrientation(subPos);
        _initLookupCell(
          level,
          i + (ij >> 1),
          j + (ij & 1),
          origOrientation,
          pos + subPos,
          orientation ^ orientationMask,
        );
      }
    }
  }

  /// Sentinel value: an invalid cell id guaranteed to be larger than any
  /// valid cell id.
  static final S2CellId sentinel = S2CellId(maxUnsigned);

  /// The canonical invalid cell id with id zero.
  static final S2CellId none = S2CellId(0);

  /// The cell id value.
  final int id;

  /// Constructs an S2CellId with the given cell id value.
  S2CellId(this.id) {
    _ensureInitialized();
  }

  /// Returns the cell corresponding to a given S2 cube face.
  factory S2CellId.fromFace(int face) {
    return S2CellId(_fromFaceAsInt(face));
  }

  /// Return a cell given its face, Hilbert curve position, and level.
  factory S2CellId.fromFacePosLevel(int face, int pos, int level) {
    return S2CellId(_parentAsInt(((face) << posBits) + (pos | 1), level));
  }

  /// Return a leaf cell containing the given point.
  factory S2CellId.fromPoint(S2Point p) {
    int face = S2Projections.xyzToFace(p);
    int i = S2Projections.stToIj(S2Projections.uvToST(S2Projections.xyzToU(face, p)));
    int j = S2Projections.stToIj(S2Projections.uvToST(S2Projections.xyzToV(face, p)));
    return S2CellId.fromFaceIJ(face, i, j);
  }

  /// Return the leaf cell containing the given S2LatLng.
  factory S2CellId.fromLatLng(S2LatLng ll) {
    return S2CellId.fromPoint(ll.toPoint());
  }

  /// Return a leaf cell given its cube face and i,j coordinates.
  factory S2CellId.fromFaceIJ(int face, int i, int j) {
    _ensureInitialized();
    int lsb = 0;
    int msb = face << (posBits - 33);

    int bits = (face & _swapMask);

    for (int k = 7; k >= 4; --k) {
      bits = _lookupBits2(i, j, k, bits);
      msb = _updateBits(msb, k, bits);
      bits = _maskBits(bits);
    }
    for (int k = 3; k >= 0; --k) {
      bits = _lookupBits2(i, j, k, bits);
      lsb = _updateBits(lsb, k, bits);
      bits = _maskBits(bits);
    }

    return S2CellId((((msb << 32) + lsb) << 1) + 1);
  }

  static int _lookupBits2(int i, int j, int k, int bits) {
    bits += (((i >> (k * _lookupBits)) & _lookupMask) << (_lookupBits + 2));
    bits += (((j >> (k * _lookupBits)) & _lookupMask) << 2);
    return _lookupPos[bits];
  }

  static int _updateBits(int sb, int k, int bits) {
    return sb | ((bits >> 2) << ((k & 0x3) * 2 * _lookupBits));
  }

  static int _maskBits(int bits) {
    return bits & (_swapMask | _invertMask);
  }

  static int _fromFaceAsInt(int face) {
    return (face << posBits) + _lowestOnBitForLevel(0);
  }

  /// Returns the lowest-numbered bit that is on for cells at the given level.
  static int _lowestOnBitForLevel(int level) {
    return 1 << (2 * (maxLevel - level));
  }

  static int _parentAsInt(int id, int level) {
    int newLsb = _lowestOnBitForLevel(level);
    return (id & -newLsb) | newLsb;
  }

  static int _lowestOnBit(int id) {
    // Dart's int is signed, so we use bitwise operations
    return id & -id;
  }

  static int _rangeMinAsInt(int id) {
    return id - (_lowestOnBit(id) - 1);
  }

  static int _rangeMaxAsInt(int id) {
    return id + (_lowestOnBit(id) - 1);
  }

  static int _childBeginAsInt(int id) {
    int oldLsb = _lowestOnBit(id);
    return id - oldLsb + (oldLsb >>> 2);
  }

  static int _childEndAsInt(int id) {
    int oldLsb = _lowestOnBit(id);
    return id + oldLsb + (oldLsb >>> 2);
  }

  /// Returns true if the given id is a valid S2Cell id.
  static bool isValidId(int id) {
    return faceFromId(id) < numFaces &&
        ((_lowestOnBit(id) & 0x1555555555555555) != 0);
  }

  /// Returns the face from an id.
  static int faceFromId(int id) {
    return id >>> posBits;
  }

  /// Which cube face this cell belongs to (0..5).
  int get face => id >>> posBits;

  /// The position along the Hilbert curve.
  int get pos => id & (-1 >>> faceBits);

  /// Return the subdivision level of the cell (0..MAX_LEVEL).
  int get level {
    if (isLeaf) return maxLevel;
    return maxLevel - ((_lowestOnBit(id).bitLength - 1) >> 1);
  }

  /// Return true if this is a valid cell.
  bool get isValid => isValidId(id);

  /// Return true if this is a leaf cell.
  bool get isLeaf => (id & 1) != 0;

  /// Return true if this is a top-level face cell.
  bool get isFace => (id & (_lowestOnBitForLevel(0) - 1)) == 0;

  /// Return the child position (0..3) of this cell within its parent.
  int get childPosition => childPositionAtLevel(level);

  /// Return the child position at the given level.
  int childPositionAtLevel(int level) {
    return (id >>> (2 * (maxLevel - level) + 1)) & 3;
  }

  /// Returns the start of the range of cell ids contained within this cell.
  S2CellId get rangeMin => S2CellId(_rangeMinAsInt(id));

  /// Returns the end of the range of cell ids contained within this cell.
  S2CellId get rangeMax => S2CellId(_rangeMaxAsInt(id));

  /// Return true if the given cell is contained within this one.
  bool contains(S2CellId other) {
    assert(isValid);
    assert(other.isValid);
    return _unsignedLessOrEquals(_rangeMinAsInt(id), other.id) &&
        _unsignedLessOrEquals(other.id, _rangeMaxAsInt(id));
  }

  /// Returns true if the given cell intersects this one.
  bool intersects(S2CellId other) {
    assert(isValid);
    assert(other.isValid);
    return _unsignedLessOrEquals(_rangeMinAsInt(other.id), _rangeMaxAsInt(id)) &&
        _unsignedLessOrEquals(_rangeMinAsInt(id), _rangeMaxAsInt(other.id));
  }

  /// Return the cell id of this cell's parent at the previous level.
  S2CellId get parent {
    assert(isValid);
    assert(level > 0);
    int newLsb = _lowestOnBit(id) << 2;
    return S2CellId((id & -newLsb) | newLsb);
  }

  /// Return the cell id of this cell's parent at the given level.
  S2CellId parentAtLevel(int level) {
    assert(isValid);
    assert(level >= 0 && level <= this.level);
    return S2CellId(_parentAsInt(id, level));
  }

  /// Returns the immediate child at the given traversal order position (0..3).
  S2CellId child(int position) {
    assert(isValid);
    assert(!isLeaf);
    int newLsb = _lowestOnBit(id) >>> 2;
    return S2CellId(id + (2 * position + 1 - 4) * newLsb);
  }

  /// Returns the first child in a traversal of the children of this cell.
  S2CellId get childBegin {
    assert(isValid);
    assert(level < maxLevel);
    return S2CellId(_childBeginAsInt(id));
  }

  /// Returns the first cell after a traversal of the children of this cell.
  S2CellId get childEnd {
    assert(isValid);
    assert(level < maxLevel);
    return S2CellId(_childEndAsInt(id));
  }

  /// Return the next cell at the same level along the Hilbert curve.
  S2CellId get next => S2CellId(id + (_lowestOnBit(id) << 1));

  /// Return the previous cell at the same level along the Hilbert curve.
  S2CellId get prev => S2CellId(id - (_lowestOnBit(id) << 1));

  /// Returns the center of the cell as an S2Point.
  S2Point toPoint() => toPointRaw().normalize();

  /// Returns the direction vector corresponding to the center of the cell.
  S2Point toPointRaw() {
    assert(isValid);
    final center = _getCenterSiTi();
    final si = center >> 32;
    final ti = center & 0xFFFFFFFF;
    return S2Projections.faceSiTiToXyz(face, si, ti);
  }

  int _getCenterSiTi() {
    final ijo = _toIJOrientation();
    final i = ijo >> 33;
    final j = (ijo >> 2) & 0x7FFFFFFF;
    int delta = isLeaf ? 1 : (((i ^ ((id) >>> 2)) & 1) != 0) ? 2 : 0;
    return ((2 * i + delta) << 32) | ((2 * j + delta) & 0xFFFFFFFF);
  }

  int _toIJOrientation() {
    int face = this.face;
    int bits = (face & _swapMask);
    int i = 0;
    int j = 0;

    for (int k = 7; k >= 0; --k) {
      final nbits = (k == 7) ? (maxLevel - 7 * _lookupBits) : _lookupBits;
      bits += ((id >>> (k * 2 * _lookupBits + 1)) & ((1 << (2 * nbits)) - 1)) << 2;
      bits = _lookupIJ[bits];
      i += (bits >> (_lookupBits + 2)) << (k * _lookupBits);
      j += ((bits >> 2) & _lookupMask) << (k * _lookupBits);
      bits = _maskBits(bits);
    }

    if ((_lowestOnBit(id) & 0x1111111111111110) != 0) {
      bits ^= S2.swapMask;
    }

    return (i << 33) | (j << 2) | bits;
  }

  /// Return the S2LatLng corresponding to the center of this cell.
  S2LatLng toLatLng() => S2LatLng.fromPoint(toPointRaw());

  /// Returns the edge length of cells at the given level in (i,j)-space.
  static int getSizeIJ(int level) => 1 << (maxLevel - level);

  /// Returns the edge length of this cell in (i,j)-space.
  int get sizeIJ => getSizeIJ(level);

  /// Returns the i coordinate of this cell.
  int get i => _toIJOrientation() >> 33;

  /// Returns the j coordinate of this cell.
  int get j => (_toIJOrientation() >> 2) & 0x7FFFFFFF;

  /// Encodes the cell id to a compact text string.
  String toToken() {
    if (id == 0) return 'X';

    String hex = id.toRadixString(16).toLowerCase();
    // Pad to 16 characters
    hex = hex.padLeft(16, '0');
    // Trim trailing zeros
    int len = hex.length;
    while (len > 0 && hex[len - 1] == '0') {
      len--;
    }
    return hex.substring(0, len);
  }

  /// Decodes the cell id from a compact text string.
  static S2CellId fromToken(String token) {
    if (token.isEmpty || token == 'X') {
      return none;
    }
    if (token.length > 16) {
      return none;
    }

    // Pad with trailing zeros to make 16 characters
    String padded = token.padRight(16, '0');

    try {
      int value = int.parse(padded, radix: 16);
      return S2CellId(value);
    } catch (e) {
      return none;
    }
  }

  /// Returns true if the given token represents a valid cell id.
  static bool isValidToken(String token) {
    return fromToken(token).isValid;
  }

  // Unsigned comparison helpers
  static bool _unsignedLessThan(int x1, int x2) {
    return (x1 ^ (1 << 63)) < (x2 ^ (1 << 63));
  }

  static bool _unsignedLessOrEquals(int x1, int x2) {
    return (x1 ^ (1 << 63)) <= (x2 ^ (1 << 63));
  }

  static bool _unsignedGreaterThan(int x1, int x2) {
    return (x1 ^ (1 << 63)) > (x2 ^ (1 << 63));
  }

  /// Returns true if this cell id is less than other (unsigned comparison).
  bool lessThan(S2CellId other) => _unsignedLessThan(id, other.id);

  /// Returns true if this cell id is greater than other (unsigned comparison).
  bool greaterThan(S2CellId other) => _unsignedGreaterThan(id, other.id);

  @override
  bool operator ==(Object other) {
    if (other is S2CellId) {
      return id == other.id;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  int compareTo(S2CellId other) {
    if (_unsignedLessThan(id, other.id)) return -1;
    if (_unsignedGreaterThan(id, other.id)) return 1;
    return 0;
  }

  @override
  String toString() => '(face=$face, pos=${pos.toRadixString(16)}, level=$level)';

  /// Returns the (i, j, orientation) packed into a single int.
  /// Format: (i << 33) | (orientation << 1) | (j << 2)
  int toIJOrientation() => _toIJOrientation();

  /// Returns the center of the cell in (u,v) coordinates.
  R2Vector getCenterUV() {
    final centerSiTi = _getCenterSiTi();
    final si = centerSiTi >>> 32;
    final ti = centerSiTi & 0xFFFFFFFF;
    return R2Vector(
      S2Projections.stToUV(S2Projections.siTiToSt(si)),
      S2Projections.stToUV(S2Projections.siTiToSt(ti)),
    );
  }

  /// The 6 face cells.
  static final List<S2CellId> faceCells = List.generate(6, (i) => S2CellId.fromFace(i));

  /// Appends to results the cell ids of the four cells at the given level
  /// that share a vertex with this cell.
  void getVertexNeighbors(int level, List<S2CellId> results) {
    // Determine the i,j coordinates of the vertex closest to this cell center.
    final ijo = _toIJOrientation();
    final i = ijo >>> 33;
    final j = (ijo >> 2) & 0x7FFFFFFF;
    final halfSize = getSizeIJ(level + 1);
    final size = halfSize << 1;

    // Determine which vertex this cell shares with the neighboring cells.
    final iOffset = ((i & halfSize) != 0) ? 1 : -1;
    final jOffset = ((j & halfSize) != 0) ? 1 : -1;

    results.add(parent(level));
    results.add(S2CellId._fromFaceIJSame(
        face, i + iOffset * size, j, i + iOffset * size >= 0)
        .parent(level));
    results.add(S2CellId._fromFaceIJSame(
        face, i, j + jOffset * size, j + jOffset * size >= 0)
        .parent(level));
    results.add(S2CellId._fromFaceIJSame(
        face, i + iOffset * size, j + jOffset * size,
        i + iOffset * size >= 0 && j + jOffset * size >= 0)
        .parent(level));
  }

  /// Returns an S2CellId from face and (i, j) coordinates.
  /// If sameCell is false, wraps around to neighboring faces.
  static S2CellId _fromFaceIJSame(int face, int i, int j, bool sameCell) {
    if (sameCell) {
      return fromFaceIJ(face, i, j);
    } else {
      // TODO: implement face wrapping for edge cases
      return fromFaceIJ(face, i.clamp(0, _maxSize - 1), j.clamp(0, _maxSize - 1));
    }
  }
}

