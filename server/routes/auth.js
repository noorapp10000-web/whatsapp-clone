const router = require('express').Router();
const admin = require('../firebase');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');

// POST /api/auth/login  — called right after Firebase sign-in
router.post('/login', async (req, res) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }
  const idToken = authHeader.slice(7);

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const { uid, email, name, picture } = decoded;

    const { displayName, photoUrl, fcmToken } = req.body;

    // Upsert user
    const { rows } = await pool.query(
      `INSERT INTO users (firebase_uid, display_name, email, photo_url, fcm_token)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (firebase_uid) DO UPDATE
         SET display_name = EXCLUDED.display_name,
             email        = EXCLUDED.email,
             photo_url    = COALESCE(EXCLUDED.photo_url, users.photo_url),
             fcm_token    = COALESCE(EXCLUDED.fcm_token, users.fcm_token),
             last_seen    = NOW()
       RETURNING *`,
      [uid, displayName || name, email, photoUrl || picture, fcmToken]
    );

    res.json({ user: rows[0] });
  } catch (err) {
    console.error('Login error:', err);
    res.status(401).json({ error: 'Authentication failed: ' + err.message });
  }
});

// POST /api/auth/logout
router.post('/logout', requireAuth, async (req, res) => {
  await pool.query('UPDATE users SET last_seen = NOW() WHERE id = $1', [req.user.id]);
  res.json({ success: true });
});

module.exports = router;
