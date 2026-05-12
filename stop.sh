#!/usr/bin/env bash
# Stop the proxy (tokens are preserved in the Docker volume).
docker stop fawad-imap-proxy 2>/dev/null && echo "Stopped." || echo "Container not running."
