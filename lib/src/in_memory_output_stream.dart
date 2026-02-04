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

/// An abstract class that represents an in-memory output stream.
///
/// In Dart, this is conceptually similar to Java's ByteArrayOutputStream but
/// with a slightly different API. Use [ByteArrayInMemoryOutputStream] for the
/// default implementation.
abstract class InMemoryOutputStream {
  /// Returns the number of bytes written so far.
  int get size;

  /// Writes a single byte.
  void write(int byte);

  /// Writes a list of bytes.
  void writeBytes(List<int> bytes);

  /// Writes a portion of a list of bytes.
  void writeBytesRange(List<int> bytes, int offset, int length);

  /// Writes the contents of this stream to [output].
  void writeTo(InMemoryOutputStream output);

  /// Returns the contents as a Uint8List.
  Uint8List toBytes();
}

/// A [InMemoryOutputStream] backed by a BytesBuilder.
class ByteArrayInMemoryOutputStream extends InMemoryOutputStream {
  final BytesBuilder _builder = BytesBuilder();

  ByteArrayInMemoryOutputStream();

  /// Creates an [InMemoryOutputStream] with initial contents from [bytes].
  ByteArrayInMemoryOutputStream.withBytes(List<int> bytes) {
    _builder.add(bytes);
  }

  @override
  int get size => _builder.length;

  @override
  void write(int byte) {
    _builder.addByte(byte & 0xFF);
  }

  @override
  void writeBytes(List<int> bytes) {
    _builder.add(bytes);
  }

  @override
  void writeBytesRange(List<int> bytes, int offset, int length) {
    _builder.add(bytes.sublist(offset, offset + length));
  }

  @override
  void writeTo(InMemoryOutputStream output) {
    output.writeBytes(_builder.toBytes());
  }

  @override
  Uint8List toBytes() => _builder.toBytes();
}

