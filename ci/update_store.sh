#!/usr/bin/env bash
# Publish an unsigned .ipa to the personal Nextcloud "store" and update the
# shared SideStore/AltStore source (apps.json) so the iPhone gets an Update
# prompt. No VPS/SSH — everything is done over Nextcloud WebDAV from CI.
#
# Reused across repos (vocabloop / monvy / pheem). Everything app-specific comes
# from env so the script itself is identical everywhere.
#
# Required env:
#   NC_USER NC_APP_PASSWORD   Nextcloud auth (repo secrets)
#   APP_SLUG                  folder + file stem, e.g. vocabloop
#   APP_NAME                  display name, e.g. VocabLoop
#   BUNDLE_ID                 e.g. tech.huylv.vocabloop
#   DEV_NAME                  developer name shown in SideStore
#   VER                       marketing version, MUST equal the ipa's CFBundleShortVersionString
#   IPA_PATH                  local path to the built .ipa
#   DESC                      version description (changelog line)
#   ICON_PATH                 optional local PNG (uploaded once as icon)
#   SHARE_TOKEN               public share token of the /Builds folder
set -euo pipefail

: "${NC_USER:?}"; : "${NC_APP_PASSWORD:?}"; : "${APP_SLUG:?}"; : "${BUNDLE_ID:?}"
: "${VER:?}"; : "${IPA_PATH:?}"; : "${SHARE_TOKEN:?}"
APP_NAME="${APP_NAME:-$APP_SLUG}"; DEV_NAME="${DEV_NAME:-huylv}"; DESC="${DESC:-CI build $VER}"
STORE_NAME="${STORE_NAME:-HuyLV Official}"   # SideStore source display name (shared across apps)

HOST="https://drive.huylv.tech"
DAV="$HOST/remote.php/dav/files/$NC_USER/Builds"           # authenticated (read/write)
PUB="$HOST/public.php/dav/files/$SHARE_TOKEN"              # public (direct download)
AUTH=(-u "$NC_USER:$NC_APP_PASSWORD")
DATE="$(date -u +%Y-%m-%d)"
SIZE="$(wc -c < "$IPA_PATH" | tr -d ' ')"

# WebDAV PUT with retry. Nextcloud can return 423 Locked (a stale transactional
# lock, common with object-storage primary) or transient 5xx; retry with backoff
# so a lock that clears within a couple of minutes doesn't fail the publish.
dav_put() {  # $1=local file  $2=remote url
  local f="$1" url="$2" i
  for i in 1 2 3 4 5 6 7 8; do
    if curl -fSS "${AUTH[@]}" -T "$f" "$url"; then return 0; fi
    echo "  PUT failed (attempt $i/8) — locked/transient? retry in 20s…" >&2
    sleep 20
  done
  echo "  PUT gave up after 8 attempts: $url" >&2
  return 1
}

echo "→ upload ipa ($SIZE bytes)"
curl -fsS "${AUTH[@]}" -X MKCOL "$DAV/$APP_SLUG" || true
curl -fsS "${AUTH[@]}" -X MKCOL "$DAV/$APP_SLUG/ios" || true
dav_put "$IPA_PATH" "$DAV/$APP_SLUG/ios/$APP_SLUG-$VER.ipa"
dav_put "$IPA_PATH" "$DAV/$APP_SLUG/ios/$APP_SLUG-latest.ipa"

# Storage retention. Separate number from the apps.json window on purpose: the
# source only ever offers 10 builds, but keeping more files around means an
# older link someone saved still resolves.
#
# Note what this does NOT do: something outside these repos already removes
# builds (four VocabLoop .ipa files vanished while their apps.json entries
# stayed, and nothing here deletes). A count cap cannot stop that; it only
# bounds growth from our side. The aliveness check further down is what keeps
# the source honest when files disappear for reasons we don't control.
KEEP_IPAS="${KEEP_IPAS:-50}"

