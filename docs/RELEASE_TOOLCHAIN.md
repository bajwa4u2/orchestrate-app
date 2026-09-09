# Orchestrate 1.0.0 (14) — Release Toolchain and Provenance

**Release source commit:** `725f40fc7fb88b14cc50868f1b0997a25c8e2ab0`
**Backend commit expected by this client:** `c8ff0f01b45eea4546afc9691bf26ab4e3cd0e98`
**Working tree at build time:** clean, 0 modified files

"Build succeeded" is not provenance. Every value below was read out of the
artifact or the machine that produced it, not out of the configuration that was
supposed to produce it.

---

## What converges, and what does not

Native toolchains legitimately differ — Xcode builds iOS, MSVC builds Windows,
Gradle builds Android. Pretending they are one environment would be theatre.

What must converge across the Flutter clients:

| | |
|---|---|
| Application source | one frozen commit |
| Product version | `1.0.0+14` |
| Flutter SDK revision | one, not one version *string* |
| Dart | the one that SDK carries |
| `pubspec.lock` | one committed lock |

Platform-native toolchain versions are **recorded**, not equalised.

---

## The Flutter layer

| | |
|---|---|
| Flutter | **3.47.2** |
| Framework revision | `d3b14c876900e553bc736ca19295fc09e3853e8e` |
| Engine hash | `1cf1c4773fb941c4c74a7f8bb144a8837596c0f4` (revision `a804b26164`) |
| Dart | **3.13.2** · DevTools 2.60.0 |
| `pubspec.yaml` | `sha256 99f8ecf67b43247013f4d3102c04e3bfb418319134dec188d1fefac592158460` |
| `pubspec.lock` | `sha256 04e2f2dc8e05e446ba5d0905cbea1a27e40521f9f1ccd62561bfe5670d6dded3` |

### Proven equal, by revision rather than by version string

Two different SDK revisions can report the same marketing version, so the
version string alone proves nothing.

```
CI    Flutter 3.47.2   framework d3b14c8769   engine a804b26164   Dart 3.13.2
local Flutter 3.47.2   framework d3b14c8769   engine a804b26164   Dart 3.13.2
```

The local SDK is a **separate checkout at tag `3.47.2`**, not the machine's
global Flutter, because this machine is shared with another workstream that is
mid-flight on 3.41.4. Its channel reads `[user-branch]` because it is a tag
checkout rather than a branch; the revision is identical, and the revision is
what decides what gets compiled.

### CI is pinned, not `stable`

Both Codemagic workflows previously read `flutter: stable` — whatever the runner
happened to have that day. The same commit could be built by two different SDKs
with nothing recording which. Both now read `flutter: 3.47.2`, and the workflow
prints the toolchain it actually got, so the claim is checkable rather than
asserted.

---

## Android

| | |
|---|---|
| Gradle wrapper | 8.14-all |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |
| JDK | Microsoft OpenJDK **17.0.18.8** (`JAVA_HOME`) |
| compileSdk / targetSdk | **36 / 36** — read from the AAB manifest |
| minSdk | 24 |
| Play Billing | **`com.android.billingclient:billing:8.0.0`** — read from the AAB's dependency metadata |

### Artifact

| | |
|---|---|
| File | `build/app/outputs/bundle/release/app-release.aab` |
| Size | 63,228,264 bytes |
| SHA-256 | `8cc2db7018412890cf1f2d5f941b616209be958638154b97eda63fdc12f9353c` |
| Application id | `com.orchestrateops.app` |
| versionName / versionCode | **1.0.0 / 14** |
| Signing subject | `CN=Orchestrate, OU=Engineering, O=Aura Platform LLC, L=New York, ST=New York, C=US` |
| Signing SHA-256 | `1E:91:61:8C:5F:CB:A5:55:00:A1:3C:6C:CA:9E:C4:A3:AB:C5:E4:F0:5C:A5:2A:66:CE:D6:70:53:B2:8C:70:C6` |
| Certificate validity | 2026-05-08 → 2053-09-23 |
| ABIs | arm64-v8a, armeabi-v7a, x86_64 |

### The size change, accounted for

