#!/usr/bin/env python3
"""Google Play release helper for Alluwal Education Hub.

Authenticates as the play-publisher service account directly from
~/.play-publisher/key.json, so it never disturbs the machine's active gcloud
account. No secrets live in this file.

    play.py state                          what each track is serving
    play.py release <aab> <build> <name> [notes.json] [fraction]
                                  upload the bundle and roll it to production

Two traps this script exists to avoid:
  * the tracks PUT can 503 transiently. The edit is committed ONLY if the
    track update came back with releases; re-applying the track in a fresh
    edit works, because uploaded bundles persist across edits.
  * `changesNotSentForReview` is rejected for this app - never send it.
"""
import json
import os
import sys

import google.auth.transport.requests
from google.oauth2 import service_account

PACKAGE = "org.alluvaleducationhub.academy"
KEY_PATH = os.path.expanduser("~/.play-publisher/key.json")
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"


def session():
    creds = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=[SCOPE])
    return google.auth.transport.requests.AuthorizedSession(creds)


def call(sess, method, url, expect=(200,), **kw):
    resp = sess.request(method, url, timeout=600, **kw)
    if resp.status_code not in expect:
        raise SystemExit(f"{method} {url} -> {resp.status_code}\n{resp.text}")
    return resp.json() if resp.text else {}


def new_edit(sess):
    return call(sess, "POST", f"{API}/edits")["id"]


def state():
    sess = session()
    edit = new_edit(sess)
    tracks = call(sess, "GET", f"{API}/edits/{edit}/tracks")
    for track in tracks.get("tracks", []):
        print(f"== {track['track']} ==")
        for rel in track.get("releases", []):
            print(f"   {rel.get('name','?'):>10}  {rel.get('status'):<12} "
                  f"builds={rel.get('versionCodes')} "
                  f"fraction={rel.get('userFraction', 1.0)}")
    bundles = call(sess, "GET", f"{API}/edits/{edit}/bundles")
    codes = [b["versionCode"] for b in bundles.get("bundles", [])]
    print(f"== uploaded bundles == {sorted(codes)[-8:]}")
    sess.delete(f"{API}/edits/{edit}", timeout=60)


PLAY_LOCALES = {"en-US": "en-US", "fr-FR": "fr-FR"}


def release(aab_path, build, version_name, notes_path=None,
            track="production", fraction=None):
    if notes_path:
        with open(notes_path) as fh:
            too_long = {k: len(v) for k, v in json.load(fh).items() if len(v) > 500}
        if too_long:
            raise SystemExit(f"Play release notes are capped at 500 characters: {too_long}")
    sess = session()
    edit = new_edit(sess)
    print(f"edit {edit}: uploading {os.path.basename(aab_path)}")
    with open(aab_path, "rb") as fh:
        up = call(sess, "POST", f"{UPLOAD}/edits/{edit}/bundles?uploadType=media",
                  data=fh,
                  headers={"Content-Type": "application/octet-stream"})
    code = up["versionCode"]
    print(f"uploaded version code {code} (sha1 {up.get('sha1')})")
    if str(code) != str(build):
        raise SystemExit(f"uploaded code {code} is not the expected build {build}")

    rel = {"name": version_name, "versionCodes": [str(code)], "status": "completed"}
    if notes_path:
        with open(notes_path) as fh:
            notes = json.load(fh)
        default = notes.get("en-US") or next(iter(notes.values()))
        rel["releaseNotes"] = [
            {"language": lang, "text": notes.get(key, default)}
            for key, lang in PLAY_LOCALES.items()
        ]
    if fraction:
        rel["status"] = "inProgress"
        rel["userFraction"] = float(fraction)
    body = {"track": track, "releases": [rel]}
    result = call(sess, "PUT", f"{API}/edits/{edit}/tracks/{track}",
                  data=json.dumps(body),
                  headers={"Content-Type": "application/json"})
    if not result.get("releases"):
        raise SystemExit(
            "track update returned no releases - NOT committing. Re-run; the "
            "uploaded bundle persists, so a fresh edit can re-apply the track.")
    print(f"track {track} -> {result['releases']}")
    # zsh trap: a bare $EDIT:commit is read as a modifier. Not an issue here.
    call(sess, "POST", f"{API}/edits/{edit}:commit")
    print(f"committed: {version_name} (build {code}) to {track}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "state"
    if cmd == "state":
        state()
    elif cmd == "release":
        release(sys.argv[2], sys.argv[3], sys.argv[4],
                notes_path=sys.argv[5] if len(sys.argv) > 5 else None,
                fraction=sys.argv[6] if len(sys.argv) > 6 else None)
    else:
        raise SystemExit(__doc__)
