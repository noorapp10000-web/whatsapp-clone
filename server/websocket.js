const { WebSocketServer } = require('ws');
const admin = require('./firebase');
const { pool } = require('./db');

// Map: userId (int) → Set of WebSocket connections
const userSockets = new Map();

/**
 * Broadcast a message to all connections of a given user.
 */
function broadcast(userId, data) {
  const sockets = userSockets.get(userId);
  if (!sockets) return;
  const payload = JSON.stringify(data);
  sockets.forEach(ws => {
    if (ws.readyState === 1 /* OPEN */) {
      ws.send(payload);
    }
  });
}

/**
 * Initialize the WebSocket server attached to the HTTP server.
 */
function initWebSocket(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', async (ws, req) => {
    // Extract token from query string: ws://host/ws?token=FIREBASE_ID_TOKEN
    const url = new URL(req.url, 'http://localhost');
    const token = url.searchParams.get('token');

    if (!token) {
      ws.close(4001, 'Missing token');
      return;
    }

    let userId;
    try {
      const decoded = await admin.auth().verifyIdToken(token);
      const { rows } = await pool.query(
        'SELECT id FROM users WHERE firebase_uid = $1',
        [decoded.uid]
      );
      if (!rows.length) { ws.close(4002, 'User not found'); return; }
      userId = rows[0].id;
    } catch (e) {
      ws.close(4003, 'Invalid token');
      return;
    }

    // Register connection
    if (!userSockets.has(userId)) userSockets.set(userId, new Set());
    userSockets.get(userId).add(ws);

    // Update online status
    await pool.query('UPDATE users SET last_seen = NOW() WHERE id = $1', [userId]);

    ws.send(JSON.stringify({ type: 'connected', userId }));

    ws.on('message', async (raw) => {
      try {
        const data = JSON.parse(raw);

        // Relay call signalling (offer, answer, ice-candidate)
        if (['call_offer', 'call_answer', 'call_ice', 'call_end', 'call_reject'].includes(data.type)) {
          const targetId = data.targetUserId;
          if (targetId) {
            broadcast(targetId, { ...data, fromUserId: userId });
          }
        }

        // Typing indicator
        if (data.type === 'typing') {
          const { conversationId } = data;
          const { rows } = await pool.query(
            'SELECT user_id FROM participants WHERE conversation_id = $1 AND user_id != $2',
            [conversationId, userId]
          );
          rows.forEach(r => broadcast(r.user_id, { type: 'typing', conversationId, userId }));
        }

        // Message status updates
        if (data.type === 'message_read') {
          const { messageId, conversationId } = data;
          await pool.query(
            "UPDATE messages SET status = 'read' WHERE id = $1 AND conversation_id = $2",
            [messageId, conversationId]
          );
          // Notify sender
          const { rows } = await pool.query('SELECT sender_id FROM messages WHERE id = $1', [messageId]);
          if (rows.length) broadcast(rows[0].sender_id, { type: 'message_status', messageId, status: 'read' });
        }
      } catch (e) {
        console.error('WS message error:', e.message);
      }
    });

    ws.on('close', async () => {
      const sockets = userSockets.get(userId);
      if (sockets) {
        sockets.delete(ws);
        if (sockets.size === 0) {
          userSockets.delete(userId);
          await pool.query('UPDATE users SET last_seen = NOW() WHERE id = $1', [userId]);
        }
      }
    });

    ws.on('error', (err) => console.error(`WS error for user ${userId}:`, err.message));
  });

  console.log('✅ WebSocket server initialized at /ws');
  return wss;
}

module.exports = { initWebSocket, broadcast };
