const router = require('express').Router();
const { getFirestore, admin } = require('../firebase');
const { requireAuth } = require('../middleware/auth');

router.get('/me', requireAuth, (req, res) => {
  res.json({ user: { id: req.uid, uid: req.uid, ...req.user } });
});

router.put('/me', requireAuth, async (req, res) => {
  const { displayName, status, photoUrl, fcmToken } = req.body;
  const db = getFirestore();
  const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
  if (displayName) updates.displayName = displayName;
  if (status !== undefined) updates.status = status;
  if (photoUrl !== undefined) updates.photoUrl = photoUrl;
  if (fcmToken) updates.fcmToken = fcmToken;
  await db.collection('users').doc(req.uid).update(updates);
  const doc = await db.collection('users').doc(req.uid).get();
  res.json({ user: { id: req.uid, uid: req.uid, ...doc.data() } });
});

router.get('/search', requireAuth, async (req, res) => {
  const q = (req.query.q || '').toLowerCase().trim();
  if (q.length < 2) return res.json({ users: [] });
  const db = getFirestore();
  const snap = await db.collection('users').limit(200).get();
  const users = [];
  snap.forEach(doc => {
    if (doc.id === req.uid) return;
    const data = doc.data();
    if ((data.displayName || '').toLowerCase().includes(q) ||
        (data.email || '').toLowerCase().includes(q)) {
      users.push({ id: doc.id, uid: doc.id, ...data });
    }
  });
  res.json({ users: users.slice(0, 20) });
});

router.get('/:id', requireAuth, async (req, res) => {
  const doc = await getFirestore().collection('users').doc(req.params.id).get();
  if (!doc.exists) return res.status(404).json({ error: 'User not found' });
  res.json({ user: { id: doc.id, uid: doc.id, ...doc.data() } });
});

module.exports = router;
