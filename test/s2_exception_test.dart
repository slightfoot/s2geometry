// Copyright 2024 Google Inc.
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

void main() {
  group('S2Exception', () {
    test('wraps S2Error correctly', () {
      final error = S2Error();
      error.init(S2ErrorCode.duplicateVertices, 'Found duplicate vertices');
      final exception = S2Exception(error);

      expect(exception.code, equals(S2ErrorCode.duplicateVertices));
      expect(exception.message, equals('Found duplicate vertices'));
    });

    test('toString returns formatted message', () {
      final error = S2Error();
      error.init(S2ErrorCode.loopNotEnoughVertices, 'Need at least 3 vertices');
      final exception = S2Exception(error);

      expect(exception.toString(), equals('S2Exception: Need at least 3 vertices'));
    });

    test('can be thrown and caught', () {
      final error = S2Error();
      error.init(S2ErrorCode.antipodalVertices, 'Points are antipodal');

      expect(
        () => throw S2Exception(error),
        throwsA(isA<S2Exception>()
            .having((e) => e.code, 'code', S2ErrorCode.antipodalVertices)
            .having((e) => e.message, 'message', 'Points are antipodal')),
      );
    });

    test('default S2Error has no error code', () {
      final error = S2Error();
      final exception = S2Exception(error);

      expect(exception.code, equals(S2ErrorCode.noError));
      expect(exception.message, isEmpty);
    });
  });
}

