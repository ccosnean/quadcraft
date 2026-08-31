// Regenerates ios/fastlane/metadata, ios/fastlane/screenshots, and
// android/fastlane/metadata from store/ — the single source of truth for
// store copy and screenshots. Safe to re-run; every generated path is
// wiped and rewritten each time. See store/README.md.
//
// Usage: dart run tool/store/sync_store_content.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _iosLimits = {
  'name': 30,
  'subtitle': 30,
  'promo_text': 170,
  'keywords': 100,
  'description': 4000,
  'release_notes': 4000,
};

const _androidLimits = {
  'name': 30, // -> title.txt
  'short_description': 80,
  'description': 4000, // -> full_description.txt
  'release_notes': 500, // -> changelogs/<versionCode>.txt
};

void main() {
  final root = _findRepoRoot();
  final storeDir = Directory(p.join(root, 'store'));
  final contentDir = Directory(p.join(storeDir.path, 'content'));

  final locales =
      loadYaml(File(p.join(storeDir.path, 'locales.yaml')).readAsStringSync())
          as YamlMap;

  final appConfig =
      loadYaml(File(p.join(storeDir.path, 'app.yaml')).readAsStringSync())
          as YamlMap;
  final globalFields = {
    for (final key in ['support_url', 'marketing_url', 'privacy_url'])
      key: '${appConfig[key]}',
  };

  for (final entry in globalFields.entries) {
    if (entry.value.startsWith('REPLACE_ME')) {
      stderr.writeln(
        'warning: store/app.yaml "${entry.key}" is still a placeholder — '
        'fix it before publishing (used for every locale)',
      );
    }
  }

  final versionCode = _readAndroidVersionCode(root);

  final iosMetadataDir = Directory(p.join(root, 'ios/fastlane/metadata'));
  final iosScreenshotsDir = Directory(p.join(root, 'ios/fastlane/screenshots'));
  final androidMetadataDir = Directory(
    p.join(root, 'android/fastlane/metadata/android'),
  );

  for (final dir in [iosMetadataDir, iosScreenshotsDir, androidMetadataDir]) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final errors = <String>[];
  var localeCount = 0;

  for (final entry in contentDir.listSync().whereType<Directory>()) {
    final ourCode = p.basename(entry.path);
    final metaFile = File(p.join(entry.path, 'meta.yaml'));
    if (!metaFile.existsSync()) {
      errors.add('[$ourCode] missing meta.yaml');
      continue;
    }
    final localeCodes = locales[ourCode] as YamlMap?;
    if (localeCodes == null) {
      errors.add('[$ourCode] not present in store/locales.yaml');
      continue;
    }
    localeCount++;

    final meta = loadYaml(metaFile.readAsStringSync()) as YamlMap;
    final fields = {
      ...globalFields,
      for (final k in meta.keys) k as String: '${meta[k]}',
    };

    errors.addAll(_validate(ourCode, 'iOS', fields, _iosLimits));
    errors.addAll(_validate(ourCode, 'Android', fields, _androidLimits));

    _writeIosMetadata(iosMetadataDir, localeCodes['ios'] as String, fields);
    _writeAndroidMetadata(
      androidMetadataDir,
      localeCodes['android'] as String,
      fields,
      versionCode,
    );
    _copyScreenshots(
      root,
      ourCode,
      localeCodes['ios'] as String,
      localeCodes['android'] as String,
      iosScreenshotsDir,
      androidMetadataDir,
    );
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Store content validation failed:\n');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  stdout.writeln(
    'Synced $localeCount locale(s) into ios/fastlane and android/fastlane.',
  );
}

