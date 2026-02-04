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

import 'dart:typed_data';

/// A set of interfaces for describing primitive arrays.
///
/// Provides [Bytes] for byte arrays, [Longs] for long arrays, and [Cursor]
/// for tracking position and limit during reading.

/// A cursor storing a position and a limit.
class Cursor {
  int position;
  int limit;

  Cursor(this.position, this.limit) {
    if (position < 0) {
      throw ArgumentError('position must be >= 0');
    }
    if (position > limit) {
      throw ArgumentError('position must be <= limit');
    }
  }

  /// Returns the number of remaining elements (limit - position).
  int get remaining => limit - position;

  /// Sets the cursor position to 'position' and returns this cursor.
  Cursor seek(int newPosition) {
    if (newPosition < 0 || newPosition >= limit) {
      throw ArgumentError('position must be >= 0 and < limit');
    }
    position = newPosition;
    return this;
  }
}

/// An array of bytes.
///
/// Implementations will be thread-safe if the underlying data is not mutated.
/// Users should ensure the underlying data is not mutated in order to get
/// predictable behaviour.
abstract class Bytes {
  /// Returns the byte at position [position].
  ///
  /// Throws an [RangeError] if [position] is out of bounds.
  int get(int position);

  /// Returns the length of this array.
  int get length;

  /// Returns a [Cursor] with the given [position] and [limit].
  Cursor cursor([int position = 0, int? limit]) {
    limit ??= length;
    if (position > limit || position > length) {
      throw ArgumentError('position must be <= limit and <= length');
    }
    return Cursor(position, limit);
  }

  /// Returns true if this Bytes contains the same bytes as [other].
  bool isEqualTo(Bytes? other) {
    if (other == null) return false;
    if (other.length != length) return false;
    for (int i = 0; i < length; i++) {
      if (other.get(i) != get(i)) return false;
    }
    return true;
  }

  /// Returns a [Bytes] wrapping [bytes].
  static Bytes fromByteArray(List<int> bytes) => _ByteArrayBytes(bytes);

  /// Returns the bytes as a Uint8List.
  Uint8List toUint8List() {
    final result = Uint8List(length);
    for (int i = 0; i < length; i++) {
      result[i] = get(i) & 0xFF;
    }
    return result;
  }

  /// Returns a byte at [cursor.position] and updates the position to the next byte.
  int readByte(Cursor cursor) => get(cursor.position++);

  /// Returns an unsigned integer consisting of [numBytes] bytes read from this
  /// array at [cursor.position] in little-endian format as an unsigned 64-bit integer.
  ///
  /// [cursor.position] is updated to the index of the first byte following the varint64.
  int readVarint64(Cursor cursor) {
    int result = 0;
    for (int shift = 0; shift < 64; shift += 7) {
      int b = get(cursor.position++);
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) {
        return result;
      }
    }
    throw ArgumentError('Malformed varint.');
  }

  /// Same as [readVarint64], but throws an [ArgumentError] if the
  /// read varint64 is greater than 2^31 - 1.
  int readVarint32(Cursor cursor) {
    final value = readVarint64(cursor);
    if (value > 0x7FFFFFFF) {
      throw ArgumentError('Value $value exceeds max int32');
    }
    return value;
  }

  /// Returns an unsigned integer consisting of [numBytes] bytes read from this
  /// array at [cursor.position] in little-endian format as an unsigned 64-bit integer.
  ///
  /// [cursor.position] is updated to the index of the first byte following the uint.
  ///
  /// This method is not compatible with [readVarint64].
  int readUintWithLength(Cursor cursor, int numBytes) {
    final result = readUintWithLengthAt(cursor.position, numBytes);
    cursor.position += numBytes;
    return result;
  }

  /// Same as [readUintWithLength], but does not require a [Cursor].
  int readUintWithLengthAt(int position, int numBytes) {
    int x = 0;
    for (int i = 0; i < numBytes; i++) {
      x += (get(position++) & 0xFF) << (8 * i);
    }
    return x;
  }

  /// Reads a little endian long from the current cursor position.
  int readLittleEndianLong(Cursor cursor) => readUintWithLength(cursor, 8);

  /// Returns a little-endian double read from this array at [position].
  double readLittleEndianDouble(int position) {
    final longBits = readUintWithLengthAt(position, 8);
    final data = ByteData(8);
    data.setInt64(0, longBits, Endian.little);
    return data.getFloat64(0, Endian.little);
  }
}

/// Implementation of Bytes backed by a byte array.
class _ByteArrayBytes extends Bytes {
  final List<int> _bytes;

  _ByteArrayBytes(this._bytes);

  @override
  int get(int position) {
    if (position < 0 || position >= _bytes.length) {
      throw RangeError.index(position, _bytes, 'position');
    }
    return _bytes[position];
  }

  @override
  int get length => _bytes.length;
}

/// An array of longs.
///
/// Implementations will be thread-safe if the underlying data is not mutated.
/// Users should ensure the underlying data is not mutated in order to get
/// predictable behaviour.
abstract class Longs {
  /// Returns the long at position [position].
  ///
  /// Throws a [RangeError] if [position] is out of bounds.
  int get(int position);

  /// Returns the length of this array.
  int get length;

  /// Returns a [Longs] wrapping [list].
  static Longs fromList(List<int> list) => _ListLongs(list);

  /// Decodes and returns this array as an `int[]`.
  ///
  /// Throws an [ArgumentError] if any value in this array is less than
  /// -2^31 or greater than 2^31 - 1.
  List<int> toIntArray() {
    final result = List<int>.filled(length, 0);
    for (int i = 0; i < length; i++) {
      final value = get(i);
      if (value < -0x80000000 || value > 0x7FFFFFFF) {
        throw ArgumentError('Value $value exceeds int32 range');
      }
      result[i] = value;
    }
    return result;
  }
}

/// Implementation of Longs backed by a list.
class _ListLongs extends Longs {
  final List<int> _list;

  _ListLongs(this._list);

  @override
  int get(int position) {
    if (position < 0 || position >= _list.length) {
      throw RangeError.index(position, _list, 'position');
    }
    return _list[position];
  }

  @override
  int get length => _list.length;
}

