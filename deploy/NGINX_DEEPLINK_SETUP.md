# Starlink — Deep Link (Universal Links / App Links) Server Setup

This guide is for the **server / nginx** team. It makes the password‑reset link in
the email open the **Starlink mobile app** (on the Reset Password screen) instead of
a web browser.

- **Domain:** `starlink.ardentnetworks.com.ph`
- **Example email link:** `https://starlink.ardentnetworks.com.ph/reset-password?token=...`
- **What you do:** host **two static files** under `/.well-known/`. No backend or
  frontend code changes. This is the same setup already done for E‑Forward.

The mobile app side (entitlements, intent filters, signing) is already handled in the
app build — this document only covers the server half.

---

## 1. The two files and their exact contents

Create these two files. **Do not change the contents** — the values must match the app.

### File A — `apple-app-site-association`  (iOS)

> ⚠️ The filename has **NO extension** (not `.json`). It must be served with
> `Content-Type: application/json`.

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "K9973Z86YT.com.ardentnetworks.starlink",
        "paths": [ "/reset-password", "/reset-password/*", "/auth/reset-password", "/auth/reset-password/*" ]
      }
    ]
  }
}
```

### File B — `assetlinks.json`  (Android)

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.ardentnetworks.starlink",
      "sha256_cert_fingerprints": [
        "A4:07:EE:1A:70:37:2D:DF:EE:D3:BC:44:B0:D2:71:C9:1A:ED:B3:12:A8:F0:B7:6B:CD:70:DD:AD:68:9B:58:79",
        "2E:FF:EC:E5:B3:7C:0D:16:D9:DD:C0:31:E9:13:D3:64:18:C1:09:71:09:34:34:59:27:47:2A:2C:9B:1D:45:53"
      ]
    }
  }
]
```

> The first fingerprint is the release signing key; the second is the debug key
> (for test builds). Both are intentional — leave them as‑is.

---

## 2. Where to put the files on the server

Put both files inside a `.well-known` directory in the site's web root. Example
(adjust the path to match this domain's actual nginx `root`):

```bash
sudo mkdir -p /var/www/starlink/.well-known

# Place the files:
#   /var/www/starlink/.well-known/apple-app-site-association     (no extension)
#   /var/www/starlink/.well-known/assetlinks.json
```

They must end up publicly reachable at these **exact** URLs:

| Platform | URL |
|----------|-----|
| iOS      | `https://starlink.ardentnetworks.com.ph/.well-known/apple-app-site-association` |
| Android  | `https://starlink.ardentnetworks.com.ph/.well-known/assetlinks.json` |

---

## 3. nginx configuration

In the `server { ... }` block for `starlink.ardentnetworks.com.ph` (the **HTTPS /
port 443** block), add:

```nginx
# --- Deep-link association files (Universal Links / App Links) ---
location = /.well-known/apple-app-site-association {
    alias /var/www/starlink/.well-known/apple-app-site-association;
    default_type application/json;   # iOS requires JSON; file has no extension
    add_header Cache-Control "public, max-age=3600";
}

location = /.well-known/assetlinks.json {
    alias /var/www/starlink/.well-known/assetlinks.json;
    default_type application/json;
    add_header Cache-Control "public, max-age=3600";
}
```

> **Important:** if this site is a single‑page app with a catch‑all like
> `try_files $uri $uri/ /index.html;`, the two `location =` blocks above must come
> **before** it, so the files are served directly and not rewritten to `index.html`.
> They must return **HTTP 200** with the raw JSON — **no redirects, no auth/login
> wall, no HTML fallback.**

Then test and reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 4. Verify it works

```bash
curl -i https://starlink.ardentnetworks.com.ph/.well-known/apple-app-site-association
curl -i https://starlink.ardentnetworks.com.ph/.well-known/assetlinks.json
```

Both responses must show:
- `HTTP/2 200` (or `HTTP/1.1 200 OK`) — **no** `301`/`302` redirect
- `content-type: application/json`
- the exact JSON body from section 1

Optional Android validator (Google's Digital Asset Links API):

```
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://starlink.ardentnetworks.com.ph&relation=delegate_permission/common.handle_all_urls
```

It should return a statement listing `com.ardentnetworks.starlink`.

---

## 5. Notes / expectations

- **HTTPS only**, with a valid (non‑self‑signed) certificate. The OS will not verify
  the association over plain HTTP.
- After the files are live, the **app must be reinstalled** on the test device — iOS
  and Android fetch and cache the association files at **install time**.
- iOS additionally caches the AASA via Apple's CDN; if it doesn't pick up immediately,
  reinstalling the app forces a fresh fetch.
- If a fingerprint or app id ever changes (new signing key, Play App Signing, etc.),
  update `assetlinks.json` accordingly and reload nginx.

---

## 6. Quick checklist

- [ ] `apple-app-site-association` placed (no extension) under `/.well-known/`
- [ ] `assetlinks.json` placed under `/.well-known/`
- [ ] Both nginx `location =` blocks added, above any SPA catch‑all
- [ ] `nginx -t` passes, nginx reloaded
- [ ] Both `curl -i` checks return `200` + `application/json` + correct body
- [ ] Test device: reinstall app, tap reset link → opens Starlink Reset Password screen
