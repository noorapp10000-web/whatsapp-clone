# WhatsApp Clone

A full-featured WhatsApp clone: Flutter Android app + Node.js backend.

## Stack
- **Mobile**: Flutter 3.x (Android)
- **Backend**: Node.js + Express (this Replit project)
- **Auth**: Firebase Auth (Google Sign-In)
- **Real-time**: WebSocket (`/ws`)
- **Calls**: WebRTC (flutter_webrtc)
- **Media**: Cloudinary
- **Notifications**: Firebase Cloud Messaging

## Running the Backend

The backend runs via the **Start Backend** workflow:
```
cd server && npm install && node index.js
```
Listens on port 3000. Health check: `GET /health`

## Deployment

Configured as **VM** (always-on) — required for WebSocket connections.
Run command: `node server/index.js`

## Required Environment Secrets

| Secret | Purpose |
|--------|---------|
| `SESSION_SECRET` | Express session signing |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase Admin SDK JSON |
| `GITHUB_TOKEN` | GitHub API / CI access |

## Building the Flutter APK

Built automatically via GitHub Actions on every push to `main`.
Repo: https://github.com/noorapp10000-web/whatsapp-clone

### GitHub Secrets required for CI:
| Secret | Value |
|--------|-------|
| `GOOGLE_SERVICES_JSON` | Contents of `android/app/google-services.json` |
| `BACKEND_URL` | Production HTTPS URL of this Replit backend |
| `BACKEND_WS_URL` | Production WSS URL (`wss://...`) of this Replit backend |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | Firebase service account JSON (optional) |

## User Preferences

- Arabic is the user's preferred language for communication.
