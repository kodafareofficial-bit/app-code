#!/usr/bin/env python3
"""Wires android/key.properties into android/app/build.gradle for release signing.
If the file layout is not recognised the build continues with the debug key (and a warning)."""
import pathlib
import re

g = pathlib.Path("android/app/build.gradle")
if not g.exists():
    print("::warning::android/app/build.gradle not found (Kotlin DSL?) - release signing skipped")
    raise SystemExit(0)

s = g.read_text(encoding="utf-8")
if "signingConfigs.release" in s:
    print("signing already configured")
    raise SystemExit(0)

loader = """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""
signing = """    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

"""

s2, n1 = re.subn(r"^android\s*\{", lambda m: loader + m.group(0), s, count=1, flags=re.M)
s2, n2 = re.subn(r"^(\s*)buildTypes\s*\{", lambda m: signing + m.group(0), s2, count=1, flags=re.M)
s2, n3 = re.subn(r"signingConfig\s*=?\s*signingConfigs\.debug", "signingConfig = signingConfigs.release", s2, count=1)

if not (n1 and n2 and n3):
    print("::warning::could not patch build.gradle for release signing (%s,%s,%s) - using debug key" % (n1, n2, n3))
    raise SystemExit(0)

g.write_text(s2, encoding="utf-8")
print("release signing configured")
