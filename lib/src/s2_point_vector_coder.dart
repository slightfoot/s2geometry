// Copyright 2019 Google Inc. All Rights Reserved.
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

import 'dart:typed_data';
import 'dart:math' as math;

import 'encoded_ints.dart';
import 'primitive_arrays.dart';
import 's2_cell_id.dart';
import 's2_coder.dart';
import 's2_point.dart';
import 's2_projections.dart';
import 'uint_vector_coder.dart';
import 'vector_coder.dart';

/// An encoder/decoder of Lists of [S2Point]s.
///
/// Values from the List of [S2Point] returned by [decode] are decoded only when
/// they are accessed. This allows for very fast initialization and no additional
/// memory use beyond the encoded data.
class S2PointVectorCoder extends S2Coder<List<S2Point>> {
  /// An instance of S2PointVectorCoder which encodes/decodes S2Points in the
  /// FAST encoding format. The FAST format is optimized for fast encoding/decoding.
  static final S2PointVectorCoder FAST = S2PointVectorCoder._(_Format.fast);

  /// An instance of S2PointVectorCoder which encodes/decodes S2Points in the
  /// COMPACT encoding format. The COMPACT format is optimized for disk usage
  /// and memory footprint.
  static final S2PointVectorCoder COMPACT = S2PointVectorCoder._(_Format.compact);

  /// The value of the FAST encoding format.
  static const int _formatFast = 0;

  /// The value of the COMPACT encoding format.
  static const int _formatCompact = 1;

  /// To save space (especially for vectors of length 0, 1, and 2), the encoding
  /// format is encoded in the low-order 3 bits of the vector size.
  static const int _encodingFormatBits = 3;
  static const int _encodingFormatMask = (1 << _encodingFormatBits) - 1;

  /// The size of an encoded S2Point in bytes (3 doubles * 8 bytes per double).
  static const int _sizeofS2Point = 3 * 8;

  /// The left shift factor for [_blockSize].
  static const int _blockShift = 4;

  /// S2CellIds are represented in a special 64-bit format and are encoded in
  /// fixed-size blocks. [_blockSize] represents the number of values per block.
  static const int _blockSize = 1 << _blockShift;

  /// The exception value in the COMPACT encoding format.
  static final int _exception = S2CellId.sentinel.id;

  final _Format _type;

  S2PointVectorCoder._(this._type);

  @override
  List<int> encode(List<S2Point> values) {
    final output = <int>[];
    switch (_type) {
      case _Format.fast:
        _encodeFast(values, output);
        break;
      case _Format.compact:
        _encodeCompact(values, output);
        break;
    }
    return output;
  }

  @override
  List<S2Point> decode(Bytes data, Cursor cursor) {
    // Peek at the format but don't advance the decoder.
    int format;
    try {
      format = data.get(cursor.position) & _encodingFormatMask;
    } on RangeError catch (e) {
      throw FormatException('Insufficient input data: $e');
    }

    switch (format) {
      case _formatFast:
        return _decodeFast(data, cursor);
      case _formatCompact:
        return _decodeCompact(data, cursor);
      default:
        throw FormatException('Invalid encoding format: $format');
    }
  }

  @override
  bool get isLazy => true;

  static void _encodeFast(List<S2Point> values, List<int> output) {
    // The encoding format is as follows:
    //   varint64, bits 0-2:  encoding format (UNCOMPRESSED)
    //             bits 3-63: vector size
    //   array of values.size() S2Points in little-endian order
    int sizeFormat = (values.length << _encodingFormatBits) | _formatFast;
    EncodedInts.writeVarint64(output, sizeFormat);
    for (final point in values) {
      _writeDouble(output, point.x);
      _writeDouble(output, point.y);
      _writeDouble(output, point.z);
    }
  }

  static void _writeDouble(List<int> output, double value) {
    final bytes = Float64List(1)..[0] = value;
    final byteData = bytes.buffer.asByteData();
    for (int i = 0; i < 8; i++) {
      output.add(byteData.getUint8(i));
    }
  }

