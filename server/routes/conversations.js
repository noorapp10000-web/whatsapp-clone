const router = require('express').Router();
const { requireAuth } = require('../middleware/auth');

// Conversations are managed directly via Firestore SDK from Flutter clients.
router.get('/',  requireAuth, (_, res) => res.json({ conversations: [] }));
router.post('/', requireAuth, (_, res) => res.status(501).json({ error: 'Use Firestore SDK directly' }));

module.exports = router;
