# Spaced — Flutter Web MVP

A lightweight web build of Spaced you can embed in Carrd or host on Render/Netlify/Vercel.

## Enable Flutter Web

```bash
flutter config --enable-web
flutter doctor -v   # verify Chrome device
```

## Dev run (with API override)

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://your-api.example.com
```

## Release build

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com
```

Deploy the folder `build/web/`.

## Render static site (example)
- Root directory: `frontend`
- Build command: `flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com`
- Publish directory: `build/web`

## Netlify / Vercel
- Set the same build command and publish directory.
- Ensure your host serves `index.html` on 404 for SPA routing.

## Carrd embed
Add an embed element with an iframe:

```html
<iframe src="https://your-host.example.com" style="width:100%;height:800px;border:0;" title="Spaced"></iframe>
```

## CORS (FastAPI)
Enable CORS with methods/headers and large uploads:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # or your domain(s)
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=[
        "Accept",
        "Content-Type",
        "Authorization",
        "Origin",
        "X-Requested-With",
    ],
    max_age=600,
)
```

Ensure server supports OPTIONS preflight and large bodies (413/415 handling).

### Exact headers sent by client

- Upload/preview: `Accept: application/json`, plus `Authorization: Bearer <token>` if stored in shared preferences.
- ZIP download: `Accept: application/zip`, plus `Authorization` if present.

### FastAPI CORS config example

```python
from fastapi.middleware.cors import CORSMiddleware

origins = [
    "http://localhost:8080",  # dev hosts
    "http://localhost:8000",
    "https://your-host.example.com",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=[
        "Accept",
        "Authorization",
        "Content-Type",
        "Origin",
        "X-Requested-With",
    ],
    max_age=600,
)
```

Your server should reply to preflight (OPTIONS) with:

```
Access-Control-Allow-Origin: <origin>
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Accept, Authorization, Content-Type, Origin, X-Requested-With
Access-Control-Max-Age: 600
```

If using Render/Netlify/Vercel, ensure their CDN forwards OPTIONS and does not strip `Authorization`.

### Large uploads

- Increase body size limits; return `413` when exceeded.
- Return `202 Accepted` with `{"job_id": "..."}` when deferring processing; our client polls `/preview-study-pack?job_id=...`.
- Return `415` for unsupported media types.

## PWA (optional)
 - Manifest is at `web/manifest.json`.
 - Service worker at `web/flutter_service_worker.js` caches only the app shell and skips `.zip` downloads.
 - Registering is done in `web/index.html`.

To (re)generate icons, place your PNGs in `web/icons` as 192x192 and 512x512; optional maskables too.

To test PWA locally:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
# In Chrome DevTools > Application, verify Service Workers & Manifest.
```

## Troubleshooting
- CORS errors: inspect preflight (OPTIONS) and response headers.
- MIME types: ensure static host serves `application/wasm` for wasm assets and correct types for `js/css`.
- 429/5xx: API applies rate limits; client retries with backoff are recommended.
