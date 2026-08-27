import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:objectbox_inspector/objectbox_inspector.dart';

import '../data/progress_store.dart';
import '../objectbox.inspector.g.dart';

bool get canOpenObjectBoxInspector => kDebugMode;

void openQuadcraftObjectBoxInspector(
  BuildContext context,
  ProgressRepository repo,
) {
  if (repo is! ProgressStore) return;
  openObjectboxInspector(context, getInspectableBoxes(repo.store));
}
