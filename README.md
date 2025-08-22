# Spaced — Frontend

Flutter app for generating and studying “Study Packs”. Supports Android, iOS, desktop, and Web (MVP).

## Config and environments

API base URL is centralized in `lib/config.dart` and can be overridden via a `--dart-define` flag:

- Dev (Chrome):
	- `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`
- Dev (Android emulator):
	- `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000`
- Release (Web):
	- `flutter build web --release --dart-define=API_BASE_URL=https://api.example.com`
- Release (Android):
	- `flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com`

If not provided, the app defaults to `http://localhost:8000` on Web and `http://10.0.2.2:8000` on mobile/desktop.

See also `README_web.md` for deployment tips and CORS configuration (FastAPI).

## Previous Packs (storage)

- Stored in `shared_preferences`, which maps to `localStorage` on Web.
- Each pack stores: id, name, createdAt, flashcards, outline; the index is tracked under the key `sessions_index_v1`.
- Rename/Delete: Optimistic updates in UI; persisted immediately via `StudyStorage`.
- Migration: A safe, idempotent migration ensures older sessions get a default title (e.g., “Study Pack — YYYY-MM-DD hh:mm”). This runs at library load.

## Run locally

1. Enable web once (optional): `flutter config --enable-web`
2. Run in Chrome with dev API:
	 - `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`
3. Or on Android emulator with host API:
	 - `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000`

## Build

- Web: `flutter build web --release --dart-define=API_BASE_URL=https://api.example.com`
- Android: `flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com`

## Notes

- File picker is web-safe via conditional imports; files >10 MB are blocked with a friendly message.
- Upload shows progress with rotating status; after upload, the app polls until your preview data is ready.
