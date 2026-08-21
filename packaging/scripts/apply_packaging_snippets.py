#!/usr/bin/env python3
"""
apply_packaging_snippets.py

Merges Petal's packaging/ snippets — the petalauth:// OAuth redirect scheme,
Android permissions, macOS sandbox entitlements, an Android compileSdk/targetSdk bump (app module), and iOS App-Store-review
usage-description strings — into the platform folders that `flutter create .`
generates. The content mirrors:

    packaging/android/AndroidManifest-snippet.xml
    packaging/ios-macos/Info-snippet.plist
    packaging/macos/entitlements-snippet.plist

WHEN TO RUN THIS
    After `flutter create . --platforms=...` (and after
    `dart run flutter_launcher_icons`), from the ROOT of the Flutter project
    — the folder containing pubspec.yaml, packaging/, and the generated
    android/, ios/, macos/ folders.

USAGE
    python3 packaging/scripts/apply_packaging_snippets.py

SAFETY
    - Every file this script touches gets a one-time ".orig" backup written
      next to it before any edit, so you can always `diff` or revert.
    - Safe to re-run: each merge checks whether it already applied (looks
      for the petalauth scheme / the same entitlement keys) and skips if so,
      rather than duplicating the insertion.
    - The plist-based merges (Info.plist URL scheme x2, entitlements x2,
      iOS usage descriptions x1) go through Python's plistlib, so they
      can't produce malformed XML. The Android
      manifest merge is a plain-text insertion at the two exact tag
      boundaries described in the packaging README, guarded by a check that
      each anchor tag appears exactly once before touching the file.
"""

import plistlib
import re
import shutil
from pathlib import Path

ROOT = Path.cwd()

# A real CI build failed with: ":audiotags:checkReleaseAarMetadata" listing
# 20 AndroidX dependencies that all require compileSdk 34+, while the
# generated project was compiling against android-31 — almost certainly
# because whatever local Flutter install ran `flutter create .` was old
# enough that `flutter.compileSdkVersion` (the default the template uses,
# tracking the Flutter tool's own bundled Android metadata rather than a
# number you set yourself) resolved to 31. That default keeps drifting
# with whichever Flutter version happens to run `flutter create .`, so
# this pins an explicit number instead — 36 matches Google Play Console's
# own current target API level requirement (support.google.com/
# googleplay/android-developer/answer/11926878), so it isn't just "high
# enough for today's plugins," it's the number you'd need for a Play Store
# submission anyway. minSdk is left untouched (set separately, unrelated
# to this failure).
ANDROID_SDK_VERSION = 37

URL_SCHEME = "petalauth"
URL_SCHEME_ENTRY = {
    "CFBundleURLSchemes": [URL_SCHEME],
    "CFBundleURLName": "com.petal.player.auth",
}

ENTITLEMENT_KEYS = {
    "com.apple.security.network.client": True,
    "com.apple.security.files.user-selected.read-only": True,
}

# A real, verified finding (not a guess): file_picker ships one unified
# Darwin binary that links Photos-framework code for its FileType.image/
# video support regardless of which FileType your own Dart code actually
# calls — Apple's App Store/TestFlight static-binary scan can flag a
# missing NSPhotoLibraryUsageDescription even though this app only ever
# uses FileType.custom for audio (see github.com/miguelpruivo/
# flutter_file_picker issue #783, where Apple's own review message says
# "While your app might not use these APIs, a purpose string is still
# required"). This is an iOS-only App Store review requirement, not a
# runtime permission dialog — the app never actually touches Photos.
IOS_USAGE_DESCRIPTIONS = {
    "NSPhotoLibraryUsageDescription": (
        "Petal uses the Files picker to let you choose audio files to import "
        "— it doesn't access your photo library."
    ),
    "NSAppleMusicUsageDescription": (
        "Petal doesn't read your Apple Music library. This string exists only "
        "because a bundled file-picker library links media framework code "
        "that Apple's App Store review checks for, even though Petal never "
        "calls it."
    ),
}

PERMISSION_BLOCK = (
    '    <uses-permission android:name="android.permission.INTERNET" />\n'
    '    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />\n'
    '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"\n'
    '        android:maxSdkVersion="32" />\n'
)

