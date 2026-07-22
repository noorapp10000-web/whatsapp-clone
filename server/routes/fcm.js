const router = require('express').Router();
const { getFirestore, getMessaging } = require('../firebase');
const { requireAuth } = require('../middleware/auth');

router.post('/send', requireAuth, async (req, res) => {
  const { targetUid, title, body, data } = req.body;
  if (!targetUid || !title) return res.status(400).json({ error: 'targetUid and title required' });
  try {
    const db = getFirestore();
    const targetDoc = await db.collection('users').doc(targetUid).get();
    if (!targetDoc.exists) return res.status(404).json({ error: 'Target user not found' });
    const fcmToken = targetDoc.data().fcmToken;
    if (!fcmToken) return res.json({ success: false, reason: 'No FCM token for user' });
    const message = {
      token: fcmToken,
      notification: { title, body: body || '' },
      data: { ...(data || {}), senderId: req.uid },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'whatsapp_clone_channel' } },
    };
    try {
      const result = await getMessaging().send(message);
      res.json({ success: true, messageId: result });
    } catch (fcmErr) {
      if (fcmErr.code === 'messaging/registration-token-not-registered') {
        await db.collection('users').doc(targetUid).update({ fcmToken: null });
      }
      res.json({ success: false, error: fcmErr.message });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