List<String> _validate(
  String locale,
  String store,
  Map<String, String> fields,
  Map<String, int> limits,
) {
  final errors = <String>[];
  for (final entry in limits.entries) {
    final value = fields[entry.key];
    if (value == null || value.trim().isEmpty) {
      errors.add('[$locale] $store: "${entry.key}" is missing or empty');
      continue;
    }
    // Approximate: counts UTF-16 code units, which is what both consoles'
    // own text fields effectively cap against for these scripts.
    final len = value.trim().length;
    if (len > entry.value) {
      errors.add(
        '[$locale] $store: "${entry.key}" is $len chars, exceeds the '
        '${entry.value}-char limit',
      );
    }
  }
  return errors;
}

void _writeIosMetadata(
  Directory metadataDir,
  String iosLocale,
  Map<String, String> fields,
) {
  final dir = Directory(p.join(metadataDir.path, iosLocale))
    ..createSync(recursive: true);
  void write(String file, String? value) {
    if (value == null) return;
    File(p.join(dir.path, file)).writeAsStringSync(value.trim());
  }

  write('name.txt', fields['name']);
  write('subtitle.txt', fields['subtitle']);
  write('description.txt', fields['description']);
  write('keywords.txt', fields['keywords']);
  write('promotional_text.txt', fields['promo_text']);
  write('release_notes.txt', fields['release_notes']);
  write('support_url.txt', fields['support_url']);
  write('marketing_url.txt', fields['marketing_url']);
  write('privacy_url.txt', fields['privacy_url']);
}

void _writeAndroidMetadata(
  Directory metadataDir,
  String androidLocale,
  Map<String, String> fields,
  String versionCode,
) {
  final dir = Directory(p.join(metadataDir.path, androidLocale))
    ..createSync(recursive: true);
  void write(String file, String? value) {
    if (value == null) return;
    File(p.join(dir.path, file)).writeAsStringSync(value.trim());
  }

  write('title.txt', fields['name']);
  write('short_description.txt', fields['short_description']);
  write('full_description.txt', fields['description']);

  final changelogs = Directory(p.join(dir.path, 'changelogs'))
    ..createSync(recursive: true);
  final notes = fields['release_notes'];
  if (notes != null) {
    File(
      p.join(changelogs.path, '$versionCode.txt'),
    ).writeAsStringSync(notes.trim());
  }
}

void _copyScreenshots(
  String root,
  String ourCode,
  String iosLocale,
  String androidLocale,
  Directory iosScreenshotsDir,
  Directory androidMetadataDir,
) {
  final shotsDir = Directory(p.join(root, 'store/screenshots', ourCode));
  if (!shotsDir.existsSync()) return;

  for (final deviceDir in shotsDir.listSync().whereType<Directory>()) {
    final device = p.basename(deviceDir.path);
    final pngs = deviceDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'));

    if (device.startsWith('ios-')) {
      final dest = Directory(p.join(iosScreenshotsDir.path, iosLocale))
        ..createSync(recursive: true);
      for (final png in pngs) {
        png.copySync(p.join(dest.path, '$device-${p.basename(png.path)}'));
      }
    } else if (device == 'android-phone') {
      final dest = Directory(
        p.join(
          androidMetadataDir.path,
          androidLocale,
          'images/phoneScreenshots',
        ),
      )..createSync(recursive: true);
      for (final png in pngs) {
        png.copySync(p.join(dest.path, p.basename(png.path)));
      }
    }
    // Any store/screenshots/<locale>/ios-*/ folder (6.9", iPad 13", etc.)
    // lands here automatically. Add an `else if` for android tablet sizes
    // (images/sevenInchScreenshots, images/tenInchScreenshots) if
    // store/devices.yaml grows to capture them.
  }
}

String _readAndroidVersionCode(String root) {
  final pubspec =
      loadYaml(File(p.join(root, 'pubspec.yaml')).readAsStringSync())
          as YamlMap;
  final version = pubspec['version'] as String;
  final buildNumber = version.split('+').last;
  return buildNumber;
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (!File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln('Could not find repo root (no pubspec.yaml found).');
      exit(1);
    }
    dir = parent;
  }
  return dir.path;
}
