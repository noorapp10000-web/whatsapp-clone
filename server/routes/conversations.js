const router = require('express').Router();
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { broadcast } = require('../websocket');

// GET /api/conversations
router.get('/', requireAuth, async (req, res) => {
  const { rows } = await pool.query(
    `SELECT c.*,
            json_agg(DISTINCT jsonb_build_object(
              'id', u.id, 'displayName', u.display_name,
              'email', u.email, 'photoUrl', u.photo_url,
              'status', u.status, 'lastSeen', u.last_seen
            )) AS participants,
            (SELECT row_to_json(m) FROM (
               SELECT m2.id, m2.type, m2.content, m2.file_url, m2.created_at,
                      m2.sender_id, u2.display_name AS sender_name
               FROM messages m2
               JOIN users u2 ON u2.id = m2.sender_id
               WHERE m2.conversation_id = c.id
               ORDER BY m2.created_at DESC LIMIT 1
             ) m) AS last_message,
            (SELECT COUNT(*) FROM messages m3
             WHERE m3.conversation_id = c.id AND m3.status != 'read'
               AND m3.sender_id != $1) AS unread_count
     FROM conversations c
     JOIN participants p ON p.conversation_id = c.id AND p.user_id = $1
     JOIN participants p2 ON p2.conversation_id = c.id
     JOIN users u ON u.id = p2.user_id
     GROUP BY c.id
     ORDER BY c.updated_at DESC`,
    [req.user.id]
  );
  res.json({ conversations: rows });
});

// POST /api/conversations  — create direct or group
router.post('/', requireAuth, async (req, res) => {
  const { type = 'direct', participantIds = [], name } = req.body;

  if (!participantIds.length) {
    return res.status(400).json({ error: 'participantIds required' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // For direct chats, check if conversation already exists
    if (type === 'direct' && participantIds.length === 1) {
      const otherId = participantIds[0];
      const { rows: existing } = await client.query(
        `SELECT c.id FROM conversations c
         JOIN participants p1 ON p1.conversation_id = c.id AND p1.user_id = $1
         JOIN participants p2 ON p2.conversation_id = c.id AND p2.user_id = $2
         WHERE c.type = 'direct'
         LIMIT 1`,
        [req.user.id, otherId]
      );
      if (existing.length) {
        await client.query('ROLLBACK');
        const { rows } = await pool.query('SELECT * FROM conversations WHERE id = $1', [existing[0].id]);
        return res.json({ conversation: rows[0] });
      }
    }

    const { rows: convRows } = await client.query(
      `INSERT INTO conversations (type, name, created_by) VALUES ($1, $2, $3) RETURNING *`,
      [type, name || null, req.user.id]
    );
    const conv = convRows[0];

    // Add all participants including creator
    const allIds = [...new Set([req.user.id, ...participantIds])];
    for (const uid of allIds) {
      await client.query(
        'INSERT INTO participants (conversation_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [conv.id, uid]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({ conversation: conv });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Create conversation error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// GET /api/conversations/:id/messages
router.get('/:id/messages', requireAuth, async (req, res) => {
  // Verify participant
  const { rows: check } = await pool.query(
    'SELECT 1 FROM participants WHERE conversation_id = $1 AND user_id = $2',
    [req.params.id, req.user.id]
  );
  if (!check.length) return res.status(403).json({ error: 'Not a participant' });

  const before = req.query.before;
  const { rows } = await pool.query(
    `SELECT m.*, u.display_name AS sender_name, u.photo_url AS sender_photo
     FROM messages m
     JOIN users u ON u.id = m.sender_id
     WHERE m.conversation_id = $1
       ${before ? 'AND m.created_at < $3' : ''}
     ORDER BY m.created_at DESC
     LIMIT 50`,
    before ? [req.params.id, req.user.id, before] : [req.params.id, req.user.id]
  );
  res.json({ messages: rows.reverse() });
});

// POST /api/conversations/:id/messages
router.post('/:id/messages', requireAuth, async (req, res) => {
  const { type = 'text', content, fileUrl, fileName, fileSize, mimeType, replyToId } = req.body;
  const convId = parseInt(req.params.id);

  // Verify participant
  const { rows: check } = await pool.query(
    'SELECT 1 FROM participants WHERE conversation_id = $1 AND user_id = $2',
    [convId, req.user.id]
  );
  if (!check.length) return res.status(403).json({ error: 'Not a participant' });

  const { rows } = await pool.query(
    `INSERT INTO messages (conversation_id, sender_id, type, content, file_url, file_name, file_size, mime_type, reply_to_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [convId, req.user.id, type, content, fileUrl, fileName, fileSize, mimeType, replyToId || null]
  );

  const msg = rows[0];

  // Update conversation timestamp
  await pool.query('UPDATE conversations SET updated_at = NOW() WHERE id = $1', [convId]);

  // Broadcast to all participants via WebSocket
  const { rows: parts } = await pool.query(
    'SELECT user_id FROM participants WHERE conversation_id = $1',
    [convId]
  );
  parts.forEach(p => {
    broadcast(p.user_id, {
      type: 'new_message',
      conversationId: convId,
      message: { ...msg, senderName: req.user.display_name, senderPhoto: req.user.photo_url }
    });
  });

  res.status(201).json({ message: msg });
});

// PUT /api/conversations/:id/messages/:msgId/status
router.put('/:id/messages/:msgId/status', requireAuth, async (req, res) => {
  const { status } = req.body;
  if (!['delivered', 'read'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status' });
  }
  await pool.query(
    'UPDATE messages SET status = $1 WHERE id = $2 AND conversation_id = $3',
    [status, req.params.msgId, req.params.id]
  );
  res.json({ success: true });
});

module.exports = router;
