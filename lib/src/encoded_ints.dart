// Copyright 2018 Google Inc.
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

/// Utilities for encoding and decoding integers.
///
/// This class provides utilities for:
/// - Variable-length integer encoding (varint)
/// - ZigZag encoding for signed integers
/// - Bit interleaving for spatial indexing
class EncodedInts {
  EncodedInts._();

  /// Reads a variable-encoded signed 64-bit integer from [bytes] starting at [offset].
  ///
  /// Returns a record containing the decoded value and the number of bytes consumed.
  ///
  /// Note that if you frequently read/write negative numbers, you should consider
  /// zigzag-encoding your values before storing them as varints.
  ///
  /// Throws [FormatException] if the varint is malformed or truncated.
  static (int value, int bytesRead) readVarint64(List<int> bytes, int offset) {
    int result = 0;
    int bytesRead = 0;
    for (int shift = 0; shift < 64; shift += 7) {
      if (offset + bytesRead >= bytes.length) {
        throw FormatException('Truncated varint at offset $offset');
      }
      final b = bytes[offset + bytesRead];
      bytesRead++;
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) {
        return (result, bytesRead);
      }
    }
    throw FormatException('Malformed varint at offset $offset');
  }

  /// Returns the size in bytes of [value] when encoded by [writeVarint64].
  static int varIntSize(int value) {
    int bytes = 0;
    do {
      bytes++;
      value = value >>> 7;
    } while (value != 0);
    return bytes;
  }

  /// Writes a signed 64-bit integer using variable encoding to [bytes].
  ///
  /// Returns the number of bytes written.
  ///
  /// Note that if you frequently read/write negative numbers, you should consider
  /// zigzag-encoding your values before storing them as varints.
  static int writeVarint64(List<int> bytes, int value) {
    int written = 0;
    while (true) {
      if ((value & ~0x7F) == 0) {
        bytes.add(value & 0xFF);
        written++;
        return written;
      } else {
        bytes.add(((value & 0x7F) | 0x80) & 0xFF);
        written++;
        value = value >>> 7;
      }
    }
  }

  /// Decodes an unsigned integer of [bytesPerWord] bytes from [bytes] at [offset]
  /// in little-endian format.
  ///
  /// This method is not compatible with [readVarint64] or [writeVarint64].
  static int decodeUintWithLength(List<int> bytes, int offset, int bytesPerWord) {
    int x = 0;
    for (int i = 0; i < bytesPerWord; i++) {
      x += (bytes[offset + i] & 0xFF) << (8 * i);
    }
    return x;
  }

  /// Encodes an unsigned integer to [bytes] in little-endian format using
  /// [bytesPerWord] bytes.
  ///
  /// This method is not compatible with [readVarint64] or [writeVarint64].
  static void encodeUintWithLength(List<int> bytes, int value, int bytesPerWord) {
    while (--bytesPerWord >= 0) {
      bytes.add(value & 0xFF);
      value = value >>> 8;
    }
    assert(value == 0);
  }

  /// Encode a ZigZag-encoded 32-bit value.
  ///
  /// ZigZag encodes signed integers into values that can be efficiently encoded
  /// with varint. (Otherwise, negative values must be sign-extended to 64 bits
  /// to be varint encoded, thus always taking 10 bytes on the wire.)
  static int encodeZigZag32(int n) {
    // Note: the right-shift must be arithmetic
    return ((n << 1) ^ (n >> 31)) & 0xFFFFFFFF;
  }

  /// Encode a ZigZag-encoded 64-bit value.
  ///
  /// ZigZag encodes signed integers into values that can be efficiently encoded
  /// with varint. (Otherwise, negative values must be sign-extended to 64 bits
  /// to be varint encoded, thus always taking 10 bytes on the wire.)
  static int encodeZigZag64(int n) {
    // Note: the right-shift must be arithmetic
    return (n << 1) ^ (n >> 63);
  }

  /// Decode a ZigZag-encoded 32-bit signed value.
  static int decodeZigZag32(int n) {
    return ((n >>> 1) ^ -(n & 1)) & 0xFFFFFFFF;
  }

  /// Decode a ZigZag-encoded 64-bit signed value.
  static int decodeZigZag64(int n) {
    return (n >>> 1) ^ -(n & 1);
  }

  /// Returns the interleaving of bits of [val1] and [val2], where the LSB of
  /// [val1] is the LSB of the result, and the MSB of [val2] is the MSB of the result.
  static int interleaveBits(int val1, int val2) {
    return _insertBlankBits(val1) | (_insertBlankBits(val2) << 1);
  }

  /// Returns the first int de-interleaved from the result of [interleaveBits].
  static int deinterleaveBits1(int bits) {
    return _removeBlankBits(bits);
  }

  /// Returns the second int de-interleaved from the result of [interleaveBits].
  static int deinterleaveBits2(int bits) {
    return _removeBlankBits(bits >>> 1);
  }

  /// Inserts blank bits between the bits of [value] such that the MSB is blank
  /// and the LSB is unchanged.
  static int _insertBlankBits(int value) {
    // Treat value as unsigned 32-bit by masking
    int bits = value & 0xFFFFFFFF;
    bits = (bits | (bits << 16)) & 0x0000ffff0000ffff;
    bits = (bits | (bits << 8)) & 0x00ff00ff00ff00ff;
    bits = (bits | (bits << 4)) & 0x0f0f0f0f0f0f0f0f;
    bits = (bits | (bits << 2)) & 0x3333333333333333;
    bits = (bits | (bits << 1)) & 0x5555555555555555;
    return bits;
  }

  /// Reverses [_insertBlankBits] by extracting the even bits (bit 0, 2, ...).
  static int _removeBlankBits(int bits) {
    bits &= 0x5555555555555555;
    bits |= bits >>> 1;
    bits &= 0x3333333333333333;
    bits |= bits >>> 2;
    bits &= 0x0f0f0f0f0f0f0f0f;
    bits |= bits >>> 4;
    bits &= 0x00ff00ff00ff00ff;
    bits |= bits >>> 8;
    bits &= 0x0000ffff0000ffff;
    bits |= bits >>> 16;
    return bits & 0xFFFFFFFF;
  }

  /// Like [interleaveBits] but interleaves bit pairs rather than individual bits.
  ///
  /// This format is faster to decode than the fully interleaved format, and
  /// produces the same results for S2 use cases.
  static int interleaveBitPairs(int val1, int val2) {
    return _insertBlankPairs(val1) | (_insertBlankPairs(val2) << 2);
  }

  /// Returns the first int de-interleaved from the result of [interleaveBitPairs].
  static int deinterleaveBitPairs1(int pairs) {
    return _removeBlankPairs(pairs);
  }

  /// Returns the second int de-interleaved from the result of [interleaveBitPairs].
  static int deinterleaveBitPairs2(int pairs) {
    return _removeBlankPairs(pairs >>> 2);
  }

  /// Inserts 00 pairs in between the pairs from [value].
  static int _insertBlankPairs(int value) {
    // Treat value as unsigned 32-bit by masking
    int bits = value & 0xFFFFFFFF;
    bits = (bits | (bits << 16)) & 0x0000ffff0000ffff;
    bits = (bits | (bits << 8)) & 0x00ff00ff00ff00ff;
    bits = (bits | (bits << 4)) & 0x0f0f0f0f0f0f0f0f;
    bits = (bits | (bits << 2)) & 0x3333333333333333;
    return bits;
  }

  /// Reverses [_insertBlankPairs] by selecting the two LSB bits, dropping the
  /// next two, selecting the next two, etc.
  static int _removeBlankPairs(int pairs) {
    pairs &= 0x3333333333333333;
    pairs |= pairs >>> 2;
    pairs &= 0x0f0f0f0f0f0f0f0f;
    pairs |= pairs >>> 4;
    pairs &= 0x00ff00ff00ff00ff;
    pairs |= pairs >>> 8;
    pairs &= 0x0000ffff0000ffff;
    pairs |= pairs >>> 16;
    return pairs & 0xFFFFFFFF;
  }
}