  static List<S2Point> _decodeFast(Bytes data, Cursor cursor) {
    int tmpSize;
    try {
      tmpSize = data.readVarint64(cursor);
    } on RangeError catch (e) {
      throw FormatException('Insufficient input data: $e');
    }

    tmpSize >>= _encodingFormatBits;
    final size = tmpSize;
    if (size < 0) {
      throw FormatException('Invalid input data: size is negative');
    }
    final offset = cursor.position;
    cursor.position += size * _sizeofS2Point;

    return _FastDecodedList(data, offset, size);
  }

  static void _encodeCompact(List<S2Point> values, List<int> output) {
    // 1. Compute (level, face, si, ti) for each point, build a histogram of
    // levels, and determine the optimal level to use for encoding (if any).
    final cellPoints = <_CellPoint>[];
    final level = _chooseBestLevel(values, cellPoints);
    if (level < 0) {
      _encodeFast(values, output);
      return;
    }

    // 2. Convert the points into encodable 64-bit values.
    final cellPointValues = _convertCellsToValues(cellPoints, level);
    final haveExceptions = cellPointValues.contains(_exception);

    // 3. Choose the global encoding parameter "base".
    final base = _chooseBase(cellPointValues, level, haveExceptions);

    // Now encode the output, starting with the 2-byte header.
    final numBlocks = (cellPointValues.length + _blockSize - 1) >> _blockShift;
    final baseBytes = base.baseBits >> 3;
    final lastBlockCount = cellPointValues.length - _blockSize * (numBlocks - 1);
    assert(lastBlockCount >= 0);
    assert(lastBlockCount <= _blockSize);
    assert(baseBytes <= 7);
    assert(level <= 30);
    output.add(_formatCompact | ((haveExceptions ? 1 : 0) << 3) | ((lastBlockCount - 1) << 4));
    output.add(baseBytes | (level << 3));

    // Next we encode 0-7 bytes of "base".
    final baseShift = _baseShift(level, base.baseBits);
    EncodedInts.encodeUintWithLength(output, base.base >>> baseShift, baseBytes);

    // Now we encode the contents of each block.
    final blocks = <List<int>>[];
    final exceptions = <S2Point>[];
    final code = _MutableBlockCode();
    for (int i = 0; i < cellPointValues.length; i += _blockSize) {
      final blockSize = math.min(_blockSize, cellPointValues.length - i);
      _getBlockCode(
          code, cellPointValues.sublist(i, i + blockSize), base.base, haveExceptions);

      // Encode the one-byte block header.
      final block = <int>[];
      final offsetBytes = code.offsetBits >> 3;
      final deltaNibbles = code.deltaBits >> 2;
      final overlapNibbles = code.overlapBits >> 2;
      assert((offsetBytes - overlapNibbles) <= 7);
      assert(overlapNibbles <= 1);
      assert(deltaNibbles <= 16);
      block.add((offsetBytes - overlapNibbles) | (overlapNibbles << 3) | (deltaNibbles - 1) << 4);

      // Determine the offset for this block, and whether there are exceptions.
      int offset = -1; // Max unsigned
      int numExceptions = 0;
      for (int j = 0; j < blockSize; j++) {
        if (cellPointValues[i + j] == _exception) {
          numExceptions += 1;
        } else {
          assert(cellPointValues[i + j] >= base.base);
          offset = _unsignedMin(offset, cellPointValues[i + j] - base.base);
        }
      }
      if (numExceptions == blockSize) {
        offset = 0;
      }

      // Encode the offset.
      final offsetShift = code.deltaBits - code.overlapBits;
      offset &= ~_bitMask(offsetShift);
      assert((offset == 0) == (offsetBytes == 0));
      if (offset > 0) {
        EncodedInts.encodeUintWithLength(block, offset >>> offsetShift, offsetBytes);
      }

      // Encode the deltas, and also gather any exceptions present.
      final deltaBytes = (deltaNibbles + 1) >> 1;
      exceptions.clear();
      for (int j = 0; j < blockSize; j++) {
        int delta;
        if (cellPointValues[i + j] == _exception) {
          delta = exceptions.length;
          exceptions.add(values[i + j]);
        } else {
          assert(_unsignedCompare(cellPointValues[i + j], offset + base.base) >= 0);
          delta = cellPointValues[i + j] - (offset + base.base);
          if (haveExceptions) {
            assert(_unsignedCompare(delta, -1 - _blockSize) <= 0);
            delta += _blockSize;
          }
        }
        assert(_unsignedCompare(delta, _bitMask(code.deltaBits)) <= 0);
        if (((deltaNibbles & 1) != 0) && ((j & 1) != 0)) {
          // Combine this delta with the high-order 4 bits of the previous delta.
          final lastByte = block.removeLast();
          delta = (delta << 4) | (lastByte & 0xf);
        }
        EncodedInts.encodeUintWithLength(block, delta, deltaBytes);
      }
      // Append any exceptions to the end of the block.
      if (numExceptions > 0) {
        for (final p in exceptions) {
          _writeDouble(block, p.x);
          _writeDouble(block, p.y);
          _writeDouble(block, p.z);
        }
      }
      blocks.add(block);
    }
    output.addAll(VectorCoder.BYTE_ARRAY.encode(blocks));
  }

