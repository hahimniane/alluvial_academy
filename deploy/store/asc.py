#!/usr/bin/env python3
"""App Store Connect release helper for Alluwal Education Hub.

No secrets live here. The signing key stays at
~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8; the key id and issuer id
are identifiers, not credentials.

    asc.py state                          what the store thinks right now
    asc.py notes <version> <notes.json>   set "What's New" per locale
    asc.py submit <build> <version>       attach a build to a version and submit

`submit` handles the case this app is usually in: a previous submission is
still WAITING_FOR_REVIEW. It withdraws that one, retitles the version, attaches
the new build and resubmits, which is what Apple wants instead of a second
open submission.
"""
import json
import os
import sys
import time

import jwt
import requests

KEY_ID = "C7U4GRWF3Q"
ISSUER_ID = "4ac4bd75-377b-4ec0-b769-a9ce5b64b216"
APP_ID = "6754095805"
BUNDLE_ID = "com.example.alluwalacademyadmin"
KEY_PATH = os.path.expanduser(
    f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
API = "https://api.appstoreconnect.apple.com/v1"


def token():
    with open(KEY_PATH) as fh:
        private_key = fh.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def call(method, path, **kw):
    url = path if path.startswith("http") else f"{API}{path}"
    headers = {"Authorization": f"Bearer {token()}",
               "Content-Type": "application/json"}
    resp = requests.request(method, url, headers=headers, timeout=60, **kw)
    if resp.status_code >= 400:
        raise SystemExit(f"{method} {url} -> {resp.status_code}\n{resp.text}")
    return resp.json() if resp.text else {}


def builds(limit=8):
    return call("GET", f"/builds?filter[app]={APP_ID}&limit={limit}"
                       "&sort=-version&include=preReleaseVersion")["data"]


def versions(limit=8):
    return call("GET", f"/apps/{APP_ID}/appStoreVersions?limit={limit}")["data"]


def state():
    print("== builds ==")
    for b in builds():
        a = b["attributes"]
        print(f"  build {a['version']:>4}  {a['processingState']:<12} "
              f"expired={a['expired']}  uploaded={a['uploadedDate']}  id={b['id']}")
    print("== versions ==")
    for v in versions():
        a = v["attributes"]
        print(f"  {a['versionString']:>8}  {a['appStoreState']:<28} "
              f"release={a['releaseType']}  id={v['id']}")


def localizations(version_id):
    return call("GET", f"/appStoreVersions/{version_id}"
                       "/appStoreVersionLocalizations")["data"]


def set_notes(version_id, notes):
    """notes: {"en-US": "...", "fr-FR": "..."} - locales absent from the app
    fall back to the "en-US" text, because a locale left blank blocks review."""
    default = notes.get("en-US") or next(iter(notes.values()))
    for loc in localizations(version_id):
        locale = loc["attributes"]["locale"]
        text = notes.get(locale, default)
        call("PATCH", f"/appStoreVersionLocalizations/{loc['id']}",
             data=json.dumps({"data": {
                 "type": "appStoreVersionLocalizations",
                 "id": loc["id"],
                 "attributes": {"whatsNew": text}}}))
        print(f"  what's new set for {locale}")


def find_build(number):
    for b in builds(limit=20):
        if b["attributes"]["version"] == str(number):
            return b
    raise SystemExit(f"build {number} not found in App Store Connect")


EDITABLE = {
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
    "METADATA_REJECTED", "INVALID_BINARY",
}
WITHDRAWABLE = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE"}


def notes_cmd(version_string, notes_path):
    with open(notes_path) as fh:
        notes = json.load(fh)
    for v in versions():
        if v["attributes"]["versionString"] == version_string:
            set_notes(v["id"], notes)
            return
    raise SystemExit(f"version {version_string} not found")


def submit(build_number, version_string, notes_path=None):
    build = find_build(build_number)
    if build["attributes"]["processingState"] != "VALID":
        raise SystemExit(
            f"build {build_number} is {build['attributes']['processingState']}; "
            "wait for Apple to finish processing")

    target = None
    for v in versions():
        st = v["attributes"]["appStoreState"]
        if st in WITHDRAWABLE:
            print(f"withdrawing {v['attributes']['versionString']} ({st})")
            subs = call("GET", f"/appStoreVersions/{v['id']}"
                               "/appStoreVersionSubmission")
            sub_id = (subs.get("data") or {}).get("id")
            if sub_id:
                call("DELETE", f"/appStoreVersionSubmissions/{sub_id}")
                time.sleep(3)
            target = v
            break
        if st in EDITABLE:
            target = v
            break

    if target is None:
        print(f"creating version {version_string}")
        target = call("POST", "/appStoreVersions", data=json.dumps({"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": version_string},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }}))["data"]
    elif target["attributes"]["versionString"] != version_string:
        print(f"retitling {target['attributes']['versionString']} "
              f"-> {version_string}")
        call("PATCH", f"/appStoreVersions/{target['id']}", data=json.dumps({
            "data": {"type": "appStoreVersions", "id": target["id"],
                     "attributes": {"versionString": version_string}}}))

    if notes_path:
        with open(notes_path) as fh:
            set_notes(target["id"], json.load(fh))

    print(f"attaching build {build_number}")
    call("PATCH", f"/appStoreVersions/{target['id']}/relationships/build",
         data=json.dumps({"data": {"type": "builds", "id": build["id"]}}))

    print("submitting for review")
    submit_for_review(target["id"])
    print(f"submitted {version_string} (build {build_number})")


def submit_for_review(version_id):
    """Apple retired appStoreVersionSubmissions/CREATE. The current flow is a
    reviewSubmission holding one reviewSubmissionItem per version, flipped to
    submitted with a PATCH."""
    open_states = {"READY_FOR_REVIEW", "UNRESOLVED_ISSUES"}
    existing = call("GET", f"/apps/{APP_ID}/reviewSubmissions"
                           "?filter[platform]=IOS&limit=20").get("data", [])
    submission = next(
        (r for r in existing
         if r["attributes"]["state"] in open_states), None)

    if submission is None:
        submission = call("POST", "/reviewSubmissions", data=json.dumps({
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": APP_ID}}},
            }}))["data"]
        print(f"  opened review submission {submission['id']}")
    else:
        print(f"  reusing review submission {submission['id']} "
              f"({submission['attributes']['state']})")

    items = call("GET", f"/reviewSubmissions/{submission['id']}"
                        "/items").get("data", [])
    already = any(
        (i.get("relationships", {}).get("appStoreVersion", {}).get("data")
         or {}).get("id") == version_id
        for i in items)
    if already:
        print("  version already on the submission")
    else:
        call("POST", "/reviewSubmissionItems", data=json.dumps({"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {
                    "type": "reviewSubmissions", "id": submission["id"]}},
                "appStoreVersion": {"data": {
                    "type": "appStoreVersions", "id": version_id}},
            }}}))
        print("  version added to the submission")

    call("PATCH", f"/reviewSubmissions/{submission['id']}",
         data=json.dumps({"data": {
             "type": "reviewSubmissions",
             "id": submission["id"],
             "attributes": {"submitted": True}}}))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "state"
    if cmd == "state":
        state()
    elif cmd == "notes":
        notes_cmd(sys.argv[2], sys.argv[3])
    elif cmd == "submit":
        submit(sys.argv[2], sys.argv[3],
               sys.argv[4] if len(sys.argv) > 4 else None)
    else:
        raise SystemExit(__doc__)
