#!/usr/bin/env python3
"""Verify the built iPhone/Watch companion relationship before packaging."""
from pathlib import Path
import plistlib
import subprocess
import sys

app = Path(sys.argv[1])
watch = app / "Watch/ErosionPlusWatch.app"
phone_info = plistlib.loads((app / "Info.plist").read_bytes())
watch_info = plistlib.loads((watch / "Info.plist").read_bytes())
bundle_id = "io.github.su-cyber-art.ErosionPlus"
assert phone_info["CFBundleIdentifier"] == bundle_id
assert watch_info["CFBundleIdentifier"] == bundle_id + ".watchkitapp"
assert watch_info["WKCompanionAppBundleIdentifier"] == bundle_id
for field in ["CFBundleShortVersionString", "CFBundleVersion"]:
    assert phone_info[field] == watch_info[field], field
for target, info in [(app, phone_info), (watch, watch_info)]:
    assert (target / info["CFBundleExecutable"]).is_file()
    result = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", str(target)], capture_output=True, check=True)
    entitlements = plistlib.loads(result.stdout)
    assert entitlements["com.apple.security.application-groups"] == ["group." + bundle_id]
print(f"Verified Erosion Plus {phone_info['CFBundleShortVersionString']} (Build {phone_info['CFBundleVersion']}) and Watch companion.")
