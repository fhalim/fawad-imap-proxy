# fawad-imap-proxy

Local OAuth2 proxy for Outlook.com IMAP. Bridges mbsync (basic auth only) to Microsoft's OAuth2 protocol.

## Architecture

```
mbsync (localhost:1143, basic auth)
  ↓ emailproxy (Docker)
    ↓ outlook.office365.com:993 (OAuth2 Bearer token)
      ↓ Microsoft token endpoint
```

Tokens cached in Docker named volume. Auto-refresh on use.

## Quick Start

### 1. Configure

```bash
cd ~/projects/fawad-imap-proxy
cp .env.example .env
# Edit .env — set EMAIL to your Outlook.com address
# CLIENT_ID already set to Thunderbird's public app (no Azure setup needed)
```

### 2. Authorize (first run only)

```bash
./auth.sh
```

Output will show:
```
Triggering device flow auth...
=== Watching proxy logs for device flow URL ===
...
Please visit the following URL to authenticate account youremail@outlook.com:
https://microsoft.com/devicelogin
Enter code: ABC1234
```

**On any device with a browser:**
- Visit `https://microsoft.com/devicelogin`
- Enter the code displayed (e.g., `ABC1234`)
- Sign in with your personal Outlook.com account
- Return to terminal, Ctrl+C to exit logs

Tokens now cached. Proxy auto-refreshes them on use.

### 3. Configure mbsync

Add to `~/.mbsyncrc`:

```
IMAPAccount outlook-proxy
  Host 127.0.0.1
  Port 1143
  User youremail@outlook.com
  Pass anything
  TLSType None
  AuthMechs LOGIN

IMAPStore outlook-remote
  Account outlook-proxy

MaildirStore outlook-local
  SubFolders Verbatim
  Path ~/Mail/Outlook/
  Inbox ~/Mail/Outlook/Inbox

Channel outlook
  Far :outlook-remote:
  Near :outlook-local:
  Patterns *
  Create Both
  Expunge None
  SyncState *
```

Replace `youremail@outlook.com` and mail path as needed. See `mbsyncrc.example` for full reference.

### 4. Sync

```bash
mkdir -p ~/Mail/Outlook
mbsync -a
```

## Lifecycle

**Start (after initial auth):**
```bash
./start.sh
```

**Stop:**
```bash
./stop.sh
```

**View logs:**
```bash
docker logs -f fawad-imap-proxy
```

**Full container reset (loses tokens; re-run `./auth.sh`):**
```bash
docker rm -f fawad-imap-proxy
docker volume rm fawad-imap-proxy-tokens
```

## Azure App Registration (Optional)

Thunderbird's public client ID is included and works for personal Outlook.com accounts. If you need your own Azure app:

1. Visit https://entra.microsoft.com
2. **Identity** → **Applications** → **App registrations** → **New registration**
3. Name: `imap-oauth2-proxy` (or anything)
4. **Supported account types:** `Personal Microsoft accounts only` (critical)
5. **Redirect URI:** Platform `Mobile and desktop applications`, URI `http://localhost`
6. After registration, go to **Authentication** → **Advanced settings** → **Allow public client flows:** Yes
7. **API permissions** → **Add permission** → Search `Office 365 Exchange Online` → **Delegated permissions** → `IMAP.AccessAsUser.All`
8. Copy the **Application (client) ID**
9. Update `CLIENT_ID` in `.env` and re-run `./auth.sh`

## Troubleshooting

**"Port 1143 connection refused"**
- Container not running: `./start.sh` or `./auth.sh`
- Just started: wait 3s, ports take time to bind

**"Port 1143 IMAP LOGIN fails after device flow"**
- Device flow incomplete: check `docker logs fawad-imap-proxy` for auth errors
- Thunderbird ID blocked in your region: register own Azure app (see above)

**"mbsync: IMAP command 'LOGIN' returned an error"**
- Missing `TLSType None` in `.mbsyncrc` (port 1143 is plaintext)
- Check `docker logs fawad-imap-proxy` for proxy-side errors

**"Tokens expired / need to re-auth"**
- Personal refresh tokens last ~90 days without use
- Re-run `./auth.sh` to trigger new device flow
- Existing tokens automatically wiped; config preserved

**"Container keeps exiting"**
- `docker logs fawad-imap-proxy` for Python errors
- Usually: bad config file syntax or missing network

## Security Notes

- Port 1143 binds to `127.0.0.1` only—never expose externally
- Tokens encrypted in Docker volume (unencrypted locally = unwise)
- `emailproxy.config` contains email + client ID: add to `.gitignore`
- `.env` contains secrets: always gitignored

## Files

- `Dockerfile` — Python 3.11 + emailproxy
- `emailproxy.config` — OAuth2 + IMAP config (patched by `auth.sh`)
- `.env` — secrets (from `.env.example`)
- `auth.sh` — first-run authorization
- `start.sh` / `stop.sh` — container lifecycle
- `mbsyncrc.example` — reference mbsync config
- `docker-compose.yml` — reference (requires compose plugin; scripts use plain `docker`)

## References

- emailproxy: https://github.com/simonrob/email-oauth2-proxy
- mbsync (isync): https://github.com/gburd/isync
- Device flow: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code
