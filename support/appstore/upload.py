#!/usr/bin/env python3
"""Uploads the App Store listing (text + screenshots) through the App Store Connect API.

Needs an API key (Users and Access > Integrations > App Store Connect API, role App Manager):
  ASC_ISSUER_ID=... ASC_KEY_ID=... python3 support/appstore/upload.py [--dry-run] [--screenshots DIR]
The .p8 is ASC_KEY_P8 (PEM or base64) or ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8.
Requires: pip install -r support/appstore/requirements.txt

--media-only uploads framed screenshots and the product-page header through the
Asset Library and never submits the version or the assets for review.

Text comes from support/appstore/metadata/<locale>/*.txt (see listing.py). Screenshots come from
DIR/<device>/<lang>/*.png, where device is iphone-6.9, ipad-13, appletv, vision or mac and lang is
"en" (en-GB, and the fallback for any locale without its own set), "no", "sv", "da" or "fi".
"""
import argparse
import base64
import glob
import hashlib
import os
import sys
import time

import jwt
import requests

BUNDLE_ID = "no.cryptonordic.tv"
VERSION = "1.1.0"
API = "https://api.appstoreconnect.apple.com/v1"
HERE = os.path.dirname(os.path.abspath(__file__))
# Every locale that listing.py wrote (en-GB first: the app's primary locale).
LOCALES = ["en-GB"] + sorted(d for d in os.listdir(os.path.join(HERE, "metadata")) if d != "en-GB")
PLATFORMS = {"IOS": ["iphone-6.9", "iphone-6.5", "ipad-13"], "TV_OS": ["appletv"], "VISION_OS": ["vision"], "MAC_OS": ["mac"]}
DISPLAY_TYPE = {
    "iphone-6.9": "APP_IPHONE_67",
    "iphone-6.5": "APP_IPHONE_65",
    "ipad-13": "APP_IPAD_PRO_3GEN_129",
    "appletv": "APP_APPLE_TV",
    "vision": "APP_APPLE_VISION_PRO",
    "mac": "APP_DESKTOP",
}
# The media workflow never calls these. A bug that does is a hard stop.
_NEVER_SUBMIT = ("/reviewSubmissions", "/reviewSubmissionItems", "/appStoreVersionSubmissions")


def marketing_version():
    yml = os.path.join(HERE, "..", "..", "project.yml")
    for line in open(yml):
        if line.strip().startswith("MARKETING_VERSION:"):
            return line.split(":", 1)[1].strip().strip('"')
    sys.exit("MARKETING_VERSION not found in project.yml")


