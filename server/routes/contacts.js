const router = require('express').Router();
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');

// GET /api/contacts
router.get('/', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    `SELECT u.id, u.display_name, u.email, u.photo_url, u.status, u.last_seen
     FROM contacts c
     JOIN users u ON u.id = c.contact_user_id
     WHERE c.user_id = $1
     ORDER BY u.display_name`,
    [req.user.id]
  );
  res.json({ contacts: rows });
});

// POST /api/contacts
router.post('/', requireAuth, async (req, res) => {
  const { contactUserId } = req.body;
  if (!contactUserId) return res.status(400).json({ error: 'contactUserId required' });
  if (contactUserId === req.user.id) return res.status(400).json({ error: 'Cannot add yourself' });

  try {
    await pool.query(
      'INSERT INTO contacts (user_id, contact_user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [req.user.id, contactUserId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/contacts/:contactUserId
router.delete('/:contactUserId', requireAuth, async (req, res) => {
  await pool.query(
    'DELETE FROM contacts WHERE user_id = $1 AND contact_user_id = $2',
    [req.user.id, req.params.contactUserId]
  );
  res.json({ success: true });
});

module.exports = router;
