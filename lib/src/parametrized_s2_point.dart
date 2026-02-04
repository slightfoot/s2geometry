// Copyright 2006 Google Inc.
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

import 's2_point.dart';

/// An S2Point that also has a parameter associated with it, which corresponds
/// to a time-like order on the points. Comparing ParametrizedS2Points uses
/// the time parameter, with the point as a tiebreaker.
class ParametrizedS2Point implements Comparable<ParametrizedS2Point> {
  final double time;
  final S2Point point;

  ParametrizedS2Point(this.time, this.point);

  double getTime() => time;

  S2Point getPoint() => point;

  @override
  int compareTo(ParametrizedS2Point other) {
    final compareTime = time.compareTo(other.time);
    if (compareTime != 0) {
      return compareTime;
    }
    return point.compareTo(other.point);
  }

  @override
  bool operator ==(Object other) {
    if (other is ParametrizedS2Point) {
      return time == other.time && point == other.point;
    }
    return false;
  }

  @override
  int get hashCode => point.hashCode;
}

