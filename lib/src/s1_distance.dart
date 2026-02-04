// Copyright 2022 Google Inc.
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

/// An abstract, immutable distance on the surface of the sphere.
abstract class S1Distance<T extends S1Distance<T>> implements Comparable<T> {
  /// Compares this S1Distance to the [other]. Returns a positive value if
  /// this one is larger, zero if they are equal, and a negative value if
  /// this one is smaller.
  @override
  int compareTo(T other);

  /// Returns true iff this distance is greater than the other distance.
  bool greaterThan(T other) => compareTo(other) > 0;

  /// Returns true iff this distance is less than the other distance.
  bool lessThan(T other) => compareTo(other) < 0;

  /// Returns true iff this distance is greater than or equal to the other distance.
  bool greaterOrEquals(T other) => compareTo(other) >= 0;

  /// Returns true iff this distance is less than or equal to the other distance.
  bool lessOrEquals(T other) => compareTo(other) <= 0;

  /// Returns true iff this distance is equal to zero.
  bool get isZero;
}