# NOTE: double-check this class name against your installed flutter_web_auth_2
# version before building — see packaging/android/AndroidManifest-snippet.xml
# for why this specific detail is flagged as uncertain.
ACTIVITY_BLOCK = (
    "        <activity\n"
    '            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"\n'
    '            android:exported="true">\n'
    '            <intent-filter android:label="petal_web_auth">\n'
    '                <action android:name="android.intent.action.VIEW" />\n'
    '                <category android:name="android.intent.category.DEFAULT" />\n'
    '                <category android:name="android.intent.category.BROWSABLE" />\n'
    f'                <data android:scheme="{URL_SCHEME}" />\n'
    "            </intent-filter>\n"
    "        </activity>\n"
)


def backup(path: Path):
    orig = path.with_name(path.name + ".orig")
    if not orig.exists():
        shutil.copy2(path, orig)
        print(f"      backed up -> {orig.name}")


def require(path: Path) -> bool:
    if not path.exists():
        print(f"SKIP  {path} — not found. Did you run `flutter create .` first?")
        return False
    return True


def merge_url_scheme(path: Path):
    if not require(path):
        return
    try:
        with open(path, "rb") as f:
            data = plistlib.load(f)
    except Exception as e:
        print(f"MANUAL {path.relative_to(ROOT)} — couldn't parse as plist ({e}); "
              f"paste packaging/ios-macos/Info-snippet.plist in by hand")
        return

    types = data.get("CFBundleURLTypes", [])
    already = any(URL_SCHEME in t.get("CFBundleURLSchemes", []) for t in types)
    if already:
        print(f"SKIP  {path.relative_to(ROOT)} — {URL_SCHEME}:// scheme already present")
        return

    types.append(dict(URL_SCHEME_ENTRY))
    data["CFBundleURLTypes"] = types

    backup(path)
    with open(path, "wb") as f:
        plistlib.dump(data, f)
    print(f"OK    {path.relative_to(ROOT)} — added {URL_SCHEME}:// URL scheme")


def merge_entitlements(path: Path):
    if not require(path):
        return
    try:
        with open(path, "rb") as f:
            data = plistlib.load(f)
    except Exception as e:
        print(f"MANUAL {path.relative_to(ROOT)} — couldn't parse as plist ({e}); "
              f"paste packaging/macos/entitlements-snippet.plist in by hand")
        return

    to_add = {k: v for k, v in ENTITLEMENT_KEYS.items() if data.get(k) != v}
    if not to_add:
        print(f"SKIP  {path.relative_to(ROOT)} — entitlements already present")
        return

    data.update(to_add)
    backup(path)
    with open(path, "wb") as f:
        plistlib.dump(data, f)
    print(f"OK    {path.relative_to(ROOT)} — added {', '.join(to_add)}")


def merge_ios_usage_descriptions(path: Path):
    """iOS-only (ios/Runner/Info.plist) — NOT applied to macOS's Info.plist,
    since the App Store static-scan issue this works around (see
    IOS_USAGE_DESCRIPTIONS' comment) is specific to iOS binary review, and
    macOS's file_picker implementation doesn't link the same Photos-
    framework code.
    """
    if not require(path):
        return
    try:
        with open(path, "rb") as f:
            data = plistlib.load(f)
    except Exception as e:
        print(f"MANUAL {path.relative_to(ROOT)} — couldn't parse as plist ({e}); "
              f"add NSPhotoLibraryUsageDescription / NSAppleMusicUsageDescription by hand")
        return

    to_add = {k: v for k, v in IOS_USAGE_DESCRIPTIONS.items() if k not in data}
    if not to_add:
        print(f"SKIP  {path.relative_to(ROOT)} — usage-description keys already present")
        return

    data.update(to_add)
    backup(path)
    with open(path, "wb") as f:
        plistlib.dump(data, f)
    print(f"OK    {path.relative_to(ROOT)} — added {', '.join(to_add)}")


def merge_manifest(path: Path):
    if not require(path):
        return
    text = path.read_text()

    if URL_SCHEME in text:
        print(f"SKIP  {path.relative_to(ROOT)} — {URL_SCHEME} scheme already present")
        return

    if text.count("</application>") != 1 or text.count("</manifest>") != 1:
        print(f"MANUAL {path.relative_to(ROOT)} — expected exactly one </application> and "
              f"one </manifest>, found something else (custom manifest?); "
              f"paste packaging/android/AndroidManifest-snippet.xml in by hand")
        return

    backup(path)

    # 1. Activity block goes INSIDE <application>...</application>, right
    #    before its closing tag (as a sibling of the existing .MainActivity).
    text = text.replace(
        "</application>", ACTIVITY_BLOCK + "    </application>", 1
    )

    # 2. Permissions go OUTSIDE <application>, as siblings, right before
    #    </manifest>.
    text = text.replace("</manifest>", PERMISSION_BLOCK + "</manifest>", 1)

    path.write_text(text)
    print(f"OK    {path.relative_to(ROOT)} — added permissions + CallbackActivity intent-filter")


