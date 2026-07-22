const { WebSocketServer } = require('ws');
const { getAuth } = require('./firebase');

const userSockets = new Map(); // uid → Set<WebSocket>

function broadcast(uid, data) {
  const sockets = userSockets.get(uid);
  if (!sockets) return;
  const payload = JSON.stringify(data);
  sockets.forEach(ws => { if (ws.readyState === 1) ws.send(payload); });
}

function initWebSocket(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', async (ws, req) => {
    const url = new URL(req.url, 'http://localhost');
    const token = url.searchParams.get('token');
    if (!token) { ws.close(4001, 'Missing token'); return; }

    let uid;
    try {
      const decoded = await getAuth().verifyIdToken(token);
      uid = decoded.uid;
    } catch {
      ws.close(4003, 'Invalid token');
      return;
    }

    if (!userSockets.has(uid)) userSockets.set(uid, new Set());
    userSockets.get(uid).add(ws);
    ws.send(JSON.stringify({ type: 'connected', uid }));

    ws.on('message', raw => {
      try {
        const data = JSON.parse(raw.toString());
        const RELAY = ['call_offer','call_answer','call_ice','call_end','call_reject','screen_share_offer'];
        if (RELAY.includes(data.type) && data.targetUid) {
          broadcast(data.targetUid, { ...data, fromUid: uid });
        }
      } catch (e) { console.error('WS msg error:', e.message); }
    });

    ws.on('close', () => {
      const sockets = userSockets.get(uid);
      if (sockets) { sockets.delete(ws); if (sockets.size === 0) userSockets.delete(uid); }
    });

    ws.on('error', err => console.error(`WS error for ${uid}:`, err.message));
  });

  console.log('✅ WebSocket server initialized at /ws');
  return wss;
}

module.exports = { initWebSocket, broadcast };
