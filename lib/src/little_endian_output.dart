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
// Ported from com.google.common.geometry.LittleEndianOutput.java

import 'dart:typed_data';
import 'encoded_ints.dart';

/// Simple utility for writing little endian primitives to a byte buffer.
///
/// This is a Dart adaptation of the Java version. Instead of using an
/// OutputStream, we write to an internal byte buffer that can be retrieved
/// via [toBytes].
class LittleEndianOutput {
  final BytesBuilder _buffer = BytesBuilder();

  /// Returns the underlying byte buffer as a list of bytes.
  Uint8List toBytes() => _buffer.toBytes();

  /// Returns the number of bytes written so far.
  int get length => _buffer.length;

  /// Clears the internal buffer.
  void clear() => _buffer.clear();

  /// Writes a single byte.
  void writeByte(int value) {
    _buffer.addByte(value & 0xFF);
  }

  /// Writes an array of bytes.
  void writeBytes(List<int> bytes) {
    _buffer.add(bytes);
  }

  /// Writes a little-endian signed 32-bit integer.
  void writeInt(int value) {
    _buffer.addByte(value & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
    _buffer.addByte((value >> 16) & 0xFF);
    _buffer.addByte((value >> 24) & 0xFF);
  }

  /// Writes a little-endian signed 64-bit integer.
  void writeLong(int value) {
    _buffer.addByte(value & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
    _buffer.addByte((value >> 16) & 0xFF);
    _buffer.addByte((value >> 24) & 0xFF);
    _buffer.addByte((value >> 32) & 0xFF);
    _buffer.addByte((value >> 40) & 0xFF);
    _buffer.addByte((value >> 48) & 0xFF);
    _buffer.addByte((value >> 56) & 0xFF);
  }

  /// Writes a little-endian IEEE754 32-bit float.
  void writeFloat(double value) {
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Writes a little-endian IEEE754 64-bit double.
  void writeDouble(double value) {
    final data = ByteData(8);
    data.setFloat64(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Writes a signed 32-bit integer using variable encoding.
  void writeVarint32(int value) {
    writeVarint64(value);
  }

  /// Writes a signed 64-bit integer using variable encoding.
  void writeVarint64(int value) {
    final bytes = <int>[];
    EncodedInts.writeVarint64(bytes, value);
    _buffer.add(bytes);
  }

  /// Static method to write a little-endian 64-bit integer to a list of bytes.
  ///
  /// Returns the number of bytes written (always 8).
  static int writeLongToBytes(List<int> bytes, int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
    bytes[offset + 2] = (value >> 16) & 0xFF;
    bytes[offset + 3] = (value >> 24) & 0xFF;
    bytes[offset + 4] = (value >> 32) & 0xFF;
    bytes[offset + 5] = (value >> 40) & 0xFF;
    bytes[offset + 6] = (value >> 48) & 0xFF;
    bytes[offset + 7] = (value >> 56) & 0xFF;
    return 8;
  }

  /// Static method to write a little-endian 64-bit double to a list of bytes.
  ///
  /// Returns the number of bytes written (always 8).
  static int writeDoubleToBytes(List<int> bytes, int offset, double value) {
    final data = ByteData(8);
    data.setFloat64(0, value, Endian.little);
    final doubleBytes = data.buffer.asUint8List();
    for (int i = 0; i < 8; i++) {
      bytes[offset + i] = doubleBytes[i];
    }
    return 8;
  }
}

