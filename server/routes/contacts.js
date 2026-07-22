const router = require('express').Router();
const { requireAuth } = require('../middleware/auth');

// Contacts are managed via Firestore directly from the client.
router.get('/', requireAuth, (_, res) => res.json({ contacts: [] }));

module.exports = router;
