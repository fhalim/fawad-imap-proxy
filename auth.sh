#!/usr/bin/env bash
set -euo pipefail

# First-run script: patches config, starts proxy, triggers device flow auth.
# Re-run this if your OAuth2 tokens expire (after 90+ days without use).

CONTAINER_NAME="fawad-imap-proxy"
VOLUME_NAME="fawad-imap-proxy-tokens"
IMAGE_NAME="fawad-imap-proxy:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in values."
  exit 1
fi
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"

: "${EMAIL:?Set EMAIL in .env}"
: "${CLIENT_ID:?Set CLIENT_ID in .env}"

# ── Patch emailproxy.config ──────────────────────────────────────────────────
sed -i \
  -e "s/YOUREMAIL@outlook\.com/${EMAIL}/g" \
  -e "s/CLIENT_ID_PLACEHOLDER/${CLIENT_ID}/g" \
  "${SCRIPT_DIR}/emailproxy.config"

echo "Config patched: ${EMAIL} / client ${CLIENT_ID}"

# ── Build image ───────────────────────────────────────────────────────────────
echo "Building image..."
docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# ── Stop and remove any existing container ────────────────────────────────────
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# ── Create token volume and start proxy ──────────────────────────────────────
docker volume create "${VOLUME_NAME}" > /dev/null
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p 127.0.0.1:1143:1143 \
  -p 127.0.0.1:8080:8080 \
  -v "${SCRIPT_DIR}/emailproxy.config:/config/emailproxy.config:rw" \
  -v "${VOLUME_NAME}:/config/tokens" \
  "${IMAGE_NAME}"

echo "Waiting for proxy to bind port 1143..."
for i in $(seq 1 15); do
  if nc -z 127.0.0.1 1143 2>/dev/null; then
    echo "Port 1143 ready."
    break
  fi
  sleep 1
done

# ── Trigger device flow by sending an IMAP LOGIN ─────────────────────────────
# The proxy only initiates OAuth2 when it sees a LOGIN command.
echo ""
echo "Triggering device flow auth..."
printf "A1 LOGIN %s dummypassword\r\nA2 LOGOUT\r\n" "${EMAIL}" \
  | nc -q 5 127.0.0.1 1143 2>/dev/null || true

# ── Show device flow instructions from logs ───────────────────────────────────
echo ""
echo "=== Watching proxy logs for device flow URL (Ctrl+C to stop) ==="
echo "Look for: 'Please visit' or 'microsoft.com/devicelogin' with a user code."
echo "Go to that URL on any device and sign in with your Outlook account."
echo ""
docker logs -f "${CONTAINER_NAME}"
