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

import 's2_error.dart';

/// An exception thrown from the S2 library.
///
/// S2 methods where an error can occur generally accept an [S2Error] parameter.
/// If an error occurs, an [S2Error.Code] is assigned, along with some textual
/// description. This matches the C++ implementation of the S2 library.
///
/// In Dart, throwing and catching exceptions for error handling is common.
/// So, for some S2 library methods that accept S2Error parameters, an
/// alternate form that throws S2Exception instead is provided.
///
/// An S2Exception wraps an S2Error, and provides a convenience method to get
/// the underlying [S2ErrorCode].
class S2Exception implements Exception {
  final S2Error _error;

  /// Creates a new S2Exception wrapping the given S2Error.
  S2Exception(this._error);

  /// Returns the code of the S2Error wrapped by this S2Exception.
  S2ErrorCode get code => _error.code;

  /// Returns the error text.
  String get message => _error.text;

  @override
  String toString() => 'S2Exception: ${_error.text}';
}

