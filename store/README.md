# Publishing Quadcraft

`store/` is the single source of truth for everything the App Store and
Google Play listings need — copy in 13 languages, screenshots, and the
non-localized submission answers (category, compliance flags, contact
info). Nothing under `ios/fastlane/metadata`, `ios/fastlane/screenshots`,
or `android/fastlane/metadata` is edited by hand — those are regenerated
from `store/` every time and are gitignored.

```
store/
  app.yaml           non-localized: bundle id, category, compliance flags, URLs
  locales.yaml        our language codes -> each store's own locale codes
  devices.yaml         screenshot target pixel sizes (no simulator/emulator needed)
  content/<lang>/meta.yaml   name, subtitle, description, keywords, etc. — 13 of these
  screenshots/<lang>/<device>/*.png   generated, not hand-edited
```

## Editing store copy

Edit `store/content/<lang>/meta.yaml` directly, then run:

```
dart run tool/store/sync_store_content.dart
```

This validates every field against each store's character limits (it fails
loudly, naming the exact locale/field/length if something's too long — fix
it in `store/content/`, never in the generated `ios/fastlane`/`android/fastlane`
folders) and writes the per-store text files. Safe to run as often as you
like.

**The 13 languages' copy in this repo is a first draft**, written to be
accurate and on-brand but not reviewed by a native speaker of each
language. Read through it once before you actually submit — a store
listing is worth more scrutiny than an in-app string.

## Capturing screenshots

```
tool/store/capture_screenshots.sh
```

No simulator or emulator involved — `test/store_screenshots_test.dart`
renders each screen directly with `flutter test`
(`RenderRepaintBoundary.toImage()` at the exact pixel size each
`store/devices.yaml` entry asks for) and writes PNGs into
`store/screenshots/`. Each locale gets 5 shots: the home screen (on a
fixed, deliberately nicer seed — see `_showcaseSeed`), then 4 tutorial
levels from the Paint / Colour Bank sections (`_showcaseLevels`, currently
13/19/20/21) *actually solved* by replaying their authored `Level.solution`
straight through `PlayController` — no UI-tap simulation, no mocked-up
board — captured mid-celebration (confetti already firing, just ahead of
the 750ms-delayed win-sheet modal). All 13 locales × 3 device targets × 5
screens finish in about two minutes. Swap `_showcaseLevels` /
`_showcaseSeed` in the test file directly if you want different levels or
a different seed on the home screen.

CJK, Arabic, and Devanagari glyphs aren't in the app's bundled fonts —
production leans on `AppTheme.fallbacks` (`lib/ui/theme.dart`) naming real
OS system fonts, which this headless renderer doesn't have access to.
`test/fonts/*.ttf` (Noto Sans SC/JP/KR/Arabic/Devanagari, downloaded from
Google Fonts) are registered under those exact fallback family names by
the test itself, purely for this capture step — they're read straight off
disk via `dart:io`, not through `pubspec.yaml`, so they never ship in a
real app build. If a script still shows as tofu boxes after adding a new
locale, it likely needs one more font added there.

The test file's header explains a toolchain quirk worth knowing about:
`flutter test` can hang for a very long time after this specific test
finishes (a software-rasterizer teardown issue, unrelated to whether the
screenshots came out right) — the shell script works around it by polling
for a completion marker and killing the process itself rather than
waiting on a graceful exit.

After capturing, run the sync command above again to fan the new
screenshots out into `ios/fastlane/screenshots` and
`android/fastlane/metadata/android/*/images/phoneScreenshots`.

## Publishing

```
tool/store/publish.sh android metadata                    # title/description/changelog only
tool/store/publish.sh ios screenshots                      # screenshots only
tool/store/publish.sh all metadata_and_screenshots          # both, both stores
```

This always re-runs the sync step first, so a stale edit can never get
uploaded by accident. It never touches the app binary — see "One-time
manual setup" below for why, and for what to do instead.

None of this works until the one-time setup below is done once per store.

---

## One-time manual setup

Neither app exists in either store yet, and a few steps are permanently
gated behind each console's own UI — no API can do them. Do these once, in
order; ongoing releases after this only need the commands above.

### 1. Create the app record

