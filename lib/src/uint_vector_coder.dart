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

import 'encoded_ints.dart';
import 'primitive_arrays.dart';
import 's2_coder.dart';

/// An encoder/decoder of [Longs]. Either uint64 or uint32 values are supported.
/// Decoding is on-demand, so [S2Coder.isLazy] is true.
class UintVectorCoder extends S2Coder<Longs> {
  /// An instance of an [UintVectorCoder] which encodes/decodes uint32s.
  static final UintVectorCoder UINT32 = UintVectorCoder._(4);

  /// An instance of an [UintVectorCoder] which encodes/decodes uint64s.
  static final UintVectorCoder UINT64 = UintVectorCoder._(8);

  final int _typeBytes;

  UintVectorCoder._(this._typeBytes);

  /// Encodes the given [Longs] into the given list of bytes.
  @override
  List<int> encode(Longs values) {
    final output = <int>[];
    // The encoding format is as follows:
    //
    //   totalBytes (varint64): (values.size() * typeBytes) | (bytesPerWord - 1)
    //   array of values.size() elements [bytesPerWord bytes each]
    //
    // bytesPerWord must be >= 0 so we can encode it in (log2(typeBytes) - 1) bits.

    // oneBits = 1 ensures that bytesPerWord is at least 1.
    int oneBits = 1;
    for (int i = 0; i < values.length; i++) {
      oneBits |= values.get(i);
    }

    // bytesPerWord is the minimum number of bytes required to encode the largest value in values.
    // It is computed by dividing the minimum number of bits required to represent the largest
    // integer in values by 8 (the division by 8 is the unsigned right shift by 3 bits).
    //
    // Examples:
    // - oneBits = ~0: ((63 - 0) >>> 3) + 1 == 8 bytes per word.
    // - oneBits = 4321: ((63 - 51) >>> 3) + 1 == 2 bytes per word.
    // - oneBits = 1: ((63 - 63) >>> 3) + 1 == 1 byte per word.
    int bytesPerWord = ((63 - _numberOfLeadingZeros(oneBits)) >>> 3) + 1;

    // Since totalBytes must be a multiple of typeBytes, and bytesPerWord must be <= totalBytes,
    // (bytesPerWord - 1) can be encoded in the last few bits of totalBytes.
    int totalBytes = (values.length * _typeBytes) | (bytesPerWord - 1);
    EncodedInts.writeVarint64(output, totalBytes);
    for (int i = 0; i < values.length; i++) {
      EncodedInts.encodeUintWithLength(output, values.get(i), bytesPerWord);
    }
    return output;
  }

  /// Returns a [Longs] implementation that on-demand-decodes long values from the
  /// underlying data, starting at [cursor.position]. [cursor.position] is updated
  /// to the position of the first byte in [data] following the encoded values.
  @override
  Longs decode(Bytes data, Cursor cursor) {
    // See encode for documentation on the encoding format.
    int totalBytes;
    int size;
    int bytesPerWord;

    try {
      // readVarint64 throws if data is too short.
      totalBytes = data.readVarint64(cursor);
      if (totalBytes < 0) {
        throw FormatException('Invalid input data, totalBytes = $totalBytes');
      }
      // Check for int overflow.
      size = totalBytes ~/ _typeBytes;
      if (size > 0x7FFFFFFF) {
        throw FormatException('Size too large: $size');
      }
      bytesPerWord = (totalBytes & (_typeBytes - 1)) + 1;
    } on RangeError catch (e) {
      throw FormatException('Input data invalid or too short: $e');
    }
    int offset = cursor.position;

    // Update the position to after these Longs. Position calculations must be 64 bit.
    cursor.position += size * bytesPerWord;

    // Check that the Longs we're going to return won't read past the end of 'data'.
    if (cursor.position > data.length) {
      throw FormatException(
          "Decoding from 'data' with length ${data.length} bytes, but ${cursor.position} bytes are required.");
    }

    final capturedOffset = offset;
    final capturedBytesPerWord = bytesPerWord;
    final capturedSize = size;

    return _DecodedLongs(data, capturedOffset, capturedBytesPerWord, capturedSize);
  }

  @override
  bool get isLazy => true;

  /// Returns the number of leading zeros in a 64-bit unsigned integer.
  static int _numberOfLeadingZeros(int value) {
    if (value == 0) return 64;
    int n = 0;
    // Check upper 32 bits
    if ((value >>> 32) == 0) {
      n += 32;
      value <<= 32;
    }
    // Check upper 16 bits of remaining
    if ((value >>> 48) == 0) {
      n += 16;
      value <<= 16;
    }
    // Check upper 8 bits of remaining
    if ((value >>> 56) == 0) {
      n += 8;
      value <<= 8;
    }
    // Check upper 4 bits of remaining
    if ((value >>> 60) == 0) {
      n += 4;
      value <<= 4;
    }
    // Check upper 2 bits of remaining
    if ((value >>> 62) == 0) {
      n += 2;
      value <<= 2;
    }
    // Check upper bit of remaining
    if ((value >>> 63) == 0) {
      n += 1;
    }
    return n;
  }
}

class _DecodedLongs extends Longs {
  final Bytes _data;
  final int _offset;
  final int _bytesPerWord;
  final int _size;

  _DecodedLongs(this._data, this._offset, this._bytesPerWord, this._size);

  @override
  int get(int position) {
    return _data.readUintWithLengthAt(_offset + position * _bytesPerWord, _bytesPerWord);
  }

  @override
  int get length => _size;
}

