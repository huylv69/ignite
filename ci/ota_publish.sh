#!/usr/bin/env bash
# Sign the unsigned .ipa with the ad-hoc distribution certificate and publish it
# for one-tap install (itms-services) from the personal Nextcloud store.
#
# The profile lists exactly one device, so the signed build installs on that
# iPhone only; any other device gets "Unable to install". The certificate never
# leaves the runner: only the signed .ipa and its manifest are uploaded.
#
# Reused across repos. Everything app-specific comes from env.
#
# Required env:
#   NC_USER NC_APP_PASSWORD   Nextcloud auth (repo secrets)
#   IOS_P12_B64 IOS_P12_PASSWORD IOS_PROVISION_B64   signing (repo secrets)
#   APP_SLUG APP_NAME BUNDLE_ID VER IPA_PATH SHARE_TOKEN
# Optional:
#   TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID   told when the certificate is revoked
#
# Install link, stable across versions:
#   itms-services://?action=download-manifest&url=<PUB>/<slug>/ota/manifest.plist
set -euo pipefail

: "${NC_USER:?}"; : "${NC_APP_PASSWORD:?}"; : "${APP_SLUG:?}"; : "${BUNDLE_ID:?}"
: "${VER:?}"; : "${IPA_PATH:?}"; : "${SHARE_TOKEN:?}"
: "${IOS_P12_B64:?}"; : "${IOS_P12_PASSWORD:?}"; : "${IOS_PROVISION_B64:?}"
APP_NAME="${APP_NAME:-$APP_SLUG}"

HOST="https://drive.huylv.tech"
DAV="$HOST/remote.php/dav/files/$NC_USER/Builds"
PUB="$HOST/public.php/dav/files/$SHARE_TOKEN"
AUTH=(-u "$NC_USER:$NC_APP_PASSWORD")
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# zsign, pinned by checksum. The release ships one binary per platform.
ZV=v1.1.2
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  ZA=zsign-macos-arm64;   ZS=3f84a08150c2c41ccf80bfeca9ee6bc86ae1ff771323cd9931c4d8cd438ade0d ;;
  Linux-x86_64)  ZA=zsign-linux-x86_64;  ZS=d55e6a8650949a260892a9687ac1dfe4a9c79c2e3ecfe00a0eeb09b7b694282e ;;
  *) echo "no zsign build for $(uname -sm)" >&2; exit 1 ;;
esac
curl -fsSL -o "$WORK/z.tgz" "https://github.com/zhlynn/zsign/releases/download/$ZV/$ZA.tar.gz"
echo "$ZS  $WORK/z.tgz" | shasum -a 256 -c - >/dev/null
tar xzf "$WORK/z.tgz" -C "$WORK"
ZSIGN="$WORK/zsign"; chmod +x "$ZSIGN"

printf '%s' "$IOS_P12_B64" | base64 --decode > "$WORK/cert.p12"
printf '%s' "$IOS_PROVISION_B64" | base64 --decode > "$WORK/cert.mobileprovision"

echo "→ sign $IPA_PATH"
SIGNED="$WORK/$APP_SLUG-$VER.ipa"
"$ZSIGN" -C -k "$WORK/cert.p12" -p "$IOS_P12_PASSWORD" -m "$WORK/cert.mobileprovision" \
  -o "$SIGNED" "$IPA_PATH" | tee "$WORK/sign.log"
rm -f "$WORK/cert.p12"

# Revoked certificate: every app signed with it stops opening. Say so loudly
# instead of publishing a build that cannot launch.
if grep -qi 'OCSP:.*revoked' "$WORK/sign.log"; then
  echo "✗ certificate REVOKED" >&2
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -fsS "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      --data-urlencode text="⚠️ iOS signing certificate revoked — $APP_NAME $VER not published. Replace IOS_P12_B64 / IOS_PROVISION_B64." >/dev/null || true
  fi
  exit 1
fi

IPA_URL="$PUB/$APP_SLUG/ota/$APP_SLUG-latest.ipa"
cat > "$WORK/manifest.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>items</key><array><dict>
  <key>assets</key><array><dict>
    <key>kind</key><string>software-package</string>
    <key>url</key><string>$IPA_URL</string>
  </dict></array>
  <key>metadata</key><dict>
    <key>bundle-identifier</key><string>$BUNDLE_ID</string>
    <key>bundle-version</key><string>$VER</string>
    <key>kind</key><string>software</string>
    <key>title</key><string>$APP_NAME</string>
  </dict>
</dict></array></dict></plist>
EOF

dav_put() {  # $1=local file  $2=remote url
  local i
  for i in 1 2 3 4 5 6; do
    curl -fSS "${AUTH[@]}" -T "$1" "$2" && return 0
    echo "  PUT failed (attempt $i/6), retry in 20s" >&2; sleep 20
  done
  return 1
}

echo "→ upload signed ipa + manifest"
curl -fsS "${AUTH[@]}" -X MKCOL "$DAV/$APP_SLUG" >/dev/null 2>&1 || true
curl -fsS "${AUTH[@]}" -X MKCOL "$DAV/$APP_SLUG/ota" >/dev/null 2>&1 || true
# Only the latest signed build is kept: the install link always means "newest".
dav_put "$SIGNED" "$DAV/$APP_SLUG/ota/$APP_SLUG-latest.ipa"
dav_put "$WORK/manifest.plist" "$DAV/$APP_SLUG/ota/manifest.plist"

curl -fsS -A 'huylv-store-ci/1' -o /dev/null -w "  signed ipa %{http_code} %{size_download}B\n" "$IPA_URL"
echo "✓ OTA published: $APP_SLUG $VER"
echo "INSTALL=itms-services://?action=download-manifest&url=$PUB/$APP_SLUG/ota/manifest.plist"
