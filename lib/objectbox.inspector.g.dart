// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:objectbox/objectbox.dart';
import 'package:objectbox_inspector/objectbox_inspector.dart';
import 'data/entities.dart';
import 'data/entities.dart';
import 'data/entities.dart';
import 'data/entities.dart';
import 'data/entities.dart';
import 'dart:typed_data';

List<InspectableBox> getInspectableBoxes(Store store) {
  return [
    buildLevelRecordInspectableBox(store),
    buildAppPrefsInspectableBox(store),
    buildDiveRunInspectableBox(store),
    buildDiveRecordInspectableBox(store),
    buildDiscoveryInspectableBox(store),
  ];
}

InspectableBox buildLevelRecordInspectableBox(Store store) {
  final box = store.box<LevelRecord>();
  final allEntities = box.getAll();
  final entities = allEntities
      .map(
        (entity) => InspectableEntity(
          id: entity.id,
          properties: [
            InspectableProperty<int>(name: 'id', value: entity.id),
            InspectableProperty<int>(
              name: 'levelNumber',
              value: entity.levelNumber,

              onChanged: (value) {
                entity.levelNumber = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'bestMoves',
              value: entity.bestMoves,

              onChanged: (value) {
                entity.bestMoves = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'clears',
              value: entity.clears,

              onChanged: (value) {
                entity.clears = value;
                box.put(entity);
              },
            ),
          ],
        ),
      )
      .toList();

  return InspectableBox(
    boxName: 'LevelRecord',
    maxEntities: box.count(),
    entityGetter: () => entities,
  );
}

InspectableBox buildAppPrefsInspectableBox(Store store) {
  final box = store.box<AppPrefs>();
  final allEntities = box.getAll();
  final entities = allEntities
      .map(
        (entity) => InspectableEntity(
          id: entity.id,
          properties: [
            InspectableProperty<int>(name: 'id', value: entity.id),
            InspectableProperty<bool>(
              name: 'muted',
              value: entity.muted,

              onChanged: (value) {
                entity.muted = value;
                box.put(entity);
              },
            ),
            InspectableProperty<String>(
              name: 'confetti',
              value: entity.confetti,

              onChanged: (value) {
                entity.confetti = value;
                box.put(entity);
              },
            ),
            InspectableProperty<String>(
              name: 'language',
              value: entity.language,

              onChanged: (value) {
                entity.language = value;
                box.put(entity);
              },
            ),
            InspectableProperty<String>(
              name: 'targetPreview',
              value: entity.targetPreview,

              onChanged: (value) {
                entity.targetPreview = value;
                box.put(entity);
              },
            ),
            InspectableProperty<bool>(
              name: 'devUnlockAll',
              value: entity.devUnlockAll,

              onChanged: (value) {
                entity.devUnlockAll = value;
                box.put(entity);
              },
            ),
          ],
        ),
      )
      .toList();

  return InspectableBox(
    boxName: 'AppPrefs',
    maxEntities: box.count(),
    entityGetter: () => entities,
  );
}

InspectableBox buildDiveRunInspectableBox(Store store) {
  final box = store.box<DiveRun>();
  final allEntities = box.getAll();
  final entities = allEntities
      .map(
        (entity) => InspectableEntity(
          id: entity.id,
          properties: [
            InspectableProperty<int>(name: 'id', value: entity.id),
            InspectableProperty<int>(
              name: 'seed',
              value: entity.seed,

              onChanged: (value) {
                entity.seed = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'depth',
              value: entity.depth,

              onChanged: (value) {
                entity.depth = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'deepest',
              value: entity.deepest,

              onChanged: (value) {
                entity.deepest = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'clears',
              value: entity.clears,

              onChanged: (value) {
                entity.clears = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'runs',
              value: entity.runs,

              onChanged: (value) {
                entity.runs = value;
                box.put(entity);
              },
            ),
          ],
        ),
      )
      .toList();

  return InspectableBox(
    boxName: 'DiveRun',
    maxEntities: box.count(),
    entityGetter: () => entities,
  );
}

InspectableBox buildDiveRecordInspectableBox(Store store) {
  final box = store.box<DiveRecord>();
  final allEntities = box.getAll();
  final entities = allEntities
      .map(
        (entity) => InspectableEntity(
          id: entity.id,
          properties: [
            InspectableProperty<int>(name: 'id', value: entity.id),
            InspectableProperty<int>(
              name: 'depth',
              value: entity.depth,

              onChanged: (value) {
                entity.depth = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'bestMoves',
              value: entity.bestMoves,

              onChanged: (value) {
                entity.bestMoves = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'clears',
              value: entity.clears,

              onChanged: (value) {
                entity.clears = value;
                box.put(entity);
              },
            ),
          ],
        ),
      )
      .toList();

  return InspectableBox(
    boxName: 'DiveRecord',
    maxEntities: box.count(),
    entityGetter: () => entities,
  );
}

InspectableBox buildDiscoveryInspectableBox(Store store) {
  final box = store.box<Discovery>();
  final allEntities = box.getAll();
  final entities = allEntities
      .map(
        (entity) => InspectableEntity(
          id: entity.id,
          properties: [
            InspectableProperty<int>(name: 'id', value: entity.id),
            InspectableProperty<String>(
              name: 'shapeId',
              value: entity.shapeId,

              onChanged: (value) {
                entity.shapeId = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'depth',
              value: entity.depth,

              onChanged: (value) {
                entity.depth = value;
                box.put(entity);
              },
            ),
            InspectableProperty<int>(
              name: 'foundAt',
              value: entity.foundAt,

              onChanged: (value) {
                entity.foundAt = value;
                box.put(entity);
              },
            ),
          ],
        ),
      )
      .toList();

  return InspectableBox(
    boxName: 'Discovery',
    maxEntities: box.count(),
    entityGetter: () => entities,
  );
}
