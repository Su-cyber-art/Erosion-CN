#!/usr/bin/env python3
"""Generate the independent Erosion Plus sideloading source from its IPA releases."""

from __future__ import annotations

import hashlib
import io
import json
import os
import plistlib
import urllib.request
import zipfile
from pathlib import Path

REPO = os.environ.get("GITHUB_REPOSITORY", "Su-cyber-art/Erosion-CN")
BUNDLE_ID = "io.github.su-cyber-art.ErosionPlus"
MAX_VERSIONS = 8
ROOT = Path(__file__).resolve().parent.parent
OUTPUT_PATH = ROOT / "apps.json"

LOCALIZED_DESC = (
    "Erosion Plus 是基于 Erosion-CN 的中英双语独立应用，可与原版并存安装。\n\n"
    "• MobileGestalt 编辑、备份恢复、文件浏览与诊断\n"
    "• 应用启动图与通知铃声定制，含配对和通知路径采集\n"
    "• 新增 MG 预设及原值恢复\n\n"
    "重签时保留独立 Bundle ID 和 App Group 权限。两款应用修改的系统配置仍是同一份。\n\n"
    "Erosion Plus is a bilingual standalone fork of Erosion-CN with GestaltX feature ports. "
    "Keep its distinct bundle identifier and App Group entitlement when signing."
)


def http_get_bytes(url: str) -> bytes:
    headers = {
        "User-Agent": "ErosionPlus-AltStore-Sync/1.0",
        "Accept": "application/vnd.github+json",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token and ("api.github.com" in url or "github.com" in url):
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def inspect_ipa_bytes(ipa_bytes: bytes) -> dict:
    meta: dict = {}
    with zipfile.ZipFile(io.BytesIO(ipa_bytes), "r") as zf:
        info_names = [
            n for n in zf.namelist()
            if n.startswith("Payload/") and n.endswith(".app/Info.plist") and n.count("/") == 2
        ]
        if info_names:
            info = plistlib.loads(zf.read(info_names[0]))
            if info.get("CFBundleVersion"):
                meta["buildVersion"] = str(info["CFBundleVersion"])
            if info.get("MinimumOSVersion"):
                meta["minOSVersion"] = str(info["MinimumOSVersion"])
            if info.get("CFBundleIdentifier"):
                meta["bundleIdentifier"] = str(info["CFBundleIdentifier"])
    return meta


def load_existing_versions() -> dict[str, dict]:
    if not OUTPUT_PATH.exists():
        return {}
    existing = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
    for app in existing["apps"]:
        if app["bundleIdentifier"] == BUNDLE_ID:
            return {v["version"]: v for v in app["versions"]}
    return {}


def main() -> None:
    existing_by_ver = load_existing_versions()
    api_url = f"https://api.github.com/repos/{REPO}/releases?per_page=20"
    releases = json.loads(http_get_bytes(api_url).decode("utf-8"))

    versions_out: list[dict] = []
    bundle_id = BUNDLE_ID

    for rel in releases:
        if rel.get("draft") or rel.get("prerelease"):
            continue
        assets = [a for a in rel.get("assets", [])
                  if a["name"].startswith("ErosionPlus_") and a["name"].endswith("_Bilingual.ipa")]
        if not assets:
            continue
        asset = assets[0]
        tag = str(rel.get("tag_name") or "").strip()
        version = tag.lstrip("vV")
        if not version:
            continue

        prev = existing_by_ver.get(version, {})
        digest_raw = str(asset.get("digest") or "")
        sha256 = digest_raw.split("sha256:", 1)[1].lower() if digest_raw.startswith("sha256:") else None
        build_ver = prev.get("buildVersion")
        min_os = prev.get("minOSVersion", "26.0")

        # Cached metadata is reusable only for the same previously inspected asset.
        same_asset = (sha256 and sha256 == prev.get("sha256") and build_ver
                      and prev.get("minOSVersion") and prev.get("size") == asset["size"]
                      and prev.get("downloadURL") == asset["browser_download_url"])
        if not same_asset:
            req = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": "ErosionPlus-AltStore-Sync/1.0"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                ipa_bytes = resp.read()
            if not sha256:
                sha256 = hashlib.sha256(ipa_bytes).hexdigest()
            ipa_meta = inspect_ipa_bytes(ipa_bytes)
            if ipa_meta.get("bundleIdentifier") != BUNDLE_ID:
                raise RuntimeError(f"Refusing {asset['name']}: IPA bundle identifier is not {BUNDLE_ID}.")
            build_ver = ipa_meta["buildVersion"]
            min_os = ipa_meta["minOSVersion"]

        entry: dict = {
            "version": version,
        }
        if build_ver:
            entry["buildVersion"] = build_ver
        entry.update({
            "date": rel.get("published_at") or rel.get("created_at"),
            "localizedDescription": (rel.get("body") or f"Erosion Plus v{version}").strip(),
            "downloadURL": asset["browser_download_url"],
            "size": int(asset["size"]),
            "sha256": sha256,
            "minOSVersion": min_os,
        })
        versions_out.append(entry)
        if len(versions_out) >= MAX_VERSIONS:
            break

    if not versions_out:
        raise RuntimeError("No ErosionPlus_*_Bilingual.ipa releases found on GitHub.")

    latest = versions_out[0]
    icon_url = f"https://raw.githubusercontent.com/{REPO}/main/PreviewIcon.png"

    app_obj: dict = {
        "name": "Erosion Plus",
        "bundleIdentifier": bundle_id,
        "developerName": REPO.split("/", 1)[0],
        "subtitle": "iOS / iPadOS 系统配置与 MobileGestalt 研究工具箱（中英双语）",
        "localizedDescription": LOCALIZED_DESC,
        "iconURL": icon_url,
        "tintColor": "#CF7D46",
        "category": "utilities",
        "screenshots": [],
        "appPermissions": {
            "entitlements": [
                "com.apple.security.application-groups"
            ],
            "privacy": {},
        },
        "version": latest["version"],
    }
    if "buildVersion" in latest:
        app_obj["buildVersion"] = latest["buildVersion"]
    app_obj.update({
        "versionDate": latest["date"],
        "versionDescription": latest["localizedDescription"],
        "downloadURL": latest["downloadURL"],
        "size": latest["size"],
        "versions": versions_out,
    })

    source_doc = {
        "name": "Erosion Plus",
        "identifier": BUNDLE_ID + ".source",
        "subtitle": "Erosion Plus 独立版更新源 (SideStore / AltStore / Feather)",
        "description": LOCALIZED_DESC,
        "iconURL": icon_url,
        "website": f"https://github.com/{REPO}",
        "tintColor": "#CF7D46",
        "featuredApps": [bundle_id],
        "apps": [app_obj],
        "news": [],
    }

    OUTPUT_PATH.write_text(
        json.dumps(source_doc, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"[OK] Wrote {OUTPUT_PATH} with {len(versions_out)} versions (latest: v{latest['version']}, build {latest.get('buildVersion')}).")


if __name__ == "__main__":
    main()
