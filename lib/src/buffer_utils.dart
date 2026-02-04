// Copyright 2023 Google Inc.
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

import 'primitive_arrays.dart';

/// Static utility methods for handling byte buffers.
///
/// In Dart, ByteBuffer is accessed via ByteData. This class provides utilities
/// for creating [Bytes] objects from various sources.
class BufferUtils {
  BufferUtils._();

  /// Returns a [Bytes] wrapping [buffer].
  ///
  /// The returned array starts from index 0 of buffer, and its length is
  /// [buffer.lengthInBytes].
  static Bytes createBytes(ByteBuffer buffer) {
    return _ByteBufferBytes(buffer);
  }

  /// Returns a [Bytes] wrapping [data].
  static Bytes createBytesFromByteData(ByteData data) {
    return _ByteDataBytes(data);
  }
}

/// Implementation of Bytes backed by a ByteBuffer.
class _ByteBufferBytes extends Bytes {
  final ByteBuffer _buffer;

  _ByteBufferBytes(this._buffer);

  @override
  int get(int position) {
    if (position < 0 || position >= _buffer.lengthInBytes) {
      throw RangeError.index(position, _buffer.asUint8List(), 'position');
    }
    return _buffer.asUint8List()[position];
  }

  @override
  int get length => _buffer.lengthInBytes;
}

/// Implementation of Bytes backed by a ByteData.
class _ByteDataBytes extends Bytes {
  final ByteData _data;

  _ByteDataBytes(this._data);

  @override
  int get(int position) {
    if (position < 0 || position >= _data.lengthInBytes) {
      throw RangeError.index(position, this, 'position');
    }
    return _data.getUint8(position);
  }

  @override
  int get length => _data.lengthInBytes;
}