  static List<S2Point> _decodeCompact(Bytes data, Cursor cursor) {
    // First we decode the two-byte header.
    bool haveExceptions;
    int lastBlockCount;
    int baseBytes;
    int level;
    int base;

    try {
      final header1 = data.get(cursor.position++) & 0xFF;
      final header2 = data.get(cursor.position++) & 0xFF;
      if ((header1 & 7) != _formatCompact) {
        throw FormatException('Invalid encoding format.');
      }

      haveExceptions = (header1 & 8) != 0;
      lastBlockCount = (header1 >> 4) + 1;
      baseBytes = header2 & 7;
      level = header2 >> 3;

      // Decode the base value (if any).
      final tmpBase = data.readUintWithLength(cursor, baseBytes);
      base = tmpBase << _baseShift(level, baseBytes << 3);
    } on RangeError catch (e) {
      throw FormatException('Insufficient or invalid input bytes: $e');
    }

    // Initialize the vector of encoded blocks.
    final blockOffsets = UintVectorCoder.UINT64.decode(data, cursor);
    final offset = cursor.position;

    final size = _blockSize * (blockOffsets.length - 1) + lastBlockCount;
    cursor.position += blockOffsets.length > 0 ? blockOffsets.get(blockOffsets.length - 1) : 0;

    return _CompactDecodedList(
        data, blockOffsets, offset, size, haveExceptions, level, base);
  }

  /// Returns a bit mask with n low-order 1 bits, for 0 <= n <= 64.
  static int _bitMask(int n) {
    return (n == 0) ? 0 : (-1 >>> (64 - n));
  }

  /// Returns the maximum number of bits per value at the given S2CellId level.
  static int _maxBitsForLevel(int level) {
    return 2 * level + 3;
  }

  /// Returns the number of bits that base should be right-shifted in order to
  /// encode only its leading baseBits bits.
  static int _baseShift(int level, int baseBits) {
    return math.max(0, _maxBitsForLevel(level) - baseBits);
  }

