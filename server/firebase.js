const admin = require('firebase-admin');

if (!admin.apps.length) {
  // If FIREBASE_SERVICE_ACCOUNT secret is provided, use it
  // Otherwise fall back to projectId-only mode (still verifies tokens via public keys)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log('✅ Firebase Admin initialized with service account');
    } catch (e) {
      console.error('❌ Invalid FIREBASE_SERVICE_ACCOUNT JSON:', e.message);
      admin.initializeApp({ projectId: 'whatsapp-clone-976d4' });
    }
  } else {
    // projectId-only: token verification still works via Firebase public keys
    admin.initializeApp({ projectId: 'whatsapp-clone-976d4' });
    console.log('⚠️  Firebase Admin initialized with projectId only (token verification only)');
  }
}

module.exports = admin;