The bundle grew from 46.7 MB (Flutter 3.41.4) to 60.3 MB. The difference is
entirely `BUNDLE-METADATA`, which Google Play strips and which never reaches a
device:

- `com.android.tools.build.obfuscation/proguard.map` — 14 MB, **new**
- `libapp.so.sym` debug symbols for all three ABIs — ~33 MB, **new**

Same three ABIs as before. No additional architecture, no additional payload.

---

## Windows

| | |
|---|---|
| Packaging tool | `msix` 3.16.13 |
| Package identity | `AuraPlatformLLC.Orchestrateoperations` |
| Package version | **1.0.0.0** |
| Publisher | `CN=3E4027A7-4D4D-4492-B8DE-BBE425E307E5` |
| Display / publisher name | Orchestrate Operations · Aura Platform LLC |
| Target device family | `Windows.Desktop` min `10.0.17763.0` |
| Signature | **none** — a Store submission package is signed by the Store |
| Size | 15,940,401 bytes |
| SHA-256 | `45915bb43bfa48f8aa9d9dd3bde9db9055c3b9ba0951b2bac85d432b4ab34eec` |

The absence of a signature block is the correct state, not a gap: this is the
`store: true` package. No self-signed development package is used as release
evidence.

`1.0.0.0` is monotonic over the distributed `0.2.3.0` because the major moved.
The revision stays zero, as the Store requires.

---

## iOS

| | |
|---|---|
| Xcode | **26.6** (build 17F113) |
| iOS SDK | **26.5** (`iphoneos26.5`, `iphonesimulator26.5`) |
| Flutter / Dart on the runner | 3.47.2 / 3.13.2 — same revision as local |
| Bundle id | `com.orchestrateops.app` |
| Version read from the running app | `IOS 1.0.0 (14)` |

Apple's minimum is the iOS/iPadOS 26 SDK or later, so 26.5 satisfies it.

### A stated provenance limitation

**No `ios/Podfile` or `ios/Podfile.lock` is committed.** CocoaPods resolves
fresh on every build, so the iOS native dependency set is reproducible by date
rather than by lock, in the way `pubspec.lock` pins the Dart packages.

Nothing is failing because of it and the iOS build succeeds without it. It is
recorded here rather than quietly fixed hours before a release cut, because
committing a generated Podfile at this point would change the iOS dependency
resolution with no time to certify the change.

---

## Superseded artifacts

The AAB and MSIX built with **Flutter 3.41.4 / Dart 3.11.1** are:

```
PROVENANCE_SUPERSEDED — DO NOT SUBMIT
```

| Superseded artifact | SHA-256 |
|---|---|
| `app-release.aab` (3.41.4) | `0ce8ca0dfef63f11c8e0fbc07d939c05a51cd07675b5011abbc1bca94683cd98` |
| `orchestrate_app.msix` (3.41.4) | `8b23477ee6080ea6575c32b30410e95568fb45ece35d309e7163d3fef5b1d2fd` |

They are retained only as comparison evidence for the size analysis above.

A third AAB was produced during the SDK move and discarded without being
hashed into the record: the Gradle migrator wrote `android.builtInKotlin` and
`android.newDsl` *during* that build, so Gradle may have configured itself
before those flags existed. An artifact that cannot be said to match the frozen
source is not a candidate, so `build/app` was deleted and the bundle rebuilt.

---

## How to reproduce

```
git checkout 725f40fc7fb88b14cc50868f1b0997a25c8e2ab0
# a Flutter SDK at tag 3.47.2 — verify: git -C <sdk> rev-parse HEAD
#   must be d3b14c876900e553bc736ca19295fc09e3853e8e
<sdk>/bin/flutter clean && rm -rf build .dart_tool
<sdk>/bin/flutter pub get          # pubspec.lock must not change
<sdk>/bin/flutter analyze          # clean
<sdk>/bin/flutter test             # 408 pass
<sdk>/bin/flutter build appbundle --release
<sdk>/bin/dart run msix:create --store
```

iOS is built by the `ios-simulator-certification` and `ios-testflight`
Codemagic workflows from the same commit, both pinned to Flutter 3.47.2.
