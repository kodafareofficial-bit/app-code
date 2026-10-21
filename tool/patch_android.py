#!/usr/bin/env python3
"""Patches the generated android/app/src/main/AndroidManifest.xml.

usage: patch_android.py <api_base_url> <app_label>
"""
import pathlib
import re
import sys

api = sys.argv[1] if len(sys.argv) > 1 else ""
label = sys.argv[2] if len(sys.argv) > 2 else "Code Offer"

path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = path.read_text(encoding="utf-8")

# 1) INTERNET permission (the template only has it in debug/profile manifests)
if "android.permission.INTERNET" not in s:
    s = re.sub(r"(<application\b)", '<uses-permission android:name="android.permission.INTERNET"/>\n    \\1', s, count=1)

# 2) allow plain-http only when the API URL is http (e.g. testing); https stays strict
if api.startswith("http://") and "usesCleartextTraffic" not in s:
    s = re.sub(r"<application\b", '<application\n        android:usesCleartextTraffic="true"', s, count=1)

# 3) url_launcher (Android 11+ package visibility)
extra = (
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="http"/></intent>\n'
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>\n'
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="mailto"/></intent>\n'
)
if "android:scheme=\"tel\"" not in s:
    if "<queries>" in s:
        s = s.replace("<queries>", "<queries>\n" + extra, 1)
    else:
        s = s.replace("</manifest>", "    <queries>\n" + extra + "    </queries>\n</manifest>", 1)

# 4) launcher label
s, n = re.subn(r'android:label="[^"]*"', 'android:label="%s"' % label.replace('"', "&quot;"), s, count=1)

path.write_text(s, encoding="utf-8")
print("AndroidManifest patched (label replaced: %s, cleartext: %s)" % (bool(n), api.startswith("http://")))