  /// Returns the S2CellId level for which the greatest number of the given
  /// points can be represented as the center of an S2CellId, or -1 if there
  /// is no S2CellId that would result in significant space savings.
  static int _chooseBestLevel(List<S2Point> points, List<_CellPoint> cellPoints) {
    // Count the number of points at each level.
    final levelCounts = List<int>.filled(S2CellId.maxLevel + 1, 0);
    for (final point in points) {
      final faceSiTi = S2Projections.xyzToFaceSiTi(point);
      final level = S2Projections.levelIfCenter(faceSiTi, point);
      cellPoints.add(_CellPoint(level, faceSiTi));
      if (level >= 0) {
        levelCounts[level]++;
      }
    }
    // Choose the level for which the most points can be encoded.
    int bestLevel = 0;
    for (int level = 1; level <= S2CellId.maxLevel; level++) {
      if (levelCounts[level] > levelCounts[bestLevel]) {
        bestLevel = level;
      }
    }
    // The uncompressed encoding is smaller and faster when very few of the
    // points are encodable as S2CellIds.
    const minEncodableFraction = 0.05;
    if (levelCounts[bestLevel] <= minEncodableFraction * points.length) {
      return -1;
    }
    return bestLevel;
  }

  /// Given a vector of points in CellPoint format and an S2CellId level that
  /// has been chosen for encoding, returns a vector of 64-bit values.
  static List<int> _convertCellsToValues(List<_CellPoint> cellPoints, int level) {
    final result = <int>[];
    final shift = S2CellId.maxLevel - level;
    for (final cp in cellPoints) {
      if (cp.level != level) {
        result.add(_exception);
      } else {
        final sj = (((cp.face & 3) << 30) | (cp.si >>> 1)) >>> shift;
        final tj = (((cp.face & 4) << 29) | cp.ti) >>> (shift + 1);
        final v = EncodedInts.interleaveBitPairs(sj, tj);
        assert(_unsignedCompare(v, _bitMask(_maxBitsForLevel(level))) <= 0);
        result.add(v);
      }
    }
    return result;
  }

  /// Returns the global minimum value base and the number of bits for encoding.
  static _Base _chooseBase(List<int> values, int level, bool haveExceptions) {
    // Find the minimum and maximum non-exception values to be represented.
    int vMin = _exception;
    int vMax = 0;
    for (final v in values) {
      if (v != _exception) {
        vMin = _unsignedMin(vMin, v);
        vMax = _unsignedMax(vMax, v);
      }
    }
    if (vMin == _exception) {
      return _Base(0, 0);
    }

    final minDeltaBits = (haveExceptions || values.length == 1) ? 8 : 4;
    final excludedBits = [
      63 - _numberOfLeadingZeros(vMin ^ vMax) + 1,
      minDeltaBits,
      _baseShift(level, 56)
    ].reduce(math.max);
    int base = vMin & ~_bitMask(excludedBits);

    int baseBits = 0;
    if (base != 0) {
      final lowBit = _numberOfTrailingZeros(base);
      baseBits = (_maxBitsForLevel(level) - lowBit + 7) & ~7;
    }

    return _Base(vMin & ~_bitMask(_baseShift(level, baseBits)), baseBits);
  }

  /// Returns true if the range of values [dMin, dMax] can be encoded using the
  /// specified parameters.
  static bool _canEncode(
      int dMin, int dMax, int deltaBits, int overlapBits, bool haveExceptions) {
    dMin &= ~_bitMask(deltaBits - overlapBits);

    int maxDelta = _bitMask(deltaBits);
    if (haveExceptions) {
      if (_unsignedCompare(maxDelta, _blockSize) < 0) {
        return false;
      }
      maxDelta -= _blockSize;
    }
    return (_unsignedCompare(dMin, ~maxDelta) > 0) ||
        (_unsignedCompare(dMin + maxDelta, dMax) >= 0);
  }

