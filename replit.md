# WhatsApp Clone — Replit Project

## Overview
A full-featured WhatsApp clone with Flutter mobile app (Android APK) + Node.js backend running on Replit.

## Architecture
| Layer | Technology |
|---|---|
| Mobile | Flutter 3.24.x (Android APK) |
| Auth | Firebase Auth (Google Sign-In) |
| Real-time | WebSocket (`/ws`) |
| Calls | WebRTC (flutter_webrtc) with STUN/TURN |
| Media | Cloudinary (image, video, file, voice upload) |
| Notifications | Firebase Cloud Messaging (FCM v1) |
| Backend | Node.js + Express (this Replit) |
| Database | Cloud Firestore (Firebase) |

## Features
- 🔐 Google Sign-In
- 💬 Real-time messaging (WebSocket)
- 📞 Voice calls (WebRTC, echo cancellation)
- 📹 Video calls (WebRTC)
- 🖥️ Screen sharing
- 📁 File/image/video sharing (Cloudinary)
- 🎤 Voice messages (record & playback)
- 🔔 Push notifications (FCM)
- 👥 Group chats
- ✅ Message status (sent/delivered/read)
- 😄 Emoji reactions (double-tap messages)
- ⌨️ Typing indicators
- 🟢 Online/offline status
- 🎵 Listen Together — synchronized music listening with friends
- 💬 Reply to messages
- 🗑️ Delete messages

## Running the Backend
The backend runs via the "Start Backend" workflow:
```
cd server && npm install && node index.js
```

## Required Secrets (Replit)
- `CLOUDINARY_CLOUD_NAME` — Cloudinary cloud name (set as env var)
- `CLOUDINARY_API_KEY` — Cloudinary API key (secret)
- `CLOUDINARY_API_SECRET` — Cloudinary API secret (secret)
- `FIREBASE_SERVICE_ACCOUNT` — Firebase service account JSON (secret)
- `FIREBASE_PROJECT_ID` — Firebase project ID (set as env var)
- `SESSION_SECRET` — Session secret

## Required GitHub Secrets (for APK build)
- `GOOGLE_SERVICES_JSON` — Contents of google-services.json ✅ (set)
- `BACKEND_URL` — Replit backend HTTPS URL ✅ (set)
- `BACKEND_WS_URL` — Replit backend WSS URL ✅ (set)

## APK Download
After each push to `main`, GitHub Actions builds the APK automatically.
Download from: https://github.com/noorapp10000-web/whatsapp-clone/releases

## Firebase Project
- Project ID: whatsapp-clone-976d4
- Package: com.whatsappclone.app
- FCM Sender ID: 655621157294

## Firestore Collections
- `users` — User profiles
- `conversations` — Chat conversations
- `conversations/{id}/messages` — Messages subcollection
- `calls` — Call logs
- `listen_sessions` — Listen Together sessions

## User Preferences
- Arabic language support in UI
- WhatsApp-style green color (#00A884)
- Echo cancellation on calls is critical
