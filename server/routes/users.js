const router = require('express').Router();
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');

// GET /api/users/me
router.get('/me', requireAuth, async (req, res) => {
  res.json({ user: req.user });
});

// PUT /api/users/me  — update profile
router.put('/me', requireAuth, async (req, res) => {
  const { displayName, status, photoUrl, fcmToken } = req.body;
  const { rows } = await pool.query(
    `UPDATE users
     SET display_name = COALESCE($1, display_name),
         status       = COALESCE($2, status),
         photo_url    = COALESCE($3, photo_url),
         fcm_token    = COALESCE($4, fcm_token)
     WHERE id = $5 RETURNING *`,
    [displayName, status, photoUrl, fcmToken, req.user.id]
  );
  res.json({ user: rows[0] });
});

// GET /api/users/search?q=...
router.get('/search', requireAuth, async (req, res) => {
  const q = req.query.q || '';
  const { rows } = await pool.query(
    `SELECT id, display_name, email, photo_url, status, last_seen
     FROM users
     WHERE id != $1
       AND (display_name ILIKE $2 OR email ILIKE $2)
     LIMIT 20`,
    [req.user.id, `%${q}%`]
  );
  res.json({ users: rows });
});

// GET /api/users/:id
router.get('/:id', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT id, display_name, email, photo_url, status, last_seen FROM users WHERE id = $1',
    [req.params.id]
  );
  if (!rows.length) return res.status(404).json({ error: 'User not found' });
  res.json({ user: rows[0] });
});

module.exports = router;
