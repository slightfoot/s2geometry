// Copyright 2018 Google Inc. All Rights Reserved.
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

import 'dart:math' as math;

import 'encoded_ints.dart';
import 'primitive_arrays.dart';
import 's2_cell_id.dart';
import 's2_cell_id_vector.dart';
import 's2_coder.dart';
import 'uint_vector_coder.dart';

/// An encoder/decoder of Lists of [S2CellId]s.
class S2CellIdVectorCoder extends S2Coder<List<S2CellId>> {
  /// An instance of an [S2CellIdVectorCoder].
  static final S2CellIdVectorCoder INSTANCE = S2CellIdVectorCoder._();

  S2CellIdVectorCoder._();

  /// Encodes the given list of S2CellId values.
  ///
  /// The encoding format is as follows:
  ///
  /// - byte 0, bits 0-2: baseBytes
  /// - byte 0, bits 3-7: shift
  /// - byte 1: extended shift (only written for odd shift >= 5)
  /// - 0-7 bytes: base
  /// - values.size() bytes: encoded uint64s of deltas
  @override
  List<int> encode(List<S2CellId> values) {
    int valuesOr = 0;
    int valuesAnd = -1; // ~0L equivalent
    int valuesMin = -1; // ~0L unsigned
    int valuesMax = 0;

    for (final cellId in values) {
      valuesOr |= cellId.id;
      valuesAnd &= cellId.id;
      valuesMin = _unsignedMin(valuesMin, cellId.id);
      valuesMax = _unsignedMax(valuesMax, cellId.id);
    }

    int base = 0;
    int baseBytes = 0;
    int shift = 0;
    int maxDeltaMsb = 0;

    if (_unsignedCompare(valuesOr, 0) > 0) {
      // We only allow even shift, unless all values have the same low bit.
      shift = math.min(56, _numberOfTrailingZeros(valuesOr) & ~1);
      if ((valuesAnd & (1 << shift)) != 0) {
        // All S2CellIds are at the same level.
        shift++;
      }

      // base consists of the baseBytes most-significant bytes of the minimum S2CellId.
      int minBytes = -1;
      for (int tmpBaseBytes = 0; tmpBaseBytes < 8; tmpBaseBytes++) {
        // The base value being tested (first tmpBaseBytes of valuesMin).
        int tmpBase = valuesMin & ~(-1 >>> (8 * tmpBaseBytes));
        // The most-significant bit position of the largest delta.
        int tmpMaxDeltaMsb = math.max(0, 63 - _numberOfLeadingZeros((valuesMax - tmpBase) >>> shift));
        // The total size of the variable portion of the encoding.
        int candidateBytes = tmpBaseBytes + values.length * ((tmpMaxDeltaMsb >> 3) + 1);

        if (_unsignedCompare(candidateBytes, minBytes) < 0) {
          base = tmpBase;
          baseBytes = tmpBaseBytes;
          maxDeltaMsb = tmpMaxDeltaMsb;
          minBytes = candidateBytes;
        }
      }
      // It takes one extra byte to encode odd shifts.
      if (((shift & 1) != 0) && (maxDeltaMsb & 7) != 7) {
        shift--;
      }
    }
    assert(shift <= 56);

    final output = <int>[];

    // shift and baseBytes are encoded in 1 or 2 bytes.
    int shiftCode = shift >> 1;
    if ((shift & 1) != 0) {
      shiftCode = math.min(31, shiftCode + 29);
    }
    output.add((shiftCode << 3) | baseBytes);
    if (shiftCode == 31) {
      output.add(shift >> 1);
    }

    // Encode the baseBytes most-significant bytes of base.
    int baseCode = base >>> (64 - 8 * math.max(1, baseBytes));
    EncodedInts.encodeUintWithLength(output, baseCode, baseBytes);

    // Encode the vector of deltas.
    final tmpBase = base;
    final tmpShift = shift;
    final deltasLongs = _DeltasLongs(values, tmpBase, tmpShift);
    final encodedDeltas = UintVectorCoder.UINT64.encode(deltasLongs);
    output.addAll(encodedDeltas);

    return output;
  }

  @override
  S2CellIdVector decode(Bytes data, Cursor cursor) {
    try {
      return _decodeInternal(data, cursor);
    } on RangeError catch (e) {
      throw FormatException('Insufficient or invalid input bytes: $e');
    }
  }

