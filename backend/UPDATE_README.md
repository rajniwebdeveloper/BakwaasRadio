Update endpoint behavior
=======================

Endpoint: `GET /api/update`

Query params supported:
- `platform` (optional): `iso`, `android`, `web`, `macos`, `windows` — returns only that platform object
- `v` (optional): client version string, e.g. `6.0.0`
- `ts` (optional): client timestamp (e.g. ISO string or millis)

Response: JSON object with keys for each platform. Example:

```
{
  "iso": {
    "version": "1.4.0",
    "build": "140",
    "releaseNotes": "Bug fixes and performance improvements",
    "url": "https://apps.apple.com/app/idYOUR_APP_ID",
    "force": false
  },
  "android": {
    "version": "1.4.2",
    "code": 142,
    "releaseNotes": "Small fixes, improved playback",
    "url": "https://play.google.com/store/apps/details?id=your.package.name",
    "force": false
  }
}
```

Client integration notes:
- On app open, perform a `GET /api/update` request.
- If the request fails (network error, timeout, or non-200), do NOT show the update popup — treat as "no update info".
- If the request succeeds, compare the app's current platform/version with the values returned:
  - If any entry indicates a newer `version` (or higher `code`/`build`) than the running app, show the update popup.
  - The server now also echoes `clientVersion` and `clientTs` when provided and includes an `upToDate` boolean per-platform (true when `clientVersion === serverVersion`).
    - The server now also echoes `clientVersion` and `clientTs` when provided and includes an `upToDate` boolean per-platform (true when `clientVersion === serverVersion`).
    - The server validates the `url` for each platform (performs a HEAD request for http/https links). For each platform the response now includes:
      - `urlValid`: boolean — true when the server could reach the URL (or for non-http(s) schemes, assumed true).
      - `available`: boolean — true when `urlValid` is true (indicates the platform update is usable). If `urlValid` is false, clients should ignore the update for that platform.
  - Popup should show `releaseNotes`, and two actions: `Update Now` and `Close`.
  - `Update Now` should open the `url` for that platform (App Store / Play Store / web link).
  - `Close` should exit the app (as requested). If you prefer to just dismiss the popup, change behaviour here.

Implementation hints for client:
- Use a short timeout (e.g., 3-5 seconds) for the update request on startup to avoid blocking UX.
- If `force: true` is set for the platform, you may prevent app usage until update.
- Compare semver using a library or simple numeric parsing. For Android consider comparing `code` integer if used.

Where to change values:
- The current server returns static metadata from `backend/routes/update.js` — replace with DB or environment-driven values if needed.
