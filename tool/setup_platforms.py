#!/usr/bin/env python3
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent


def patch_manifest():
    path = root / "android/app/src/main/AndroidManifest.xml"
    if not path.exists():
        print("! AndroidManifest.xml not found - skipped")
        return
    text = path.read_text()

    if "android.permission.INTERNET" not in text:
        text = text.replace(
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">",
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
            "    <uses-permission android:name=\"android.permission.INTERNET\"/>",
            1,
        )
    if "android:allowBackup" not in text:
        text = text.replace("<application", "<application\n        android:allowBackup=\"false\"", 1)
    text = re.sub(r'android:label="[^"]*"', 'android:label="LabConnect"', text, count=1)
    path.write_text(text)
    print("ok AndroidManifest.xml")


def patch_gradle():
    for name in ("build.gradle.kts", "build.gradle"):
        path = root / "android/app" / name
        if not path.exists():
            continue
        text = path.read_text()
        new = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 23" if name.endswith(".kts") else "minSdkVersion 23", text)
        new = re.sub(r"minSdk(Version)?\s*=\s*\d+", "minSdk = 23" if name.endswith(".kts") else "minSdkVersion 23", new) if name.endswith(".kts") else new
        path.write_text(new)
        print("ok", name)
        return
    print("! android/app/build.gradle(.kts) not found - skipped")


def patch_plist():
    path = root / "ios/Runner/Info.plist"
    if not path.exists():
        print("! Info.plist not found - skipped")
        return
    text = path.read_text()
    text = re.sub(
        r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
        r"\1LabConnect\2",
        text,
        count=1,
    )
    path.write_text(text)
    print("ok Info.plist")


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
    patch_plist()
    sys.exit(0)