  /// Sets the given MutableBlockCode to the optimal encoding parameters.
  static void _getBlockCode(
      _MutableBlockCode code, List<int> values, int base, bool haveExceptions) {
    int bMin = _exception;
    int bMax = 0;
    for (final v in values) {
      if (v != _exception) {
        bMin = _unsignedMin(bMin, v);
        bMax = _unsignedMax(bMax, v);
      }
    }
    if (bMin == _exception) {
      code.set(4, 0, 0);
      return;
    }

    bMin -= base;
    bMax -= base;

    int deltaBits = (math.max(1, 63 - _numberOfLeadingZeros(bMax - bMin)) + 3) & ~3;
    int overlapBits = 0;
    if (!_canEncode(bMin, bMax, deltaBits, 0, haveExceptions)) {
      if (_canEncode(bMin, bMax, deltaBits, 4, haveExceptions)) {
        overlapBits = 4;
      } else {
        assert(deltaBits <= 60);
        deltaBits += 4;
        if (!_canEncode(bMin, bMax, deltaBits, 0, haveExceptions)) {
          assert(_canEncode(bMin, bMax, deltaBits, 4, haveExceptions));
          overlapBits = 4;
        }
      }
    }

    if (values.length == 1 && !haveExceptions) {
      assert(deltaBits == 4 && overlapBits == 0);
      deltaBits = 8;
    }

    int maxDelta = _bitMask(deltaBits) - (haveExceptions ? _blockSize : 0);
    int offsetBits = 0;
    if (_unsignedCompare(bMax, maxDelta) > 0) {
      final offsetShift = deltaBits - overlapBits;
      final mask = _bitMask(offsetShift);
      final minOffset = (bMax - maxDelta + mask) & ~mask;
      assert(minOffset != 0);
      offsetBits = ((63 - _numberOfLeadingZeros(minOffset)) + 1 - offsetShift + 7) & ~7;
      if (offsetBits == 64) {
        overlapBits = 4;
      }
    }
    code.set(deltaBits, offsetBits, overlapBits);
  }

  // Unsigned comparison helpers
  static int _unsignedCompare(int a, int b) {
    // Dart doesn't have unsigned longs, so we need to handle this specially
    final aSign = a < 0 ? 1 : 0;
    final bSign = b < 0 ? 1 : 0;
    if (aSign != bSign) {
      return aSign - bSign; // Negative (high bit set) is "larger" unsigned
    }
    return a.compareTo(b);
  }

  static int _unsignedMin(int a, int b) {
    return _unsignedCompare(a, b) <= 0 ? a : b;
  }

  static int _unsignedMax(int a, int b) {
    return _unsignedCompare(a, b) >= 0 ? a : b;
  }

  static int _numberOfLeadingZeros(int n) {
    if (n == 0) return 64;
    int count = 0;
    if ((n & 0xFFFFFFFF00000000) == 0) {
      count += 32;
      n <<= 32;
    }
    if ((n & 0xFFFF000000000000) == 0) {
      count += 16;
      n <<= 16;
    }
    if ((n & 0xFF00000000000000) == 0) {
      count += 8;
      n <<= 8;
    }
    if ((n & 0xF000000000000000) == 0) {
      count += 4;
      n <<= 4;
    }
    if ((n & 0xC000000000000000) == 0) {
      count += 2;
      n <<= 2;
    }
    if ((n & 0x8000000000000000) == 0) {
      count += 1;
    }
    return count;
  }

  static int _numberOfTrailingZeros(int n) {
    if (n == 0) return 64;
    int count = 0;
    if ((n & 0xFFFFFFFF) == 0) {
      count += 32;
      n >>>= 32;
    }
    if ((n & 0xFFFF) == 0) {
      count += 16;
      n >>>= 16;
    }
    if ((n & 0xFF) == 0) {
      count += 8;
      n >>>= 8;
    }
    if ((n & 0xF) == 0) {
      count += 4;
      n >>>= 4;
    }
    if ((n & 0x3) == 0) {
      count += 2;
      n >>>= 2;
    }
    if ((n & 0x1) == 0) {
      count += 1;
    }
    return count;
  }
}

enum _Format { fast, compact }

/// Represents the encoding parameters to be used for a given block.
class _MutableBlockCode {
  int deltaBits = 0;
  int offsetBits = 0;
  int overlapBits = 0;

  void set(int deltaBits, int offsetBits, int overlapBits) {
    this.deltaBits = deltaBits;
    this.offsetBits = offsetBits;
    this.overlapBits = overlapBits;
  }
}

