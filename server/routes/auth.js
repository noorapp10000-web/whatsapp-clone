const router = require('express').Router();
const { getAuth, getFirestore, admin } = require('../firebase');

router.post('/login', async (req, res) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) return res.status(401).json({ error: 'Missing Authorization header' });
  const idToken = authHeader.slice(7);
  try {
    const decoded = await getAuth().verifyIdToken(idToken);
    const { uid, email, name, picture } = decoded;
    const { displayName, photoUrl, fcmToken } = req.body;
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    const userData = {
      uid, email: email || '',
      displayName: displayName || name || (email ? email.split('@')[0] : 'User'),
      photoUrl: photoUrl || picture || null,
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (fcmToken) userData.fcmToken = fcmToken;
    if (!userDoc.exists) {
      userData.status = 'Hey there! I am using WhatsApp Clone.';
      userData.isOnline = true;
      userData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      await userRef.set(userData);
    } else {
      await userRef.update({ ...userData, isOnline: true });
    }
    const updated = await userRef.get();
    res.json({ user: { id: uid, uid, ...updated.data() } });
  } catch (err) {
    res.status(401).json({ error: 'Authentication failed: ' + err.message });
  }
});

router.post('/logout', async (req, res) => {
  const authHeader = req.headers['authorization'];
  if (authHeader?.startsWith('Bearer ')) {
    try {
      const decoded = await getAuth().verifyIdToken(authHeader.slice(7));
      await getFirestore().collection('users').doc(decoded.uid).update({
        isOnline: false,
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
  res.json({ success: true });
});

module.exports = router;
