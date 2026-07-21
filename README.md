# WhatsApp Clone — Flutter

A full-featured WhatsApp clone built with Flutter + Node.js backend.

## Features

- 💬 **Real-time messaging** — WebSocket-powered instant messages
- 📞 **Voice calls** — WebRTC peer-to-peer voice calls
- 📹 **Video calls** — Full video call support with camera switching
- 🖥️ **Screen sharing** — Share your screen during a call
- 📁 **File sharing** — Images, videos, audio, documents (Cloudinary)
- 🔔 **Push notifications** — Firebase Cloud Messaging
- 🔐 **Google Sign-In** — Firebase Authentication
- 👥 **Group chats** — Create and manage group conversations
- ✅ **Message status** — Sent/delivered indicators

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.x |
| Auth | Firebase Auth (Google Sign-In) |
| Real-time | WebSocket |
| Calls | WebRTC (flutter_webrtc) |
| Media | Cloudinary |
| Notifications | Firebase Cloud Messaging |
| Backend | Node.js + Express (Replit) |
| Database | PostgreSQL + Drizzle ORM |

## Setup

### 1. Backend URL
In `lib/services/api_service.dart`, replace `YOUR_REPLIT_URL` with your Replit backend URL.
In `lib/services/websocket_service.dart`, do the same.

### 2. Firebase
Place your `google-services.json` in `android/app/`.

### 3. Build
```bash
flutter pub get
flutter build apk --debug
```

## GitHub Actions

The CI/CD pipeline builds the APK automatically on every push to `main`.

### Required GitHub Secrets

| Secret | Value |
|---|---|
| `GOOGLE_SERVICES_JSON` | Contents of `google-services.json` |
| `BACKEND_URL` | Your Replit backend URL (https://...) |
| `BACKEND_WS_URL` | Your Replit WebSocket URL (wss://...) |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | Firebase service account JSON |
