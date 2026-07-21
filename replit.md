# WhatsApp Clone — Flutter + Node.js Backend

## Project Overview

Full-featured WhatsApp clone with:
- Flutter mobile app (Android APK) — built via GitHub Actions CI/CD
- Node.js + Express backend running on Replit
- PostgreSQL database (Replit built-in)
- Firebase Auth (Google Sign-In) + Firebase Cloud Messaging
- Cloudinary for file/media uploads
- WebSocket real-time messaging
- WebRTC voice/video calls + screen sharing

## Architecture

| Component | Technology |
|-----------|-----------|
| Mobile app | Flutter 3.24 |
| Backend | Node.js + Express (this Replit) |
| Database | PostgreSQL (Replit built-in) |
| Auth | Firebase Auth (Google Sign-In) |
| Realtime | WebSocket (`/ws` endpoint) |
| Calls | WebRTC (flutter_webrtc) |
| Storage | Cloudinary |
| Notifications | Firebase Cloud Messaging |
| CI/CD | GitHub Actions → APK artifacts |

## How to Run the Backend

```bash
cd server && npm install && node index.js
```

Or use the configured Replit workflow: **Start Backend**

## Backend API

Base URL: `https://<REPLIT_DEV_DOMAIN>/api`

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/auth/login | Register/login with Firebase token |
| GET | /api/users/me | Get current user |
| GET | /api/users/search?q= | Search users |
| GET | /api/contacts | List contacts |
| POST | /api/contacts | Add contact |
| GET | /api/conversations | List conversations |
| POST | /api/conversations | Create conversation |
| GET | /api/conversations/:id/messages | Get messages |
| POST | /api/conversations/:id/messages | Send message |
| POST | /api/upload | Upload file to Cloudinary |
| GET | /health | Health check |

WebSocket: `wss://<REPLIT_DEV_DOMAIN>/ws?token=FIREBASE_ID_TOKEN`

## GitHub Actions

The CI/CD pipeline builds the APK on every push to `main`.

### Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `GOOGLE_SERVICES_JSON` | Contents of `android/app/google-services.json` |
| `BACKEND_URL` | `https://<REPLIT_DEV_DOMAIN>` |
| `BACKEND_WS_URL` | `wss://<REPLIT_DEV_DOMAIN>` |

### Required Replit Secrets (Backend)

| Secret | Description |
|--------|-------------|
| `SESSION_SECRET` | ✅ Already set |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | Cloudinary API secret |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase service account JSON (optional, for push notifications) |

## Firebase Config

- Project: `whatsapp-clone-976d4`
- App ID: `1:655621157294:android:fcea2fc9a29c16db9d583f`
- Sender ID: `655621157294`
- Google Client ID: `655621157294-1jrptd26o877lf0k8kja898o9sd0300v.apps.googleusercontent.com`

## User Preferences

- Keep existing project structure (Flutter app root + server/ backend)
- Use Replit built-in PostgreSQL
- Backend runs on port 5000