- **App Store Connect** (https://appstoreconnect.apple.com, requires an
  active Apple Developer Program membership): My Apps → **+** → New App.
  - Platform: iOS. Bundle ID: `com.anotherit.quadcraft` (register it first
    under Certificates, Identifiers & Profiles → Identifiers if it isn't
    listed).
  - SKU: anything unique to you — `store/app.yaml`'s `ios.sku` uses
    `quadcraft-001`, reuse that or change both places to match.
  - Primary language: English (U.S.).
- **Google Play Console** (https://play.google.com/console, requires a
  one-time $25 registration fee if you haven't paid it before): All apps →
  Create app.
  - App name: Quadcraft. Package name: `com.anotherit.quadcraft` (this is
    permanent — cannot be changed after creation).
  - Default language: English (US).

### 2. Generate the two credential files

Both are gitignored; never commit either.

- **App Store Connect API key** — App Store Connect → Users and Access →
  Integrations → App Store Connect API → **Generate API Key** (or **+** if
  keys already exist). Role: App Manager is enough.
  - Download the `.p8` file **immediately** — Apple only lets you download
    it once. Save it somewhere durable (a password manager or encrypted
    volume works; the repo does not, since it's gitignored but still local).
  - Copy `ios/fastlane/.env.example` to `ios/fastlane/.env` and fill in the
    Key ID, Issuer ID (shown on the same page), and the path to the `.p8`
    file.
- **Google Play service account JSON** — Play Console → Setup → API
  access → follow the prompt to create a Google Cloud service account (or
  link an existing project) → create a JSON key for it → back in Play
  Console, grant that service account **Release manager** access (Users
  and permissions) so `supply` can push metadata and builds.
  - Copy `android/fastlane/.env.example` to `android/fastlane/.env` and
    point `SUPPLY_JSON_KEY` at the downloaded JSON file.

### 3. Upload a first build by hand

Both consoles require at least one build to exist before metadata-only API
updates behave reliably (Play in particular won't accept `supply` calls
against an app with zero uploaded artifacts). This is a one-time bootstrap:

- iOS: `flutter build ipa`, then upload via Xcode Organizer or Apple's
  Transporter app.
- Android: `flutter build appbundle`, then upload the `.aab` directly in
  Play Console → Production (or Internal testing) → Create release.

Automating binary builds/signing (certificates, provisioning profiles, the
upload keystore) is a separate, larger piece of setup that this pipeline
deliberately doesn't take on — the lanes here (`metadata`, `screenshots`,
`metadata_and_screenshots`) never touch the binary.

### 4. Fill in the compliance questionnaires

Two are scripted already (see `ios/fastlane/Fastfile`'s `submission_info`,
sourced from `store/app.yaml`'s `ios.uses_encryption`,
`contains_third_party_content`, and `uses_idfa`). The rest are UI-only —
their schemas are too console-version-specific to script reliably, so get
these right by hand once:

- **Apple age rating** — App Store Connect → your app → App Information →
  Age Rating. `store/app.yaml`'s `ios.age_rating` block is the drafted
  answer key (all "NONE" is accurate for a shape puzzle with no ads, IAP,
  or user content — revisit if that changes).
- **Apple App Privacy** ("nutrition label") — App Store Connect → your app
  → App Privacy. Quadcraft collects nothing (no analytics, no accounts,
  no network calls in `pubspec.yaml`'s dependencies) — "Data Not
  Collected" should be accurate.
- **Play Content rating** — Play Console → Policy → App content → Content
  ratings questionnaire.
- **Play Data safety** — Play Console → Policy → App content → Data
  safety. Same "collects nothing" answer as Apple's version above.

### 5. Fill in real URLs and contact info

`store/app.yaml` has `REPLACE_ME` placeholders for `support_url`,
`marketing_url`, `privacy_url`, and the Android `contact_email` /
`contact_website`. Both stores require a live, working privacy policy URL
— `sync_store_content.dart` will keep warning about these until they're
real. A support URL can be as simple as a GitHub Issues page or a mailto
link's landing page; a privacy policy needs actual hosted content (a
one-page static site is enough for a game that collects nothing).

### Done once — after this

```
tool/store/capture_screenshots.sh
dart run tool/store/sync_store_content.dart
tool/store/publish.sh all metadata_and_screenshots
```

then submit for review from each console (or wire up
`submit_for_review: true` in `ios/fastlane/Fastfile`'s `deliver` calls
once you're confident in the metadata — left off by default so a publish
never accidentally starts Apple's review clock).
