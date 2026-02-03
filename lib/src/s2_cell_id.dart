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

  /// Public version for external use.
  static int lowestOnBitForLevel(int level) => _lowestOnBitForLevel(level);

  static int _parentAsInt(int id, int level) {
    int newLsb = _lowestOnBitForLevel(level);
    return (id & -newLsb) | newLsb;
  }

  static int _lowestOnBit(int id) {
    // Dart's int is signed, so we use bitwise operations
    return id & -id;
  }

  /// Returns the lowest-numbered bit that is on for this cell.
  int get lowestOnBit => _lowestOnBit(id);

  /// Computes the level from the lowest on bit.
  static int _levelForLowestOnBit(int id) {
    final lsb = _lowestOnBit(id);
    return maxLevel - ((lsb.bitLength - 1) >> 1);
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

  /// Returns the first descendant at the given level.
  S2CellId childBeginAtLevel(int level) {
    assert(isValid);
    assert(level >= this.level && level <= maxLevel);
    return S2CellId((id - lowestOnBit) | lowestOnBitForLevel(level));
  }

  /// Returns the first cell after a traversal of the children of this cell.
  S2CellId get childEnd {
    assert(isValid);
    assert(level < maxLevel);
    return S2CellId(_childEndAsInt(id));
  }

  /// Returns the first cell after all descendants at the given level.
  S2CellId childEndAtLevel(int level) {
    assert(isValid);
    assert(level >= this.level && level <= maxLevel);
    return S2CellId((id + lowestOnBit) | lowestOnBitForLevel(level));
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

  // Static methods for working with raw cell id integers (used by S2CellUnion).

  /// Returns true if the given id represents a face cell.
  static bool isFaceId(int id) => (id & (_lowestOnBit(id) - 1)) == 0 && _levelForLowestOnBit(id) == 0;

  /// Returns the parent cell id as an integer.
  static int parentId(int id) {
    final newLsb = _lowestOnBit(id) << 2;
    return (id & (~newLsb + 1)) | newLsb;
  }

  /// Returns the range minimum cell id as an integer.
  static int rangeMinId(int id) => id - (_lowestOnBit(id) - 1);

  /// Returns the range maximum cell id as an integer.
  static int rangeMaxId(int id) => id + (_lowestOnBit(id) - 1);

  /// Unsigned less-than comparison for two cell id integers.
  static bool unsignedLessThan(int x1, int x2) => _unsignedLessThan(x1, x2);

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

  /// Returns true if this cell id is less than or equal to other.
  bool lessOrEquals(S2CellId other) => _unsignedLessOrEquals(id, other.id);

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

    results.add(parentAtLevel(level));
    results.add(_fromFaceIJSame(
        face, i + iOffset * size, j, i + iOffset * size >= 0)
        .parentAtLevel(level));
    results.add(_fromFaceIJSame(
        face, i, j + jOffset * size, j + jOffset * size >= 0)
        .parentAtLevel(level));
    results.add(_fromFaceIJSame(
        face, i + iOffset * size, j + jOffset * size,
        i + iOffset * size >= 0 && j + jOffset * size >= 0)
        .parentAtLevel(level));
  }

  /// Returns an S2CellId from face and (i, j) coordinates.
  /// If sameCell is false, wraps around to neighboring faces.
  static S2CellId _fromFaceIJSame(int face, int i, int j, bool sameCell) {
    if (sameCell) {
      return S2CellId.fromFaceIJ(face, i, j);
    } else {
      // TODO: implement face wrapping for edge cases
      return S2CellId.fromFaceIJ(face, i.clamp(0, maxSize - 1), j.clamp(0, maxSize - 1));
    }
  }

  /// Returns true if this cell contains the given cell id.
  bool containsCellId(S2CellId other) {
    return other.greaterOrEquals(rangeMin) && other.lessOrEquals(rangeMax);
  }

  /// Returns true if this cell id is greater than or equal to other.
  bool greaterOrEquals(S2CellId other) => !lessThan(other);

  /// Returns the edge neighbors of this cell (the 4 cells that share an edge).
  ///
  /// The neighbors are returned in the order defined by S2Cell::GetEdge.
  /// All neighbors are guaranteed to be distinct.
  void getEdgeNeighbors(List<S2CellId> neighbors) {
    assert(neighbors.length >= 4);
    final level = this.level;
    final size = getSizeIJ(level);
    final ijo = _toIJOrientation();
    final i = ijo >>> 33;
    final j = (ijo >> 2) & 0x7FFFFFFF;
    final face = this.face;

    // Edges 0, 1, 2, 3 are bottom, right, top, left respectively.
    neighbors[0] = S2CellId._fromFaceIJSame(face, i, j - size, j - size >= 0)
        .parentAtLevel(level);
    neighbors[1] = S2CellId._fromFaceIJSame(face, i + size, j, i + size < maxSize)
        .parentAtLevel(level);
    neighbors[2] = S2CellId._fromFaceIJSame(face, i, j + size, j + size < maxSize)
        .parentAtLevel(level);
    neighbors[3] = S2CellId._fromFaceIJSame(face, i - size, j, i - size >= 0)
        .parentAtLevel(level);
  }

  /// Returns the level of the lowest common ancestor of this cell and the
  /// given cell. Returns -1 if the two cells have no common ancestor
  /// (i.e. they are on different faces of the cube).
  int getCommonAncestorLevel(S2CellId other) {
    // Basically we find the first bit position at which the two S2CellIds
    // differ and compute the level from that.
    int bits = id ^ other.id;

    if (bits == 0) {
      // Same cell.
      return level;
    }

    // We need to find the most significant bit that differs.
    // First, handle the face bits. If faces differ, no common ancestor.
    if (face != other.face) {
      return -1;
    }

    // Find the most significant bit that differs.
    int msbPos = 63 - _numberOfLeadingZeros(bits);

    // The level is computed from the bit position. Each level uses 2 bits,
    // and the lowest bit is the sentinel.
    // Bit positions: 63-62-61 are face (3 bits), then pairs of bits for each level.
    // Level 0 uses bits 60-61, level 1 uses 58-59, etc.
    // The sentinel bit is at position (60 - 2*level).

    // msbPos tells us where the first difference is.
    // If msbPos > 60, they're on different faces (already handled).
    // Otherwise, the common ancestor level is floor((60 - msbPos) / 2).
    if (msbPos > 60) {
      return -1;
    }
    return (60 - msbPos) ~/ 2;
  }

  /// Returns the number of leading zeros in the binary representation.
  static int _numberOfLeadingZeros(int x) {
    if (x == 0) return 64;
    int n = 0;
    // Check high 32 bits
    if ((x >>> 32) == 0) { n += 32; x <<= 32; }
    if ((x >>> 48) == 0) { n += 16; x <<= 16; }
    if ((x >>> 56) == 0) { n +=  8; x <<=  8; }
    if ((x >>> 60) == 0) { n +=  4; x <<=  4; }
    if ((x >>> 62) == 0) { n +=  2; x <<=  2; }
    if ((x >>> 63) == 0) { n +=  1; }
    return n;
  }

  /// Appends all neighbors of this cell at the given level to [results].
  ///
  /// Two cells are neighbors if they share an edge or a corner, i.e. if their
  /// boundaries intersect. Note that a cell is always a neighbor of itself.
  void getAllNeighbors(int level, List<S2CellId> results) {
    final ijo = _toIJOrientation();
    int i = ijo >>> 33;
    int j = (ijo >> 2) & 0x7FFFFFFF;

    // Size at this cell's level.
    final size = getSizeIJ(this.level);
    // Size at requested level.
    final sizeAtLevel = getSizeIJ(level);

    // We need to handle the following cases:
    // 1. level < this.level - parent/ancestor
    // 2. level == this.level - same level
    // 3. level > this.level - children

    // Snap i and j to requested level grid.
    i &= -sizeAtLevel;
    j &= -sizeAtLevel;

    // Generate all neighbors at the given level.
    // First, add neighbors along edges.
    for (int di = -sizeAtLevel; di <= size; di += sizeAtLevel) {
      _appendNeighbor(i + di, j - sizeAtLevel, level, results); // bottom
      _appendNeighbor(i + di, j + size, level, results);       // top
    }
    for (int dj = 0; dj < size; dj += sizeAtLevel) {
      _appendNeighbor(i - sizeAtLevel, j + dj, level, results); // left
      _appendNeighbor(i + size, j + dj, level, results);        // right
    }
  }

  void _appendNeighbor(int i, int j, int level, List<S2CellId> results) {
    // Clamp to valid range and avoid duplicates from edge wrapping.
    if (i < 0 || i >= maxSize || j < 0 || j >= maxSize) {
      // TODO: proper face wrapping
      return;
    }
    final neighbor = S2CellId.fromFaceIJ(face, i, j).parentAtLevel(level);
    results.add(neighbor);
  }
}