/// Return type of _chooseBase.
class _Base {
  final int base;
  final int baseBits;

  _Base(this.base, this.baseBits);
}

/// Represents a point that can be encoded as an S2CellId center.
class _CellPoint {
  final int level;
  final int face;
  final int si;
  final int ti;

  _CellPoint(this.level, FaceSiTi faceSiTi)
      : face = faceSiTi.face,
        si = faceSiTi.si,
        ti = faceSiTi.ti;
}

/// Lazy-decoded list for FAST format.
class _FastDecodedList extends _UnmodifiableListBase<S2Point> {
  final Bytes _data;
  final int _offset;
  final int _size;

  _FastDecodedList(this._data, this._offset, this._size);

  @override
  S2Point operator [](int index) {
    final position = _offset + index * S2PointVectorCoder._sizeofS2Point;
    return S2Point(
      _data.readLittleEndianDouble(position),
      _data.readLittleEndianDouble(position + 8),
      _data.readLittleEndianDouble(position + 16),
    );
  }

  @override
  int get length => _size;
}

/// Lazy-decoded list for COMPACT format.
class _CompactDecodedList extends _UnmodifiableListBase<S2Point> {
  final Bytes _data;
  final Longs _blockOffsets;
  final int _offset;
  final int _size;
  final bool _haveExceptions;
  final int _level;
  final int _base;

  _CompactDecodedList(this._data, this._blockOffsets, this._offset, this._size,
      this._haveExceptions, this._level, this._base);

  @override
  S2Point operator [](int index) {
    // First we decode the block header.
    final iShifted = index >> S2PointVectorCoder._blockShift;
    int position = _offset + ((iShifted == 0) ? 0 : _blockOffsets.get(iShifted - 1));
    final header = _data.get(position++) & 0xFF;
    final overlapNibbles = (header >> 3) & 1;
    final offsetBytes = (header & 7) + overlapNibbles;
    final deltaNibbles = (header >> 4) + 1;

    // Decode the offset for this block.
    int offset = 0;
    if (offsetBytes > 0) {
      final offsetShift = (deltaNibbles - overlapNibbles) << 2;
      offset = _data.readUintWithLength(_data.cursor(position), offsetBytes) << offsetShift;
      position += offsetBytes;
    }

    // Decode the delta for the requested value.
    final deltaNibbleOffset = (index & (S2PointVectorCoder._blockSize - 1)) * deltaNibbles;
    final deltaBytes = (deltaNibbles + 1) >> 1;
    final deltaPosition = position + (deltaNibbleOffset >> 1);
    int delta = _data.readUintWithLength(_data.cursor(deltaPosition), deltaBytes);
    delta >>>= (deltaNibbleOffset & 1) << 2;
    delta &= S2PointVectorCoder._bitMask(deltaNibbles << 2);

    // Test whether this point is encoded as an exception.
    if (_haveExceptions) {
      if (delta < S2PointVectorCoder._blockSize) {
        final blockSize = math.min(
            S2PointVectorCoder._blockSize,
            _size - (index & -S2PointVectorCoder._blockSize));
        int exceptionPosition = position + ((blockSize * deltaNibbles + 1) >> 1);
        exceptionPosition += delta * S2PointVectorCoder._sizeofS2Point;
        return S2Point(
          _data.readLittleEndianDouble(exceptionPosition),
          _data.readLittleEndianDouble(exceptionPosition + 8),
          _data.readLittleEndianDouble(exceptionPosition + 16),
        );
      }
      delta -= S2PointVectorCoder._blockSize;
    }

    // Otherwise convert the 64-bit value back to an S2Point.
    final value = _base + offset + delta;
    final shift = S2CellId.maxLevel - _level;

    final sj = EncodedInts.deinterleaveBitPairs1(value);
    final tj = EncodedInts.deinterleaveBitPairs2(value);
    final si = (((sj << 1) | 1) << shift) & 0x7fffffff;
    final ti = (((tj << 1) | 1) << shift) & 0x7fffffff;
    final face = ((sj << shift) >>> 30) | (((tj << (shift + 1)) >>> 29) & 4);
    return S2Projections.faceUvToXyz(
            face,
            S2Projections.stToUV(S2Projections.siTiToSt(si)),
            S2Projections.stToUV(S2Projections.siTiToSt(ti)))
        .normalize();
  }

