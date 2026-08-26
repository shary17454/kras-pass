#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API = "https://api.appstoreconnect.apple.com/v1"
ISSUER_ID = "26cc2279-524d-4d33-ba75-9333cf111ad1"
KEY_ID = "668Z2T3Q47"
APP_STORE_VERSION_LOCALIZATION_ID = os.environ.get(
    "APP_STORE_VERSION_LOCALIZATION_ID",
    "40f54014-70ee-426d-ada2-6279b13e5f59",
)

SCREENSHOT_GROUPS = {
    "APP_IPHONE_65": [
        ROOT / "assets/app_store/screenshots/iphone-01-party-arena.png",
        ROOT / "assets/app_store/screenshots/iphone-02-fast-rounds.png",
        ROOT / "assets/app_store/screenshots/iphone-03-local-chaos.png",
    ],
    "APP_IPAD_PRO_129": [
        ROOT / "assets/app_store/screenshots/ipad-01-party-arena.png",
        ROOT / "assets/app_store/screenshots/ipad-02-fast-rounds.png",
        ROOT / "assets/app_store/screenshots/ipad-03-local-chaos.png",
    ],
    "APP_IPAD_PRO_3GEN_129": [
        ROOT / "assets/app_store/screenshots/ipad-01-party-arena.png",
        ROOT / "assets/app_store/screenshots/ipad-02-fast-rounds.png",
        ROOT / "assets/app_store/screenshots/ipad-03-local-chaos.png",
    ],
}


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def jwt_token() -> str:
    key_path = Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode())
    payload = b64url(
        json.dumps(
            {"iss": ISSUER_ID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{payload}".encode()
    proc = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_path)],
        input=signing_input,
        stdout=subprocess.PIPE,
        check=True,
    )
    der = proc.stdout
    if der[0] != 0x30:
        raise RuntimeError("Unexpected ECDSA signature")
    index = 2
    if der[1] & 0x80:
        index = 2 + (der[1] & 0x7F)

    def read_int(i: int) -> tuple[bytes, int]:
        if der[i] != 0x02:
            raise RuntimeError("Unexpected ECDSA integer")
        length = der[i + 1]
        value = der[i + 2 : i + 2 + length]
        value = value.lstrip(b"\x00")
        return value.rjust(32, b"\x00"), i + 2 + length

    r, index = read_int(index)
    s, _ = read_int(index)
    return f"{header}.{payload}.{b64url(r + s)}"


TOKEN = jwt_token()


def request(method: str, url: str, body: dict | None = None, headers: dict[str, str] | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode("utf-8")
    req_headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
    }
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        raise RuntimeError(f"{method} {url} failed: {exc.code} {raw.decode('utf-8', 'replace')}")
    return json.loads(raw.decode("utf-8")) if raw else {}


def delete(url: str) -> None:
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {TOKEN}"}, method="DELETE")
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            response.read()
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raw = exc.read()
            raise RuntimeError(f"DELETE {url} failed: {exc.code} {raw.decode('utf-8', 'replace')}")


def upload_part(operation: dict, file_bytes: bytes) -> None:
    offset = int(operation["offset"])
    length = int(operation["length"])
    part = file_bytes[offset : offset + length]
    headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
    req = urllib.request.Request(operation["url"], data=part, headers=headers, method=operation["method"])
    try:
        with urllib.request.urlopen(req, timeout=180) as response:
            response.read()
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        raise RuntimeError(f"asset upload failed: {exc.code} {raw.decode('utf-8', 'replace')}")


def get_or_create_set(display_type: str) -> str:
    existing = request(
        "GET",
        f"{API}/appStoreVersionLocalizations/{APP_STORE_VERSION_LOCALIZATION_ID}/appScreenshotSets"
        f"?fields%5BappScreenshotSets%5D=screenshotDisplayType&limit=50",
    )
    for item in existing.get("data", []):
        if item.get("attributes", {}).get("screenshotDisplayType") == display_type:
            return item["id"]
    created = request(
        "POST",
        f"{API}/appScreenshotSets",
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "id": APP_STORE_VERSION_LOCALIZATION_ID,
                        }
                    }
                },
            }
        },
    )
    return created["data"]["id"]


def remove_existing_screenshots() -> list[str]:
    removed: list[str] = []
    sets = request(
        "GET",
        f"{API}/appStoreVersionLocalizations/{APP_STORE_VERSION_LOCALIZATION_ID}/appScreenshotSets"
        "?fields%5BappScreenshotSets%5D=screenshotDisplayType,appScreenshots&include=appScreenshots&fields%5BappScreenshots%5D=fileName,assetDeliveryState&limit=50",
    )
    screenshot_to_set: dict[str, str] = {}
    for item in sets.get("data", []):
        display_type = item.get("attributes", {}).get("screenshotDisplayType", "")
        for relation in item.get("relationships", {}).get("appScreenshots", {}).get("data", []):
            screenshot_to_set[relation["id"]] = display_type

    for screenshot in sets.get("included", []):
        screenshot_id = screenshot["id"]
        attrs = screenshot.get("attributes", {})
        state = attrs.get("assetDeliveryState", {}).get("state")
        display_type = screenshot_to_set.get(screenshot_id, "")
        if display_type in SCREENSHOT_GROUPS or state == "FAILED":
            delete(f"{API}/appScreenshots/{screenshot_id}")
            removed.append(screenshot_id)
    return removed


def upload_screenshot(set_id: str, path: Path) -> str:
    file_bytes = path.read_bytes()
    reservation = request(
        "POST",
        f"{API}/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileSize": len(file_bytes), "fileName": path.name},
                "relationships": {
                    "appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": set_id}
                    }
                },
            }
        },
    )
    screenshot_id = reservation["data"]["id"]
    for operation in reservation["data"]["attributes"]["uploadOperations"]:
        upload_part(operation, file_bytes)
    checksum = hashlib.md5(file_bytes).hexdigest()
    request(
        "PATCH",
        f"{API}/appScreenshots/{screenshot_id}",
        {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
            }
        },
    )
    return screenshot_id


def main() -> None:
    removed = remove_existing_screenshots()
    uploaded: dict[str, list[str]] = {}
    skipped: dict[str, list[str]] = {}
    for display_type, files in SCREENSHOT_GROUPS.items():
        set_id = get_or_create_set(display_type)
        uploaded[display_type] = []
        skipped[display_type] = []
        for path in files:
            uploaded[display_type].append(upload_screenshot(set_id, path))

    states = {}
    for display_type, ids in uploaded.items():
        states[display_type] = []
        for screenshot_id in ids:
            state = None
            for _ in range(20):
                info = request(
                    "GET",
                    f"{API}/appScreenshots/{screenshot_id}?fields%5BappScreenshots%5D=assetDeliveryState,fileName,imageAsset",
                )
                attrs = info["data"]["attributes"]
                state = attrs.get("assetDeliveryState", {})
                if state.get("state") in {"COMPLETE", "FAILED"}:
                    break
                time.sleep(3)
            states[display_type].append({"id": screenshot_id, "state": state})

    print(json.dumps({"removed": removed, "skipped": skipped, "uploaded": uploaded, "states": states}, indent=2))


if __name__ == "__main__":
    main()
