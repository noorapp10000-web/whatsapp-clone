const admin = require('firebase-admin');

let _initialized = false;

function initFirebase() {
  if (_initialized) return;
  const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(serviceAccount)),
      projectId: process.env.FIREBASE_PROJECT_ID || 'whatsapp-clone-976d4',
    });
  } else {
    // Falls back to Application Default Credentials (useful for local dev)
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'whatsapp-clone-976d4',
    });
    console.warn('⚠️  FIREBASE_SERVICE_ACCOUNT not set — using Application Default Credentials');
  }
  _initialized = true;
  console.log('✅ Firebase Admin initialized');
}

function getFirestore() { return admin.firestore(); }
function getAuth()      { return admin.auth(); }
function getMessaging() { return admin.messaging(); }

module.exports = { admin, initFirebase, getFirestore, getAuth, getMessaging };
