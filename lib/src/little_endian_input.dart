// Copyright 2016 Google Inc.
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
//
// Ported from com.google.common.geometry.LittleEndianInput.java

import 'dart:typed_data';
import 'encoded_ints.dart';

/// Simple utility for reading little endian primitives from a byte buffer.
///
/// This is a Dart adaptation of the Java version. Instead of using an
/// InputStream, we read from a byte list and track the current position.
class LittleEndianInput {
  final List<int> _bytes;
  int _position = 0;

  /// Creates a LittleEndianInput that reads from the given byte list.
  LittleEndianInput(this._bytes);

  /// Creates a LittleEndianInput that reads from a Uint8List.
  LittleEndianInput.fromUint8List(Uint8List bytes) : _bytes = bytes;

  /// Returns the current position in the byte buffer.
  int get position => _position;

  /// Sets the current position in the byte buffer.
  set position(int value) {
    _position = value;
  }

  /// Returns the number of bytes remaining in the buffer.
  int get remaining => _bytes.length - _position;

  /// Returns true if there are no more bytes to read.
  bool get isEmpty => _position >= _bytes.length;

  /// Reads a single byte.
  ///
  /// Throws [FormatException] if past end of input.
  int readByte() {
    if (_position >= _bytes.length) {
      throw FormatException('EOF');
    }
    return _bytes[_position++];
  }

  /// Reads a fixed size of bytes from the input.
  ///
  /// Throws [FormatException] if past end of input.
  Uint8List readBytes(int size) {
    if (size < 0) {
      throw FormatException('Attempt to read $size bytes');
    }
    if (_position + size > _bytes.length) {
      throw FormatException('EOF');
    }
    final result = Uint8List(size);
    for (int i = 0; i < size; i++) {
      result[i] = _bytes[_position + i];
    }
    _position += size;
    return result;
  }

  /// Reads a little-endian signed 32-bit integer.
  ///
  /// Throws [FormatException] if past end of input.
  int readInt() {
    return (readByte() & 0xFF) |
        ((readByte() & 0xFF) << 8) |
        ((readByte() & 0xFF) << 16) |
        ((readByte() & 0xFF) << 24);
  }

  /// Reads a little-endian signed 64-bit integer.
  ///
  /// Throws [FormatException] if past end of input.
  int readLong() {
    return (readByte() & 0xFF) |
        ((readByte() & 0xFF) << 8) |
        ((readByte() & 0xFF) << 16) |
        ((readByte() & 0xFF) << 24) |
        ((readByte() & 0xFF) << 32) |
        ((readByte() & 0xFF) << 40) |
        ((readByte() & 0xFF) << 48) |
        ((readByte() & 0xFF) << 56);
  }

  /// Reads a little-endian IEEE754 32-bit float.
  ///
  /// Throws [FormatException] if past end of input.
  double readFloat() {
    final bytes = readBytes(4);
    final data = ByteData.view(bytes.buffer);
    return data.getFloat32(0, Endian.little);
  }

  /// Reads a little-endian IEEE754 64-bit double.
  ///
  /// Throws [FormatException] if past end of input.
  double readDouble() {
    final bytes = readBytes(8);
    final data = ByteData.view(bytes.buffer);
    return data.getFloat64(0, Endian.little);
  }

  /// Reads a variable-encoded signed 32-bit integer.
  ///
  /// Throws [FormatException] if past end of input.
  int readVarint32() {
    return readVarint64() & 0xFFFFFFFF;
  }

  /// Reads a variable-encoded signed 64-bit integer.
  ///
  /// Throws [FormatException] if past end of input.
  int readVarint64() {
    final (value, bytesRead) = EncodedInts.readVarint64(_bytes, _position);
    _position += bytesRead;
    return value;
  }

  /// Static method to read a little-endian 64-bit integer from a list of bytes.
  static int readLongFromBytes(List<int> bytes, int offset) {
    return (bytes[offset] & 0xFF) |
        ((bytes[offset + 1] & 0xFF) << 8) |
        ((bytes[offset + 2] & 0xFF) << 16) |
        ((bytes[offset + 3] & 0xFF) << 24) |
        ((bytes[offset + 4] & 0xFF) << 32) |
        ((bytes[offset + 5] & 0xFF) << 40) |
        ((bytes[offset + 6] & 0xFF) << 48) |
        ((bytes[offset + 7] & 0xFF) << 56);
  }

  /// Static method to read a little-endian 64-bit double from a list of bytes.
  static double readDoubleFromBytes(List<int> bytes, int offset) {
    final data = ByteData(8);
    for (int i = 0; i < 8; i++) {
      data.setUint8(i, bytes[offset + i]);
    }
    return data.getFloat64(0, Endian.little);
  }
}

