#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


API = "https://api.appstoreconnect.apple.com/v1"
ISSUER_ID = "26cc2279-524d-4d33-ba75-9333cf111ad1"
KEY_ID = "668Z2T3Q47"
APP_ID = os.environ.get("APP_STORE_APP_ID", "6801506973")
VERSION_STRING = os.environ.get("APP_STORE_VERSION", "1.1.0")
BUILD_NUMBER = os.environ.get("APP_STORE_BUILD", "39")

WHATS_NEW_AR = (
    "تحسين استقرار التشغيل على iPhone وiPad، ومعالجة مشكلة الشاشة السوداء عند فتح اللعبة، "
    "وتحديث بناء iOS ليتوافق مع متطلبات App Store الحالية."
)
WHATS_NEW_EN = (
    "Improves iPhone and iPad launch stability, fixes a blank-screen startup issue, "
    "and updates the iOS build pipeline for current App Store requirements."
)


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
        value = der[i + 2 : i + 2 + length].lstrip(b"\x00")
        return value.rjust(32, b"\x00"), i + 2 + length

    r, index = read_int(index)
    s, _ = read_int(index)
    return f"{header}.{payload}.{b64url(r + s)}"


TOKEN = jwt_token()


def request(method: str, path: str, body: dict | None = None) -> dict:
    url = path if path.startswith("https://") else f"{API}{path}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"{method} {url} failed: {exc.code} {raw}") from exc
    return json.loads(raw.decode("utf-8")) if raw else {}


def q(params: dict[str, str]) -> str:
    return urllib.parse.urlencode(params, safe=",")


def get_ios_version() -> dict:
    params = q(
        {
            "filter[platform]": "IOS",
            "filter[versionString]": VERSION_STRING,
            "fields[appStoreVersions]": "versionString,appStoreState,platform,createdDate",
            "limit": "10",
        }
    )
    data = request("GET", f"/apps/{APP_ID}/appStoreVersions?{params}")["data"]
    if not data:
        raise RuntimeError(f"No iOS App Store version {VERSION_STRING} found for app {APP_ID}")
    return data[0]


def get_build() -> dict:
    params = q(
        {
            "filter[app]": APP_ID,
            "filter[version]": BUILD_NUMBER,
            "fields[builds]": "version,processingState,uploadedDate,usesNonExemptEncryption,minOsVersion,expired",
            "sort": "-uploadedDate",
            "limit": "10",
        }
    )
    data = request("GET", f"/builds?{params}")["data"]
    if not data:
        raise RuntimeError(f"No build {BUILD_NUMBER} found for app {APP_ID}")
    build = data[0]
    state = build.get("attributes", {}).get("processingState")
    if state != "VALID":
        raise RuntimeError(f"Build {BUILD_NUMBER} is not VALID; current processingState={state}")
    return build


def list_recent_builds() -> list[dict]:
    params = q(
        {
            "filter[app]": APP_ID,
            "fields[builds]": "version,processingState,uploadedDate,usesNonExemptEncryption,minOsVersion,expired",
            "limit": "20",
        }
    )
    data = request("GET", f"/builds?{params}")["data"]
    data.sort(key=lambda item: item.get("attributes", {}).get("uploadedDate", ""), reverse=True)
    return data


def get_localizations(version_id: str) -> list[dict]:
    params = q(
        {
            "fields[appStoreVersionLocalizations]": "locale,whatsNew,description,keywords,marketingUrl,promotionalText,supportUrl",
            "limit": "50",
        }
    )
    return request("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?{params}")["data"]


def update_whats_new(localizations: list[dict]) -> list[dict[str, str]]:
    updated = []
    for loc in localizations:
        locale = loc.get("attributes", {}).get("locale", "")
        text = WHATS_NEW_AR if locale.startswith("ar") else WHATS_NEW_EN
        request(
            "PATCH",
            f"/appStoreVersionLocalizations/{loc['id']}",
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc["id"],
                    "attributes": {"whatsNew": text},
                }
            },
        )
        updated.append({"id": loc["id"], "locale": locale, "whatsNew": text})
    return updated


