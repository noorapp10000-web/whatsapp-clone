const router = require('express').Router();
const { getFirestore, admin } = require('../firebase');
const { requireAuth } = require('../middleware/auth');

// ─── GET /contacts ─────────────────────────────────────────────────────────
// Returns all accepted contacts for the logged-in user
router.get('/', requireAuth, async (req, res) => {
  try {
    const db = getFirestore();
    const myUid = req.uid;
    const [sentSnap, recvSnap] = await Promise.all([
      db.collection('contactRequests')
        .where('fromUid', '==', myUid)
        .where('status', '==', 'accepted')
        .get(),
      db.collection('contactRequests')
        .where('toUid', '==', myUid)
        .where('status', '==', 'accepted')
        .get(),
    ]);
    const contactUids = new Set();
    sentSnap.forEach(doc => contactUids.add(doc.data().toUid));
    recvSnap.forEach(doc => contactUids.add(doc.data().fromUid));

    const contacts = [];
    for (const uid of contactUids) {
      const userDoc = await db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        contacts.push({ id: userDoc.id, uid: userDoc.id, ...userDoc.data() });
      }
    }
    res.json({ contacts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /contacts/requests ─────────────────────────────────────────────────
// Returns pending incoming contact requests
router.get('/requests', requireAuth, async (req, res) => {
  try {
    const db = getFirestore();
    let snap;
    try {
      snap = await db.collection('contactRequests')
        .where('toUid', '==', req.uid)
        .where('status', '==', 'pending')
        .orderBy('createdAt', 'desc')
        .get();
    } catch (_) {
      // Index might not exist yet — fall back to unordered
      snap = await db.collection('contactRequests')
        .where('toUid', '==', req.uid)
        .where('status', '==', 'pending')
        .get();
    }

    const requests = [];
    for (const doc of snap.docs) {
      const data = doc.data();
      const userDoc = await db.collection('users').doc(data.fromUid).get();
      if (userDoc.exists) {
        requests.push({
          id: doc.id,
          fromUser: { id: userDoc.id, uid: userDoc.id, ...userDoc.data() },
          createdAt: data.createdAt,
        });
      }
    }
    res.json({ requests });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /contacts/status/:uid ──────────────────────────────────────────────
// Check the contact-request relationship between me and another user
router.get('/status/:uid', requireAuth, async (req, res) => {
  try {
    const db = getFirestore();
    const myUid = req.uid;
    const targetUid = req.params.uid;

    const [sentSnap, recvSnap] = await Promise.all([
      db.collection('contactRequests')
        .where('fromUid', '==', myUid).where('toUid', '==', targetUid)
        .limit(1).get(),
      db.collection('contactRequests')
        .where('fromUid', '==', targetUid).where('toUid', '==', myUid)
        .limit(1).get(),
    ]);

    if (!sentSnap.empty) {
      const d = sentSnap.docs[0].data();
      return res.json({ status: d.status, direction: 'sent', requestId: sentSnap.docs[0].id });
    }
    if (!recvSnap.empty) {
      const d = recvSnap.docs[0].data();
      return res.json({ status: d.status, direction: 'received', requestId: recvSnap.docs[0].id });
    }
    res.json({ status: 'none' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /contacts/request/:uid ────────────────────────────────────────────
// Send a contact request
router.post('/request/:uid', requireAuth, async (req, res) => {
  try {
    const db = getFirestore();
    const myUid = req.uid;
    const targetUid = req.params.uid;
    if (myUid === targetUid) return res.status(400).json({ error: 'Cannot add yourself' });

    // Check if I already sent a request
    const sentSnap = await db.collection('contactRequests')
      .where('fromUid', '==', myUid).where('toUid', '==', targetUid).limit(1).get();
    if (!sentSnap.empty) {
      const existing = sentSnap.docs[0].data();
      if (existing.status === 'accepted') return res.json({ success: true, message: 'Already contacts', accepted: true });
      return res.json({ success: true, message: 'Request already sent', requestId: sentSnap.docs[0].id });
    }

    // Check if they already sent me a request
    const recvSnap = await db.collection('contactRequests')
      .where('fromUid', '==', targetUid).where('toUid', '==', myUid).limit(1).get();
    if (!recvSnap.empty) {
      const existing = recvSnap.docs[0].data();
      if (existing.status === 'accepted') return res.json({ success: true, message: 'Already contacts', accepted: true });
      // Auto-accept mutual request
      if (existing.status === 'pending') {
        await recvSnap.docs[0].ref.update({
          status: 'accepted',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return res.json({ success: true, message: 'Accepted mutual request', accepted: true });
      }
    }

    // Create new request
    const ref = await db.collection('contactRequests').add({
      fromUid: myUid,
      toUid: targetUid,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true, requestId: ref.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /contacts/accept/:uid ─────────────────────────────────────────────
// Accept an incoming contact request from uid
router.post('/accept/:uid', requireAuth, async (req, res) => {
  try {
    const db = getFirestore();
    const snap = await db.collection('contactRequests')
      .where('fromUid', '==', req.params.uid)
      .where('toUid', '==', req.uid)
      .where('status', '==', 'pending')
      .limit(1).get();
    if (snap.empty) return res.status(404).json({ error: 'Request not found' });
    await snap.docs[0].ref.update({
      status: 'accepted',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /contacts/reject/:uid ─────────────────────────────────────────────
// Reject an incoming contact request from uid
router.post('/reject/:uid', requireAuth, async (req, res) => {
  try {
    const db = getFirestore();
    const snap = await db.collection('contactRequests')
      .where('fromUid', '==', req.params.uid)
      .where('toUid', '==', req.uid)
      .where('status', '==', 'pending')
      .limit(1).get();
    if (snap.empty) return res.status(404).json({ error: 'Request not found' });
    await snap.docs[0].ref.update({
      status: 'rejected',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE /contacts/:uid ──────────────────────────────────────────────────
// Remove a contact (delete the request doc in both directions)
router.delete('/:uid', requireAuth, async (req, res) => {
  try {
    const db = getFirestore();
    const myUid = req.uid;
    const targetUid = req.params.uid;
    const batch = db.batch();
    const [s1, s2] = await Promise.all([
      db.collection('contactRequests').where('fromUid', '==', myUid).where('toUid', '==', targetUid).get(),
      db.collection('contactRequests').where('fromUid', '==', targetUid).where('toUid', '==', myUid).get(),
    ]);
    s1.forEach(doc => batch.delete(doc.ref));
    s2.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