def load_private_key(key_id):
    """PEM from ASC_KEY_P8 (raw or base64), or AuthKey_<id>.p8 on disk."""
    raw = os.environ.get("ASC_KEY_P8", "").strip()
    if raw:
        if "BEGIN PRIVATE KEY" not in raw:
            try:
                decoded = base64.b64decode(raw).decode()
            except Exception:
                decoded = ""
            if "BEGIN PRIVATE KEY" in decoded:
                raw = decoded
        return raw.replace("\\n", "\n")
    path = os.environ.get("ASC_KEY_PATH") or os.path.expanduser(
        f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")
    with open(path) as fh:
        return fh.read()


class ASC:
    def __init__(self, issuer, key_id, dry_run):
        self.key = load_private_key(key_id)
        self.issuer, self.key_id, self.dry_run = issuer, key_id, dry_run
        self.token, self.token_time = None, 0

    def headers(self):
        if time.time() - self.token_time > 600:
            now = int(time.time())
            self.token = jwt.encode({"iss": self.issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                                    self.key, algorithm="ES256", headers={"kid": self.key_id, "typ": "JWT"})
            self.token_time = time.time()
        return {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"}

    def _request(self, method, path, **kwargs):
        for attempt in range(4):
            r = requests.request(method, API + path, headers=self.headers(), **kwargs)
            if r.status_code != 429 or attempt == 3:
                return r
            time.sleep(int(r.headers.get("Retry-After", "2")))
        return r

    def get(self, path, **params):
        r = self._request("GET", path, params=params)
        if r.status_code >= 400:
            print("  ! GET", path, r.status_code, r.text[:500])
            r.raise_for_status()
        return r.json()

    def write(self, method, path, body):
        if any(blocked in path for blocked in _NEVER_SUBMIT):
            sys.exit(f"Refusing {method} {path}: this pipeline never submits for review.")
        if self.dry_run:
            data = body["data"]
            print("  [dry-run]", method, path, list(data.get("attributes", {}).keys()) if isinstance(data, dict) else data)
            return {"data": {"id": "dry-run", "attributes": {}}}
        r = self._request(method, path, json=body)
        if r.status_code >= 400:
            print("  !", method, path, r.status_code, r.text[:500])
            r.raise_for_status()
        return r.json() if r.text else {}

    def remove(self, path):
        if any(blocked in path for blocked in _NEVER_SUBMIT):
            sys.exit(f"Refusing DELETE {path}: this pipeline never submits for review.")
        if self.dry_run:
            print("  [dry-run] DELETE", path)
            return
        r = self._request("DELETE", path)
        if r.status_code >= 400:
            print("  ! DELETE", path, r.status_code, r.text[:500])
            r.raise_for_status()

    def send_operations(self, operations, data):
        """PUT asset bytes to the upload URLs Apple returned. The API token is not sent."""
        if self.dry_run:
            return
        for op in operations:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
            requests.request(op["method"], op["url"], data=chunk, headers=headers).raise_for_status()


def text(locale, field):
    p = os.path.join(HERE, "metadata", locale, field + ".txt")
    return open(p).read().strip() if os.path.exists(p) else None


def upsert_localization(asc, kind, parent_rel, parent_id, existing, locale, attrs):
    attrs = {k: v for k, v in attrs.items() if v}
    if locale in existing:
        asc.write("PATCH", f"/{kind}/{existing[locale]}",
                  {"data": {"type": kind, "id": existing[locale], "attributes": attrs}})
        print(f"  updated {kind} {locale}")
        return existing[locale]
    try:
        res = asc.write("POST", f"/{kind}", {"data": {"type": kind, "attributes": {"locale": locale, **attrs},
                                                      "relationships": {parent_rel: {"data": {"type": parent_rel + "s", "id": parent_id}}}}})
    except requests.HTTPError:
        print(f"  skipped {kind} {locale} (not accepted by App Store Connect)")
        return None
    print(f"  created {kind} {locale}")
    return res["data"]["id"]


def upload_screenshot(asc, set_id, path):
    data = open(path, "rb").read()
    res = asc.write("POST", "/appScreenshots", {"data": {"type": "appScreenshots",
                    "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
                    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    if asc.dry_run:
        return
    shot = res["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        requests.request(op["method"], op["url"], data=chunk,
                         headers={h["name"]: h["value"] for h in op["requestHeaders"]}).raise_for_status()
    asc.write("PATCH", f"/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
              "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


def replace_screenshots(asc, loc_id, device, files):
    sets = asc.get(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"] if loc_id != "dry-run" else []
    wanted = DISPLAY_TYPE[device]
    set_id = next((s["id"] for s in sets if s["attributes"]["screenshotDisplayType"] == wanted), None)
    if set_id:
        for old in asc.get(f"/appScreenshotSets/{set_id}/appScreenshots")["data"]:
            if not asc.dry_run:
                requests.delete(f"{API}/appScreenshots/{old['id']}", headers=asc.headers()).raise_for_status()
    else:
        set_id = asc.write("POST", "/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                           "attributes": {"screenshotDisplayType": wanted},
                           "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]["id"]
    for f in files:
        upload_screenshot(asc, set_id, f)
    print(f"    {device}: {len(files)} screenshots")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", help="only touch screenshots for this device (e.g. appletv); text is re-sent unchanged")
    ap.add_argument("--screenshots", default=os.path.expanduser("~/Desktop/NordicCrypto-AppStore/screenshots"))
    ap.add_argument("--media-only", action="store_true",
                    help="upload screenshots and creative assets only; do not change listing text and do not submit for review")
    ap.add_argument("--headers", help="directory with the product-page header PNGs")
    ap.add_argument("--version", help="App Store version to update (default: MARKETING_VERSION in project.yml)")
    args = ap.parse_args()
    issuer, key_id = os.environ.get("ASC_ISSUER_ID"), os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        sys.exit("Set ASC_ISSUER_ID and ASC_KEY_ID.")
    asc = ASC(issuer, key_id, args.dry_run)

    if args.media_only:
        from library import upload_media
        version = args.version or marketing_version()
        headers = args.headers or os.path.join(HERE, "..", "..", "build", "appstore", "headers")
        app = asc.get("/apps", **{"filter[bundleId]": BUNDLE_ID})["data"][0]
        print("app", app["id"], app["attributes"]["name"], "version", version)
        print("Uploading media only. This does not submit the version or the assets for review.")
        upload_media(asc, app["id"], version, args.screenshots, headers)
        print("done")
        return

    app = asc.get("/apps", **{"filter[bundleId]": BUNDLE_ID})["data"][0]
    print("app", app["id"], app["attributes"]["name"])

    # App-level text: name, subtitle, privacy policy, per locale.
    info = asc.get(f"/apps/{app['id']}/appInfos")["data"]
    info_id = next((i["id"] for i in info if i["attributes"].get("appStoreState") not in ("READY_FOR_SALE",)), info[0]["id"])
    existing = {l["attributes"]["locale"]: l["id"] for l in asc.get(f"/appInfos/{info_id}/appInfoLocalizations")["data"]}
    for locale in LOCALES:
        upsert_localization(asc, "appInfoLocalizations", "appInfo", info_id, existing, locale, {
            "name": text(locale, "name"), "subtitle": text(locale, "subtitle"),
            "privacyPolicyUrl": text(locale, "privacy_url")})

    # One App Store version per platform, each with its text and screenshots.
    versions = asc.get(f"/apps/{app['id']}/appStoreVersions", **{"limit": 50})["data"]
    for platform, devices in PLATFORMS.items():
        if args.only and args.only not in devices:
            continue
        editable = [v for v in versions if v["attributes"]["platform"] == platform
                    and v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
        if editable:
            version = editable[0]
            if version["attributes"]["versionString"] != VERSION:
                asc.write("PATCH", f"/appStoreVersions/{version['id']}", {"data": {"type": "appStoreVersions",
                          "id": version["id"], "attributes": {"versionString": VERSION}}})
        else:
            try:
                version = asc.write("POST", "/appStoreVersions", {"data": {"type": "appStoreVersions",
                                    "attributes": {"platform": platform, "versionString": VERSION},
                                    "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})["data"]
            except requests.HTTPError:
                print(f"{platform}: no version (is the platform added to the app in App Store Connect?)")
                continue
        print(platform, "version", version["id"])
        vloc = {} if version["id"] == "dry-run" else {
            l["attributes"]["locale"]: l["id"] for l in asc.get(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]}
        for locale in LOCALES:
            loc_id = upsert_localization(asc, "appStoreVersionLocalizations", "appStoreVersion", version["id"], vloc, locale, {
                "description": text(locale, "description"), "keywords": text(locale, "keywords"),
                "promotionalText": text(locale, "promotional_text"), "supportUrl": text(locale, "support_url"),
                "marketingUrl": text(locale, "marketing_url")})
            # Each locale gets screenshots in its own language; English is the fallback.
            if loc_id is None:
                continue
            lang = "en" if locale.startswith("en") else locale
            for device in devices:
                if args.only and device != args.only:
                    continue
                files = sorted(glob.glob(os.path.join(args.screenshots, device, lang, "*.png"))) or \
                    sorted(glob.glob(os.path.join(args.screenshots, device, "en", "*.png")))
                if files:
                    replace_screenshots(asc, loc_id, device, files[:10])
    print("done")


if __name__ == "__main__":
    main()