  S2CellIdVector _decodeInternal(Bytes data, Cursor cursor) {
    // Invert the encoding of (shiftCode, baseBytes).
    int shiftCodeBaseBytes = data.get(cursor.position++) & 0xff;
    int shiftCode = shiftCodeBaseBytes >> 3;
    if (shiftCode == 31) {
      shiftCode = 29 + (data.get(cursor.position++) & 0xff);
    }

    // Decode the baseBytes most-significant bytes of base.
    int baseBytes = shiftCodeBaseBytes & 7;
    int base = data.readUintWithLength(cursor, baseBytes);
    base <<= 64 - 8 * math.max(1, baseBytes);

    // Invert the encoding of shiftCode.
    int shift;
    if (shiftCode >= 29) {
      shift = 2 * (shiftCode - 29) + 1;
      base |= 1 << (shift - 1);
    } else {
      shift = 2 * shiftCode;
    }

    final tmpBase = base;
    final deltas = UintVectorCoder.UINT64.decode(data, cursor);
    return _DecodedS2CellIdVector(deltas, shift, tmpBase);
  }

  @override
  bool get isLazy => true;

  /// Unsigned comparison of two 64-bit integers.
  static int _unsignedCompare(int a, int b) {
    // Convert to unsigned comparison using BigInt
    final ua = BigInt.from(a).toUnsigned(64);
    final ub = BigInt.from(b).toUnsigned(64);
    return ua.compareTo(ub);
  }

  /// Unsigned minimum of two 64-bit integers.
  static int _unsignedMin(int a, int b) {
    return _unsignedCompare(a, b) <= 0 ? a : b;
  }

  /// Unsigned maximum of two 64-bit integers.
  static int _unsignedMax(int a, int b) {
    return _unsignedCompare(a, b) >= 0 ? a : b;
  }

  /// Returns the number of trailing zeros in a 64-bit value.
  static int _numberOfTrailingZeros(int value) {
    if (value == 0) return 64;
    int n = 0;
    if ((value & 0xFFFFFFFF) == 0) {
      n += 32;
      value >>>= 32;
    }
    if ((value & 0xFFFF) == 0) {
      n += 16;
      value >>>= 16;
    }
    if ((value & 0xFF) == 0) {
      n += 8;
      value >>>= 8;
    }
    if ((value & 0xF) == 0) {
      n += 4;
      value >>>= 4;
    }
    if ((value & 0x3) == 0) {
      n += 2;
      value >>>= 2;
    }
    if ((value & 0x1) == 0) {
      n += 1;
    }
    return n;
  }

  /// Returns the number of leading zeros in a 64-bit unsigned integer.
  static int _numberOfLeadingZeros(int value) {
    if (value == 0) return 64;
    int n = 0;
    if ((value >>> 32) == 0) {
      n += 32;
      value <<= 32;
    }
    if ((value >>> 48) == 0) {
      n += 16;
      value <<= 16;
    }
    if ((value >>> 56) == 0) {
      n += 8;
      value <<= 8;
    }
    if ((value >>> 60) == 0) {
      n += 4;
      value <<= 4;
    }
    if ((value >>> 62) == 0) {
      n += 2;
      value <<= 2;
    }
    if ((value >>> 63) == 0) {
      n += 1;
    }
    return n;
  }
}

/// Helper class to lazily compute deltas for encoding.
class _DeltasLongs extends Longs {
  final List<S2CellId> _values;
  final int _base;
  final int _shift;

  _DeltasLongs(this._values, this._base, this._shift);

  @override
  int get(int position) {
    return (_values[position].id - _base) >>> _shift;
  }

  @override
  int get length => _values.length;
}

/// Decoded S2CellIdVector that lazily decodes cells.
class _DecodedS2CellIdVector extends S2CellIdVector {
  final Longs _deltas;
  final int _shift;
  final int _base;

  _DecodedS2CellIdVector(this._deltas, this._shift, this._base);

  @override
  int get length => _deltas.length;

  @override
  S2CellId operator [](int index) {
    return S2CellId((_deltas.get(index) << _shift) + _base);
  }

  @override
  int lowerBound(S2CellId target) {
    if (S2CellIdVectorCoder._unsignedCompare(target.id, _base) <= 0) {
      return 0;
    }
    if (target.greaterOrEquals(S2CellId.end(S2CellId.maxLevel))) {
      return length;
    }
    int low = 0;
    int high = _deltas.length;
    int needle = (target.id - _base + (1 << _shift) - 1) >>> _shift;

    // Binary search for the index of the first element in deltas that is >= needle.
    while (low < high) {
      int mid = (low + high) >> 1;
      int value = _deltas.get(mid);
      if (S2CellIdVectorCoder._unsignedCompare(value, needle) < 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

