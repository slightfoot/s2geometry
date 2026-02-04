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

/// Utilities for handling input streams.
///
/// In Dart, we typically work with List<int> or Uint8List directly rather than
/// streams for in-memory byte operations. This class provides utility methods
/// similar to the Java InputStreams class.
class InputStreams {
  InputStreams._();

  /// Reads a byte from [bytes] at [position].
  ///
  /// Throws [FormatException] if [position] is past the end of [bytes].
  static int readByte(List<int> bytes, int position) {
    if (position < 0 || position >= bytes.length) {
      throw const FormatException('EOF');
    }
    return bytes[position] & 0xFF;
  }

  /// Reads [count] bytes from [bytes] starting at [position].
  ///
  /// Throws [FormatException] if there aren't enough bytes.
  static List<int> readBytes(List<int> bytes, int position, int count) {
    if (position < 0 || position + count > bytes.length) {
      throw const FormatException('EOF');
    }
    return bytes.sublist(position, position + count);
  }
}

