const admin = require('../firebase');
const { pool } = require('../db');

/**
 * Verifies Firebase ID token and attaches the DB user to req.user
 */
async function requireAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  const idToken = authHeader.slice(7);

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const { rows } = await pool.query(
      'SELECT * FROM users WHERE firebase_uid = $1',
      [uid]
    );

    if (!rows.length) {
      return res.status(401).json({ error: 'User not registered. Call /api/auth/login first.' });
    }

    req.user = rows[0];
    next();
  } catch (err) {
    console.error('Auth error:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { requireAuth };
