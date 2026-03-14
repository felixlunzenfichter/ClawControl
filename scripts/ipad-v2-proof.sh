#!/usr/bin/env bash
set -euo pipefail

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$REPO_ROOT/ClawControl"
PROJECT_PATH="$PROJECT_ROOT/ClawControl.xcodeproj"
SCHEME="ClawControl"
BUNDLE_ID="findMyFelix.ch.ClawControl"
EVIDENCE_DIR="$REPO_ROOT/private/device-evidence"
mkdir -p "$EVIDENCE_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
DEPLOY_LOG="$EVIDENCE_DIR/ipad-deploy-$TS.log"
DEVICE_LOG="$EVIDENCE_DIR/ipad-device-log-$TS.log"
CHAIN_LOG="$EVIDENCE_DIR/ipad-chain-$TS.log"
SERVER_LOG="$EVIDENCE_DIR/mac-server-$TS.log"

exec > >(tee -a "$DEPLOY_LOG") 2>&1

echo "=== iPad V2 proof run: $(date '+%Y-%m-%d %H:%M:%S') ==="

iPAD_LINE=$(xcrun devicectl list devices | grep "iPad" | grep -v "Simulator" | head -1 || true)
if [[ -z "$iPAD_LINE" ]]; then
  echo "❌ No physical iPad found"
  exit 1
fi
DEVICE_ID=$(echo "$iPAD_LINE" | awk '{print $4}')
if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "❌ Could not parse iPad identifier from: $iPAD_LINE"
  exit 1
fi

echo "📱 Device: $iPAD_LINE"

cd "$REPO_ROOT"

echo "🖥️ Starting mac TCP handshake server"
node src/index.js > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT
sleep 1
if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
  echo "❌ Mac server process exited"
  cat "$SERVER_LOG"
  exit 1
fi

echo "🏗️ Building app"
cd "$PROJECT_ROOT"
xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  TARGETED_DEVICE_FAMILY=2 \
  >/tmp/clawcontrol-ipad-build-$TS.log 2>&1

echo "🔎 Locating app bundle"
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -type f -path "*/Build/Products/Debug-iphoneos/${SCHEME}.app/Info.plist" 2>/dev/null | head -1 | sed 's#/Info.plist$##')
if [[ -z "${APP_PATH:-}" || ! -f "$APP_PATH/Info.plist" ]]; then
  echo "❌ Built app bundle not found"
  exit 1
fi

echo "📦 Installing app"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

validate_chain() {
  python3 - "$1" "$2" <<'PY'
import re, sys
from pathlib import Path
raw_log = Path(sys.argv[1]); chain_log = Path(sys.argv[2])
patterns = [
    re.compile(r"ipad_started"),
    re.compile(r"handshake_confirmed session=([A-Za-z0-9\-]+)"),
    re.compile(r"ping hello"),
    re.compile(r"pong_received_same_session"),
]
idx = 0; session = None; matches = []
for line in raw_log.read_text(encoding="utf-8", errors="replace").splitlines():
    m = patterns[idx].search(line)
    if not m: continue
    if idx == 1: session = m.group(1)
    matches.append(line); idx += 1
    if idx == len(patterns): break
if idx != len(patterns):
    sys.exit(1)
chain_log.write_text("\n".join(matches)+"\n", encoding="utf-8")
print(f"session={session}")
PY
}

HOST_CANDIDATES=$(node -e 'const os=require("os");const out=[];for (const [name,arr] of Object.entries(os.networkInterfaces())) {for (const x of arr||[]) {if (x.family==="IPv4" && !x.internal) out.push({name,ip:x.address});}} out.sort((a,b)=>{const s=v=>v.startsWith("100.")?0:v.startsWith("10.")?1:v.startsWith("192.168.")?2:v.startsWith("169.254.")?3:4; return s(a.ip)-s(b.ip);}); console.log(out.map(x=>`${x.name}:${x.ip}`).join("\n"));')

SUCCESS_HOST=""
for entry in $HOST_CANDIDATES; do
  iface=${entry%%:*}
  host=${entry##*:}
  ENV_JSON=$(printf '{"CLAW_MAC_HOST":"%s","CLAW_MAC_PORT":"7878"}' "$host")

  echo "🚀 Launching app (host=$host via $iface)"
  xcrun devicectl device process launch --terminate-existing --device "$DEVICE_ID" --environment-variables "$ENV_JSON" "$BUNDLE_ID"

  echo "⏳ Waiting 10s for handshake flow"
  sleep 10

  TMP_LOG="$EVIDENCE_DIR/ipad-device-log-$TS-$iface.log"
  echo "📥 Copying on-device evidence log ($TMP_LOG)"
  xcrun devicectl device copy from \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "Documents/v2-handshake-evidence.log" \
    --destination "$TMP_LOG"

  if validate_chain "$TMP_LOG" "$CHAIN_LOG" >/tmp/chain-check-$TS.txt 2>&1; then
    cp "$TMP_LOG" "$DEVICE_LOG"
    SUCCESS_HOST="$host"
    echo "✅ Ordered chain found using host=$host"
    cat /tmp/chain-check-$TS.txt
    break
  fi

  echo "⚠️ Chain not complete for host=$host"
  tail -n 5 "$TMP_LOG" || true
done

if [[ -z "$SUCCESS_HOST" ]]; then
  echo "❌ Missing ordered handshake chain on all candidate hosts"
  echo "Candidates tried:"
  echo "$HOST_CANDIDATES"
  exit 1
fi

echo "✅ Evidence ready"
echo "deploy_log=$DEPLOY_LOG"
echo "server_log=$SERVER_LOG"
echo "device_log=$DEVICE_LOG"
echo "chain_log=$CHAIN_LOG"
echo "host_used=$SUCCESS_HOST"
