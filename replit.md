# WhatsApp Clone

A full-featured WhatsApp clone: Flutter Android app + Node.js backend.

## Stack
- **Mobile**: Flutter 3.x (Android)
- **Backend**: Node.js + Express — deployed on Railway
- **Auth**: Firebase Auth (Google Sign-In)
- **Real-time**: WebSocket (`/ws`)
- **Calls**: WebRTC (flutter_webrtc)
- **Media**: Cloudinary (file/image/video upload)
- **Notifications**: Firebase Cloud Messaging
- **Database**: Firebase Firestore

## Backend (Railway)

Production URL: `https://wa-clone-976d4-production.up.railway.app`
WebSocket URL: `wss://wa-clone-976d4-production.up.railway.app/ws`
Health check: `GET /health`

The Replit environment also runs the backend locally (port 3000) via the **Start Backend** workflow for development:
```
cd server && npm install && node index.js
```

## Flutter App — Backend URLs

Both URLs are hardcoded in:
- `lib/services/api_service.dart` — `_base` constant
- `lib/services/websocket_service.dart` — `_wsBase` constant

## Building the Flutter APK

Built automatically via GitHub Actions on every push to `main`.
Repo: https://github.com/noorapp10000-web/whatsapp-clone

The CI/CD workflow (`build.yml`) builds debug + release APKs and creates a GitHub Release.

### Debug Keystore

A consistent debug keystore is committed at `android/app/debug.keystore`:
- Alias: `androiddebugkey`
- Store password: `android`
- Key password: `android`
- **SHA-1: `18:B8:5A:77:A8:B3:1C:4C:A4:B4:81:55:38:20:DB:60:92:D5:DA:56`**

⚠️ This SHA-1 **must be registered** in Firebase Console (Project Settings → Android app → Add fingerprint) to fix Google Sign-In (`ApiException: 10`).

### GitHub Actions Secrets (CI/CD)

| Secret | Value |
|--------|-------|
| `GOOGLE_SERVICES_JSON` | Contents of `android/app/google-services.json` |
| `BACKEND_URL` | `https://wa-clone-976d4-production.up.railway.app` |
| `BACKEND_WS_URL` | `wss://wa-clone-976d4-production.up.railway.app` |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | Firebase service account JSON (for Railway backend) |

### Railway Environment Variables

| Variable | Value |
|----------|-------|
| `CLOUDINARY_CLOUD_NAME` | `mj0osj22` |
| `CLOUDINARY_API_KEY` | (set in Railway dashboard) |
| `CLOUDINARY_API_SECRET` | (set in Railway dashboard) |
| `FIREBASE_PROJECT_ID` | `whatsapp-clone-976d4` |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase Admin SDK JSON (required for FCM + Auth) |

## Firebase Project

- Project ID: `whatsapp-clone-976d4`
- Android App ID: `1:655621157294:android:fcea2fc9a29c16db9d583f`
- Package name: `com.whatsappclone.app`

## User Preferences

- Arabic is the user's preferred language for communication.