prune_ipas() {
  local listing names total del
  listing=$(curl -fsS "${AUTH[@]}" -X PROPFIND -H 'Depth: 1' \
    --data '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>' \
    "$DAV/$APP_SLUG/ios/" 2>/dev/null) || {
      echo "  prune: không liệt kê được thư mục — bỏ qua, không xoá gì"; return 0; }

  # The digit right after the dash is the safety catch: it matches
  # <slug>-1.2.3.ipa and can never match <slug>-latest.ipa, which every install
  # link points at and which must survive regardless of age.
  names=$(printf '%s' "$listing" | grep -oE "$APP_SLUG-[0-9][0-9.]*\.ipa" | sort -uV) || true
  [ -n "$names" ] || return 0
  total=$(printf '%s\n' "$names" | wc -l | tr -d ' ')
  if [ "$total" -le "$KEEP_IPAS" ]; then
    echo "  prune: $total/$KEEP_IPAS file — chưa cần xoá"
    return 0
  fi

  # sort -V is ascending, so the head of the list is the oldest.
  del=$(printf '%s\n' "$names" | head -n "$((total - KEEP_IPAS))")
  echo "  prune: $total file > $KEEP_IPAS — xoá $((total - KEEP_IPAS)) bản cũ nhất"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if curl -fsS "${AUTH[@]}" -X DELETE "$DAV/$APP_SLUG/ios/$f" >/dev/null 2>&1; then
      echo "    xoá $f"
    else
      echo "    xoá hụt $f — bỏ qua" >&2
    fi
  done <<< "$del"
}

echo "→ prune ipa cũ (giữ $KEEP_IPAS)"
prune_ipas || true

ICON_URL=""
if [ -n "${ICON_PATH:-}" ] && [ -f "${ICON_PATH:-}" ]; then
  dav_put "$ICON_PATH" "$DAV/$APP_SLUG/icon.png"
  ICON_URL="$PUB/$APP_SLUG/icon.png"
fi
DL_URL="$PUB/$APP_SLUG/ios/$APP_SLUG-$VER.ipa"

echo "→ fetch current apps.json (init if missing)"
if ! curl -fsS "${AUTH[@]}" "$DAV/apps.json" -o cur.json 2>/dev/null; then
  echo '{"name":"huylv apps","identifier":"tech.huylv.store","apps":[]}' > cur.json
fi

# --- changelog -----------------------------------------------------------------
# Every version used to be described as "CI build 1.0.NN", which tells a reader
# nothing they can't see from the version number. Build the real list instead:
# the commit subjects since the previously published build.
#
# Which commit that was is recorded in apps.json itself (`commit` on each
# version entry) — a field AltStore/SideStore ignore and we can therefore use.
# Needs a full clone; the workflow sets fetch-depth: 0 for exactly this.
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo '')}"
PREV_SHA="$(python3 - "$BUNDLE_ID" <<'PY'
import json, sys
try:
    d = json.load(open('cur.json'))
    app = next(a for a in d.get('apps', []) if a.get('bundleIdentifier') == sys.argv[1])
    print((app.get('versions') or [{}])[0].get('commit', ''))
except Exception:
    print('')
PY
)"

DESC=""
if [ -n "$PREV_SHA" ] && git cat-file -e "$PREV_SHA^{commit}" 2>/dev/null; then
  # `|| true` matters under `set -e`: a failing command substitution in an
  # assignment aborts the whole publish, and a changelog is not worth losing a
  # build over.
  DESC="$(git log --no-merges --pretty=format:'• %s' "$PREV_SHA..HEAD" 2>/dev/null | head -20 || true)"
  echo "  changelog: $(printf '%s' "$DESC" | grep -c '^•' || true) commit kể từ ${PREV_SHA:0:7}"
fi
if [ -z "$DESC" ]; then
  # First publish, or the previous commit is gone (force-push, rewritten
  # history). Say what happened rather than inventing a list.
  DESC="$(git log --no-merges --pretty=format:'• %s' -3 2>/dev/null || true)"
  echo "  changelog: không lần ngược được bản trước — lấy 3 commit gần nhất"
fi
[ -n "$DESC" ] || DESC="CI build $VER"
python3 - "$BUNDLE_ID" "$APP_NAME" "$DEV_NAME" "$ICON_URL" "$VER" "$DATE" "$SIZE" "$DL_URL" "$DESC" "$STORE_NAME" "$COMMIT_SHA" <<'PY'
import json, sys, urllib.request, urllib.error
bundle, name, dev, icon, ver, date, size, dl, desc, store_name = sys.argv[1:11]
commit_sha = sys.argv[11] if len(sys.argv) > 11 else ''