  @override
  int get length => _size;
}

/// Base class for unmodifiable lists.
abstract class _UnmodifiableListBase<T> implements List<T> {
  @override
  void operator []=(int index, T value) => throw UnsupportedError('Cannot modify');

  @override
  set length(int newLength) => throw UnsupportedError('Cannot modify');

  @override
  void add(T value) => throw UnsupportedError('Cannot modify');

  @override
  void addAll(Iterable<T> iterable) => throw UnsupportedError('Cannot modify');

  @override
  bool any(bool Function(T) test) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) return true;
    }
    return false;
  }

  @override
  Map<int, T> asMap() => {for (int i = 0; i < length; i++) i: this[i]};

  @override
  List<R> cast<R>() => List.castFrom<T, R>(toList());

  @override
  void clear() => throw UnsupportedError('Cannot modify');

  @override
  bool contains(Object? element) {
    for (int i = 0; i < length; i++) {
      if (this[i] == element) return true;
    }
    return false;
  }

  @override
  T elementAt(int index) => this[index];

  @override
  bool every(bool Function(T) test) {
    for (int i = 0; i < length; i++) {
      if (!test(this[i])) return false;
    }
    return true;
  }

  @override
  Iterable<R> expand<R>(Iterable<R> Function(T) f) sync* {
    for (int i = 0; i < length; i++) {
      yield* f(this[i]);
    }
  }

  @override
  void fillRange(int start, int end, [T? fillValue]) =>
      throw UnsupportedError('Cannot modify');

  @override
  T get first => this[0];

  @override
  set first(T value) => throw UnsupportedError('Cannot modify');

  @override
  T firstWhere(bool Function(T) test, {T Function()? orElse}) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) return this[i];
    }
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  R fold<R>(R initialValue, R Function(R, T) combine) {
    R value = initialValue;
    for (int i = 0; i < length; i++) {
      value = combine(value, this[i]);
    }
    return value;
  }

  @override
  Iterable<T> followedBy(Iterable<T> other) sync* {
    for (int i = 0; i < length; i++) {
      yield this[i];
    }
    yield* other;
  }

  @override
  void forEach(void Function(T) action) {
    for (int i = 0; i < length; i++) {
      action(this[i]);
    }
  }

  @override
  Iterable<T> getRange(int start, int end) sync* {
    for (int i = start; i < end; i++) {
      yield this[i];
    }
  }

  @override
  int indexOf(T element, [int start = 0]) {
    for (int i = start; i < length; i++) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  @override
  int indexWhere(bool Function(T) test, [int start = 0]) {
    for (int i = start; i < length; i++) {
      if (test(this[i])) return i;
    }
    return -1;
  }

  @override
  void insert(int index, T element) => throw UnsupportedError('Cannot modify');

  @override
  void insertAll(int index, Iterable<T> iterable) =>
      throw UnsupportedError('Cannot modify');

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => length != 0;

  @override
  Iterator<T> get iterator => _ListIterator(this);

  @override
  String join([String separator = '']) {
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      if (i > 0) buffer.write(separator);
      buffer.write(this[i]);
    }
    return buffer.toString();
  }

  @override
  T get last => this[length - 1];

  @override
  set last(T value) => throw UnsupportedError('Cannot modify');

  @override
  int lastIndexOf(T element, [int? start]) {
    start ??= length - 1;
    for (int i = start; i >= 0; i--) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  @override
  int lastIndexWhere(bool Function(T) test, [int? start]) {
    start ??= length - 1;
    for (int i = start; i >= 0; i--) {
      if (test(this[i])) return i;
    }
    return -1;
  }

  @override
  T lastWhere(bool Function(T) test, {T Function()? orElse}) {
    for (int i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<R> map<R>(R Function(T) f) sync* {
    for (int i = 0; i < length; i++) {
      yield f(this[i]);
    }
  }

  @override
  T reduce(T Function(T, T) combine) {
    if (isEmpty) throw StateError('No element');
    T value = this[0];
    for (int i = 1; i < length; i++) {
      value = combine(value, this[i]);
    }
    return value;
  }

  @override
  bool remove(Object? value) => throw UnsupportedError('Cannot modify');

  @override
  T removeAt(int index) => throw UnsupportedError('Cannot modify');

  @override
  T removeLast() => throw UnsupportedError('Cannot modify');

  @override
  void removeRange(int start, int end) => throw UnsupportedError('Cannot modify');

  @override
  void removeWhere(bool Function(T) test) =>
      throw UnsupportedError('Cannot modify');

  @override
  void replaceRange(int start, int end, Iterable<T> replacements) =>
      throw UnsupportedError('Cannot modify');

  @override
  void retainWhere(bool Function(T) test) =>
      throw UnsupportedError('Cannot modify');

  @override
  Iterable<T> get reversed sync* {
    for (int i = length - 1; i >= 0; i--) {
      yield this[i];
    }
  }

  @override
  void setAll(int index, Iterable<T> iterable) =>
      throw UnsupportedError('Cannot modify');

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) =>
      throw UnsupportedError('Cannot modify');

  @override
  void shuffle([math.Random? random]) => throw UnsupportedError('Cannot modify');

  @override
  T get single {
    if (length != 1) throw StateError('Not exactly one element');
    return this[0];
  }

  @override
  T singleWhere(bool Function(T) test, {T Function()? orElse}) {
    T? result;
    bool found = false;
    for (int i = 0; i < length; i++) {
      if (test(this[i])) {
        if (found) throw StateError('Too many elements');
        result = this[i];
        found = true;
      }
    }
    if (found) return result as T;
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<T> skip(int count) sync* {
    for (int i = count; i < length; i++) {
      yield this[i];
    }
  }

  @override
  Iterable<T> skipWhile(bool Function(T) test) sync* {
    bool skipping = true;
    for (int i = 0; i < length; i++) {
      if (skipping && test(this[i])) continue;
      skipping = false;
      yield this[i];
    }
  }

  @override
  void sort([int Function(T, T)? compare]) =>
      throw UnsupportedError('Cannot modify');

  @override
  List<T> sublist(int start, [int? end]) {
    end ??= length;
    return [for (int i = start; i < end; i++) this[i]];
  }

  @override
  Iterable<T> take(int count) sync* {
    for (int i = 0; i < count && i < length; i++) {
      yield this[i];
    }
  }

  @override
  Iterable<T> takeWhile(bool Function(T) test) sync* {
    for (int i = 0; i < length; i++) {
      if (!test(this[i])) break;
      yield this[i];
    }
  }

  @override
  List<T> toList({bool growable = true}) {
    return [for (int i = 0; i < length; i++) this[i]];
  }

  @override
  Set<T> toSet() => {for (int i = 0; i < length; i++) this[i]};

  @override
  Iterable<T> where(bool Function(T) test) sync* {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) yield this[i];
    }
  }

  @override
  Iterable<R> whereType<R>() sync* {
    for (int i = 0; i < length; i++) {
      if (this[i] is R) yield this[i] as R;
    }
  }

  @override
  List<T> operator +(List<T> other) => [...toList(), ...other];
}

class _ListIterator<T> implements Iterator<T> {
  final List<T> _list;
  int _index = -1;

  _ListIterator(this._list);

  @override
  T get current => _list[_index];

  @override
  bool moveNext() {
    _index++;
    return _index < _list.length;
  }
}

