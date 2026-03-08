#!/usr/bin/env python3
"""
Submit a TestFlight build to App Store review via App Store Connect API.

Usage: called by .github/workflows/promote-appstore.yml

Environment variables:
  KEY_ID        — App Store Connect API key ID (e.g. 88R6NGQ7J4)
  ISSUER_ID     — App Store Connect issuer ID
  BUNDLE_ID     — App bundle ID (e.g. com.aiwodtimer.app)
  BUILD_NUMBER  — Build number to promote (github.run_number from deploy workflow)
  VERSION       — Marketing version string (e.g. 1.0.0)
  KEY_PATH      — Path to .p8 private key file
"""

import os
import sys
import time
import requests
import jwt  # PyJWT

KEY_ID = os.environ["KEY_ID"]
ISSUER_ID = os.environ["ISSUER_ID"]
BUNDLE_ID = os.environ["BUNDLE_ID"]
BUILD_NUMBER = os.environ["BUILD_NUMBER"]
VERSION = os.environ["VERSION"]
KEY_PATH = os.path.expanduser(os.environ["KEY_PATH"])

BASE_URL = "https://api.appstoreconnect.apple.com/v1"


def _token() -> str:
    with open(KEY_PATH) as f:
        private_key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


def _headers() -> dict:
    return {"Authorization": f"Bearer {_token()}", "Content-Type": "application/json"}


def api_get(path: str) -> dict:
    resp = requests.get(f"{BASE_URL}{path}", headers=_headers())
    if not resp.ok:
        print(f"GET {path} failed {resp.status_code}: {resp.text}")
        sys.exit(1)
    return resp.json()


def api_post(path: str, body: dict) -> dict:
    resp = requests.post(f"{BASE_URL}{path}", headers=_headers(), json=body)
    if not resp.ok:
        print(f"POST {path} failed {resp.status_code}: {resp.text}")
        sys.exit(1)
    return resp.json() if resp.content else {}


def api_patch(path: str, body: dict) -> None:
    resp = requests.patch(f"{BASE_URL}{path}", headers=_headers(), json=body)
    if not resp.ok:
        print(f"PATCH {path} failed {resp.status_code}: {resp.text}")
        sys.exit(1)


def get_app_id() -> str:
    data = api_get(f"/apps?filter[bundleId]={BUNDLE_ID}")
    apps = data.get("data", [])
    if not apps:
        print(f"No app found with bundle ID {BUNDLE_ID}")
        sys.exit(1)
    app_id = apps[0]["id"]
    print(f"App ID: {app_id}")
    return app_id


def get_or_create_version(app_id: str) -> str:
    # Check for existing editable version matching VERSION
    data = api_get(
        f"/apps/{app_id}/appStoreVersions"
        f"?filter[platform]=IOS"
        f"&filter[appStoreState]=PREPARE_FOR_SUBMISSION"
    )
    for v in data.get("data", []):
        if v["attributes"]["versionString"] == VERSION:
            version_id = v["id"]
            print(f"Found existing version {VERSION}: {version_id}")
            return version_id

    # Create a new version
    print(f"Creating App Store version {VERSION}...")
    body = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": VERSION},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    data = api_post("/appStoreVersions", body)
    version_id = data["data"]["id"]
    print(f"Created version {VERSION}: {version_id}")
    return version_id


def get_build_id(app_id: str) -> str:
    data = api_get(
        f"/builds"
        f"?filter[app]={app_id}"
        f"&filter[version]={BUILD_NUMBER}"
        f"&filter[platform]=IOS"
        f"&sort=-uploadedDate"
        f"&limit=1"
    )
    builds = data.get("data", [])
    if not builds:
        print(f"No build found with build number {BUILD_NUMBER} for app {app_id}")
        print("Make sure the deploy-ios workflow completed successfully first.")
        sys.exit(1)
    build_id = builds[0]["id"]
    print(f"Build ID: {build_id}")
    return build_id


def attach_build(version_id: str, build_id: str) -> None:
    print(f"Attaching build {build_id} to version {version_id}...")
    api_patch(
        f"/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
    )
    print("Build attached.")


def submit_for_review(version_id: str) -> None:
    print(f"Submitting for App Store review...")
    body = {
        "data": {
            "type": "appStoreVersionSubmissions",
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                }
            },
        }
    }
    api_post("/appStoreVersionSubmissions", body)
    print("Submitted for review.")


def main() -> None:
    print(f"Promoting build {BUILD_NUMBER} (v{VERSION}) to App Store review...")
    app_id = get_app_id()
    version_id = get_or_create_version(app_id)
    build_id = get_build_id(app_id)
    attach_build(version_id, build_id)
    submit_for_review(version_id)
    print(f"\nDone. Build {BUILD_NUMBER} submitted for App Store review.")
    print("Track status at https://appstoreconnect.apple.com")


if __name__ == "__main__":
    main()
