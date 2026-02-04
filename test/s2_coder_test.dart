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

import 'package:s2geometry/s2geometry.dart';
import 'package:test/test.dart';

/// Unit tests for S2Coder.
void main() {
  group('S2Coder', () {
    test('testVarint', () {
      // Note: Dart's int is 64-bit, so we use the same values but as int
      final tests = [
        -9223372036854775808, // min int64
        -1,
        0,
        1,
        4,
        9223372036854775807, // max int64
      ];
      for (final test in tests) {
        expect(encodeDecode(S2Coder.unboxedVarint, test), equals(test));
      }
    });

    test('testString', () {
      final tests = ['', 'foo', 'ăѣծềſģȟ'];
      for (final test in tests) {
        expect(encodeDecode(S2Coder.string, test), equals(test));
      }
    });

    test('testBytes', () {
      final tests = [
        <int>[],
        <int>[1, 2, 3],
        <int>[0, 255, 128],
      ];
      for (final test in tests) {
        expect(encodeDecode(S2Coder.bytes, test), equals(test));
      }
    });
  });
}

T encodeDecode<T>(S2Coder<T> coder, T value) {
  final bytes = coder.encode(value);
  return coder.decodeBytes(Bytes.fromByteArray(bytes));
}

