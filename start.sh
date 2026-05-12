#!/usr/bin/env bash
# Start an already-authorised proxy (tokens exist in the Docker volume).
# For first-time setup, use auth.sh instead.
docker start fawad-imap-proxy 2>/dev/null \
  && echo "Started. Logs: docker logs -f fawad-imap-proxy" \
  || echo "Container not found — run auth.sh first."