def alive(url):
    """Does this version's .ipa still exist?

    Retention used to be a plain [:10] on the list, which quietly assumed the
    files outlive their entries. They don't: the store was listing four builds
    whose .ipa was already gone, so picking one in SideStore returned a 404.
    Nothing in this script deletes them, so whatever does is outside our reach —
    which is exactly why the list has to be checked rather than trusted.

    Fails OPEN. A timeout or a transport error keeps the entry: dropping a
    working version because the network hiccuped is worse than one stale link.
    Only a definitive 404 removes it.
    """
    if not url:
        return False
    try:
        # The User-Agent is not decoration. Nextcloud's public share endpoint
        # answers 403 to urllib's default agent — for files that exist AND for
        # files that don't. With that 403 the check below fails open on every
        # single version and the prune silently does nothing, which is how this
        # would have looked correct forever while achieving zero.
        req = urllib.request.Request(
            url, method='HEAD', headers={'User-Agent': 'huylv-store-ci/1'})
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status < 400
    except urllib.error.HTTPError as e:
        return e.code != 404
    except Exception:
        return True
d = json.load(open('cur.json'))
d['name'] = store_name                 # keep the source display name in sync
d.setdefault('identifier', 'tech.huylv.store')
d.setdefault('apps', [])
app = next((a for a in d['apps'] if a.get('bundleIdentifier') == bundle), None)
if app is None:
    app = {'name': name, 'bundleIdentifier': bundle, 'developerName': dev,
           'localizedDescription': name, 'versions': []}
    if icon: app['iconURL'] = icon
    d['apps'].append(app)
if icon: app['iconURL'] = icon
entry = {'version': ver, 'date': date, 'size': int(size),
         'downloadURL': dl, 'localizedDescription': desc}
# Not part of the AltStore schema — readers ignore unknown keys. It is how the
# NEXT build knows where to start the changelog from.
if commit_sha:
    entry['commit'] = commit_sha
vers = [v for v in app.get('versions', []) if v.get('version') != ver]  # idempotent
kept = [v for v in vers if alive(v.get('downloadURL', ''))]
dropped = [v['version'] for v in vers if v not in kept]
if dropped:
    print('  dropped (ipa gone):', ', '.join(dropped))
# The version just uploaded goes in unchecked — HEAD-ing it moments after the
# PUT can race object storage, and we know it landed because dav_put succeeded.
kept.insert(0, entry)
app['versions'] = kept[:10]                                             # retention
# legacy top-level mirror (older AltStore readers)
app['version'] = ver; app['versionDate'] = date; app['versionDescription'] = desc
app['downloadURL'] = dl; app['size'] = int(size)
json.dump(d, open('out.json', 'w'), ensure_ascii=False, indent=2)
PY
python3 -c "import json; json.load(open('out.json'))"   # validate before upload
# apps.json is a text file; if it's ever opened in the Nextcloud web "Text"
# editor it can be left with a permanent (ttl=0) Files-Lock that returns 423 on
# every future CI write (SideStore source then freezes at the old version).
# Force-release any lock on THIS file only before writing — collaboration /
# Files-Lock on every OTHER file is left untouched (files_lock stays enabled).
unlock_apps_json() {
  local fid
  fid=$(curl -fsS "${AUTH[@]}" -X PROPFIND -H 'Depth: 0' \
        --data '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns"><d:prop><oc:fileid/></d:prop></d:propfind>' \
        "$DAV/apps.json" 2>/dev/null | grep -oE 'fileid>[0-9]+' | grep -oE '[0-9]+' | head -1 || true)
  [ -n "${fid:-}" ] || return 0
  curl -fsS "${AUTH[@]}" -H 'OCS-APIRequest: true' -X DELETE \
    "$HOST/ocs/v2.php/apps/files_lock/lock/$fid" >/dev/null 2>&1 \
    && echo "  released stale Files-Lock on apps.json (fileid=$fid)" || true
}

echo "→ upload apps.json (release any stale lock first)"
put_apps_json() {
  local i
  for i in 1 2 3 4 5 6 7 8; do
    unlock_apps_json
    if curl -fSS "${AUTH[@]}" -T out.json "$DAV/apps.json"; then return 0; fi
    echo "  apps.json PUT failed (attempt $i/8) — retry in 15s…" >&2
    sleep 15
  done
  echo "  apps.json PUT gave up after 8 attempts" >&2
  return 1
}
put_apps_json

echo "→ verify public URLs"
curl -fsS -o /dev/null -w "  ipa  %{http_code} %{size_download}B\n" "$DL_URL"
curl -fsS "$PUB/apps.json" | python3 -c "import json,sys; a=[x for x in json.load(sys.stdin)['apps'] if x['bundleIdentifier']=='$BUNDLE_ID'][0]; print('  apps.json latest:', a['versions'][0]['version'])"
echo "✓ store updated: $APP_SLUG $VER"
echo "SOURCE_URL=$PUB/apps.json"
