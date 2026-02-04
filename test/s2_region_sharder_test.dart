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

/// Tests for S2RegionSharder - ported from S2RegionSharderTest.java
import 'package:s2geometry/s2geometry.dart';
import 'package:s2geometry/src/s2_region_sharder.dart';
import 'package:test/test.dart';

void main() {
  const defaultShard = 42;

  group('S2RegionSharder', () {
    test('getMostIntersectingShard', () {
      final coverings = <S2CellUnion>[
        S2CellUnion.fromCellIds([
          S2CellId.fromFacePosLevel(0, 0, 10),
        ]),
        S2CellUnion.fromCellIds([
          S2CellId.fromFacePosLevel(1, 1, 9),
          S2CellId.fromFacePosLevel(3, 0, 8),
        ]),
        S2CellUnion.fromCellIds([
          S2CellId.fromFacePosLevel(5, 0, 10),
        ]),
      ];

      final sharder = S2RegionSharder(coverings);

      // Overlap with only 1 shard.
      expect(
        sharder.getMostIntersectingShard(
          S2CellUnion.fromCellIds([S2CellId.fromFacePosLevel(0, 0, 11)]),
          defaultShard,
        ),
        equals(0),
      );

      // Overlap with multiple shards, picks the shard with more overlap.
      expect(
        sharder.getMostIntersectingShard(
          S2CellUnion.fromCellIds([
            S2CellId.fromFacePosLevel(0, 0, 10),
            S2CellId.fromFacePosLevel(3, 0, 9),
            S2CellId.fromFacePosLevel(3, 1, 9),
          ]),
          defaultShard,
        ),
        equals(1),
      );

      // Overlap with no shards.
      expect(
        sharder.getMostIntersectingShard(
          S2CellUnion.fromCellIds([S2CellId.fromFacePosLevel(4, 0, 10)]),
          defaultShard,
        ),
        equals(defaultShard),
      );
    });

    test('getIntersectingShards', () {
      final coverings = <S2CellUnion>[
        S2CellUnion.fromCellIds([
          S2CellId.fromFacePosLevel(0, 0, 10),
        ]),
        S2CellUnion.fromCellIds([
          S2CellId.fromFacePosLevel(1, 1, 9),
          S2CellId.fromFacePosLevel(3, 0, 8),
        ]),
        S2CellUnion.fromCellIds([
          S2CellId.fromFacePosLevel(5, 0, 10),
        ]),
      ];

      final sharder = S2RegionSharder(coverings);

      // Overlap with only 1 shard
      expect(
        sharder.getIntersectingShards(
          S2CellUnion.fromCellIds([S2CellId.fromFacePosLevel(0, 0, 11)]),
        ).toSet(),
        equals({0}),
      );

      // Overlap with multiple shards, picks the shard with more overlap.
      expect(
        sharder.getIntersectingShards(
          S2CellUnion.fromCellIds([
            S2CellId.fromFacePosLevel(0, 0, 10),
            S2CellId.fromFacePosLevel(3, 0, 9),
            S2CellId.fromFacePosLevel(3, 1, 9),
          ]),
        ).toSet(),
        equals({0, 1}),
      );

      // Overlap with no shards.
      expect(
        sharder.getIntersectingShards(
          S2CellUnion.fromCellIds([S2CellId.fromFacePosLevel(4, 0, 10)]),
        ),
        isEmpty,
      );
    });
  });
}