def bump_android_sdk():
    """Sets compileSdk and targetSdk to ANDROID_SDK_VERSION in whichever
    Gradle file `flutter create .` generated — the Kotlin DSL
    `build.gradle.kts` (the current Flutter default) or the older Groovy
    `build.gradle`, whichever exists. Matches both DSLs' syntax variants:
    Kotlin's `compileSdk = flutter.compileSdkVersion` / `compileSdk = 31`,
    and Groovy's `compileSdkVersion flutter.compileSdkVersion` /
    `compileSdk 31`, same for targetSdk.
    """
    kts = ROOT / "android/app/build.gradle.kts"
    groovy = ROOT / "android/app/build.gradle"
    path = kts if kts.exists() else groovy if groovy.exists() else None

    if path is None:
        print(f"SKIP  android/app/build.gradle(.kts) — not found. Did you run "
              f"`flutter create .` first?")
        return

    text = path.read_text()
    original = text

    # keyword with optional "Version" suffix, then "=" or whitespace, then
    # either a flutter.* property reference or a literal integer. Matches
    # "compileSdk = flutter.compileSdkVersion", "compileSdk = 31",
    # "compileSdkVersion flutter.compileSdkVersion", "compileSdk 31", etc.
    def find_pattern(keyword: str) -> re.Pattern:
        return re.compile(
            rf'({re.escape(keyword)}(?:Version)?)(\s*=\s*|\s+)(flutter\.\w+|\d+)'
        )

    def bump(text: str, keyword: str) -> str:
        return find_pattern(keyword).sub(rf'\g<1>\g<2>{ANDROID_SDK_VERSION}', text)

    pattern_found = bool(find_pattern("compileSdk").search(text) or find_pattern("targetSdk").search(text))

    text = bump(text, "compileSdk")
    text = bump(text, "targetSdk")

    if text == original:
        if pattern_found:
            print(f"SKIP  {path.relative_to(ROOT)} — compileSdk/targetSdk already set to "
                  f"{ANDROID_SDK_VERSION}, nothing to change")
        else:
            print(f"SKIP  {path.relative_to(ROOT)} — compileSdk/targetSdk pattern not "
                  f"found (hand-customized build.gradle?); set both to "
                  f"{ANDROID_SDK_VERSION} by hand")
        return

    backup(path)
    path.write_text(text)
    print(f"OK    {path.relative_to(ROOT)} — compileSdk/targetSdk set to "
          f"{ANDROID_SDK_VERSION}")



  
def main():
    print("Applying Petal packaging snippets into platform folders...\n")

    steps = [
        ("iOS Info.plist", merge_url_scheme, ROOT / "ios/Runner/Info.plist"),
        ("macOS Info.plist", merge_url_scheme, ROOT / "macos/Runner/Info.plist"),
        ("macOS entitlements (Debug)", merge_entitlements, ROOT / "macos/Runner/DebugProfile.entitlements"),
        ("macOS entitlements (Release)", merge_entitlements, ROOT / "macos/Runner/Release.entitlements"),
        ("iOS usage descriptions (App Store review)", merge_ios_usage_descriptions, ROOT / "ios/Runner/Info.plist"),
        ("Android manifest", merge_manifest, ROOT / "android/app/src/main/AndroidManifest.xml"),
    ]

    for label, fn, path in steps:
        print(label)
        try:
            fn(path)
        except Exception as e:
            print(f"MANUAL {path} — script hit an unexpected error ({e}); "
                  f"paste the matching packaging/ snippet in by hand")
        print()

    print("Android compileSdk/targetSdk (app module)")
    try:
        bump_android_sdk()
    except Exception as e:
        print(f"MANUAL android/app/build.gradle(.kts) — script hit an unexpected "
              f"error ({e}); set compileSdk and targetSdk to {ANDROID_SDK_VERSION} by hand")
    print()



    print("Done. Diff against the *.orig backups to review exactly what changed, e.g.:")
    print("  diff ios/Runner/Info.plist.orig ios/Runner/Info.plist")
    print()
    print("Reminder: double-check the CallbackActivity class name the script wrote into")
    print("AndroidManifest.xml against your installed flutter_web_auth_2 package version")
    print("before building — see packaging/android/AndroidManifest-snippet.xml for why.")


if __name__ == "__main__":
    main()
