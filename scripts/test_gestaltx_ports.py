#!/usr/bin/env python3
"""Run host-side regressions for imported customization features using temporary files."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CUSTOM = ROOT / "Erosion/Tweaks/AppCustomization"
CONSOLE = ROOT / "Erosion/Helpers/DeviceConsole"
COMMON = [CUSTOM / name for name in ["CustomizationFiles.swift", "CustomizationLocalization.swift"]]
ARTWORK = COMMON + [CUSTOM / name for name in [
    "ContainerOriginals.swift", "LaunchArtworkFiles.swift", "LaunchArtworkImages.swift", "LaunchArtworkStore.swift",
]]
PARSER = [CONSOLE / "NotificationSoundLogParser.swift"]
WATCH = [ROOT / "Shared/Watch" / name for name in ["WatchLocalization.swift", "WatchMGWire.swift", "WatchMGDocument.swift"]]
SUITES = {
    "LaunchArtworkTests": ARTWORK,
    "AppSoundTests": ARTWORK + [CUSTOM / name for name in ["AppSoundFiles.swift", "AppSoundCodec.swift", "AppSoundStore.swift"]],
    "LaunchArtworkCatalogTests": ARTWORK + [CUSTOM / name for name in ["LaunchArtworkCatalog.swift", "SharedApplicationInventory.swift"]],
    "NotificationSoundLogParserTests": PARSER,
    "CapturedSoundStoreTests": COMMON + PARSER + [CONSOLE / "DeviceConsolePaths.swift", CONSOLE / "CapturedSoundStore.swift"],
    "MGExtraPresetTests": COMMON + [ROOT / "Erosion/Tweaks/MobileGestalt/MGExtraPreset.swift"],
    "WatchMG": WATCH + [ROOT / "Shared/Watch/WatchMGService.swift"],
    "WatchTweaks": WATCH + [ROOT / "Erosion/Tweaks/Watch/WatchTweaks.swift"],
    "WatchDocumentTests": WATCH,
    "InPlaceWriteTests": [ROOT / "Shared/InPlaceWrite.swift"],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", dest="suites", action="append", choices=list(SUITES))
    args = parser.parse_args()
    swift_files = [path for folder in ["Erosion", "ErosionWatch", "Shared"] for path in (ROOT / folder).rglob("*.swift")]
    subprocess.run(["swiftc", "-frontend", "-parse", *map(str, sorted(swift_files))], check=True)
    with tempfile.TemporaryDirectory(prefix="erosion-port-tests-") as temporary:
        work = Path(temporary)
        localization = work / "HostLocalization.swift"
        localization.write_text("import Foundation\nnonisolated enum LocalizationManager { static var activeBundle: Bundle { .main } }\n")
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-fsyntax-only",
            *map(str, sorted((ROOT / "Erosion/Exploits/Customization").glob("*.m"))),
            *map(str, sorted((ROOT / "ErosionWatch/Access").glob("*.m"))),
            str(ROOT / "ErosionWatch/WatchRespring.m"),
        ], check=True, timeout=60)
        lease_test = work / "watch-cache-lease"
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-framework", "Foundation",
            "-I", str(ROOT / "ErosionWatch/Access"), str(ROOT / "ErosionWatch/Access/GestaltCacheLease.m"),
            str(ROOT / "tests/WatchCacheLeaseTests.m"), "-o", str(lease_test),
        ], check=True, timeout=60)
        subprocess.run([str(lease_test)], check=True, timeout=30)
        subprocess.run([
            "swiftc", "-typecheck", "-warnings-as-errors", "-swift-version", "5", "-default-isolation", "MainActor",
            "-D", "GXDEVICECONSOLE", "-import-objc-header", str(CONSOLE / "GXDeviceConsole.h"),
            str(localization), str(CUSTOM / "CustomizationLocalization.swift"),
            *[str(CONSOLE / f"{name}.swift") for name in ["DeviceConsole", "DevicePairingStore", "DeviceConsolePaths", "LoopbackRoute"]],
        ], check=True, timeout=120)
        for name in args.suites or SUITES:
            binary = work / name
            test = ROOT / "tests" / (f"{name}/main.swift" if name in ["WatchMG", "WatchTweaks"] else f"{name}.swift")
            entry_flags = [] if name == "WatchTweaks" else ["-parse-as-library"]
            subprocess.run([
                "swiftc", "-swift-version", "5", "-default-isolation", "MainActor", *entry_flags,
                *map(str, SUITES[name]), str(localization), str(test), "-o", str(binary),
            ], check=True, timeout=180)
            arguments = [str(ROOT / "Shared/Watch")] if name == "WatchTweaks" else []
            subprocess.run([str(binary), *arguments], check=True, timeout=60)
            print(f"PASS {name}", flush=True)


if __name__ == "__main__":
    main()