def set_version_build(version_id: str, build_id: str) -> None:
    request(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
    )


def get_review_submission(version_id: str) -> dict | None:
    params = q(
        {
            "fields[reviewSubmissions]": "state,submittedDate",
            "filter[app]": APP_ID,
            "include": "items",
            "fields[reviewSubmissionItems]": "state",
            "limit": "20",
        }
    )
    submissions = request("GET", f"/reviewSubmissions?{params}").get("data", [])
    for submission in submissions:
        relationships = submission.get("relationships", {})
        items = relationships.get("items", {}).get("data", [])
        for item in items:
            full_item = request(
                "GET",
                f"/reviewSubmissionItems/{item['id']}?include=appStoreVersion&fields[appStoreVersions]=versionString",
            )
            included = full_item.get("included", [])
            if any(i.get("type") == "appStoreVersions" and i.get("id") == version_id for i in included):
                return submission
    return None


def create_review_submission() -> str:
    created = request(
        "POST",
        "/reviewSubmissions",
        {
            "data": {
                "type": "reviewSubmissions",
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        },
    )
    return created["data"]["id"]


def add_version_to_review(submission_id: str, version_id: str) -> str:
    try:
        created = request(
            "POST",
            "/reviewSubmissionItems",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            },
        )
        return created["data"]["id"]
    except RuntimeError as exc:
        match = re.search(r"another reviewSubmission with id ([0-9a-f-]+)", str(exc))
        if not match:
            raise
        return f"existing-submission:{match.group(1)}"


def submit_review(submission_id: str) -> None:
    request(
        "PATCH",
        f"/reviewSubmissions/{submission_id}",
        {
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        },
    )


def snapshot() -> dict:
    version = get_ios_version()
    build = get_build()
    localizations = get_localizations(version["id"])
    submission = get_review_submission(version["id"])
    return {
        "version": version,
        "build": build,
        "localizations": [
            {"id": loc["id"], "locale": loc.get("attributes", {}).get("locale")}
            for loc in localizations
        ],
        "reviewSubmission": submission,
    }


def main() -> None:
    dry_run = "--dry-run" in sys.argv
    if "--list-builds" in sys.argv:
        version = get_ios_version()
        print(
            json.dumps(
                {
                    "appId": APP_ID,
                    "versionId": version["id"],
                    "versionString": version["attributes"]["versionString"],
                    "appStoreState": version["attributes"].get("appStoreState"),
                    "recentBuilds": list_recent_builds(),
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return
    version = get_ios_version()
    build = get_build()
    localizations = get_localizations(version["id"])
    before_submission = get_review_submission(version["id"])
    result = {
        "dryRun": dry_run,
        "appId": APP_ID,
        "versionId": version["id"],
        "versionString": version["attributes"]["versionString"],
        "appStoreStateBefore": version["attributes"].get("appStoreState"),
        "buildId": build["id"],
        "buildNumber": build["attributes"]["version"],
        "buildProcessingState": build["attributes"].get("processingState"),
        "buildUploadedDate": build["attributes"].get("uploadedDate"),
        "buildMinOsVersion": build["attributes"].get("minOsVersion"),
        "reviewSubmissionBefore": before_submission,
    }
    if dry_run:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    result["updatedLocalizations"] = update_whats_new(localizations)
    set_version_build(version["id"], build["id"])

    submission = before_submission
    if submission is None or submission.get("attributes", {}).get("state") in {"CANCELED", "COMPLETE"}:
        submission_id = create_review_submission()
        item_id = add_version_to_review(submission_id, version["id"])
    else:
        submission_id = submission["id"]
        item_id = add_version_to_review(submission_id, version["id"])
    if item_id.startswith("existing-submission:"):
        submission_id = item_id.removeprefix("existing-submission:")

    submit_review(submission_id)
    time.sleep(3)
    after = snapshot()
    result["reviewSubmissionId"] = submission_id
    result["reviewSubmissionItemId"] = item_id
    result["after"] = after
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
