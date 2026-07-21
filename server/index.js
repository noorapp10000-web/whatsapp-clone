require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');
const { initWebSocket } = require('./websocket');
const { pool, initDB } = require('./db');

const app = express();
const server = http.createServer(app);

// ─── Middleware ──────────────────────────────────────────────────────────────
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// ─── Routes ──────────────────────────────────────────────────────────────────
app.use('/api/auth',          require('./routes/auth'));
app.use('/api/users',         require('./routes/users'));
app.use('/api/contacts',      require('./routes/contacts'));
app.use('/api/conversations', require('./routes/conversations'));
app.use('/api/upload',        require('./routes/upload'));

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));
app.get('/',       (req, res) => res.json({ name: 'WhatsApp Clone API', version: '1.0.0' }));

// ─── WebSocket ────────────────────────────────────────────────────────────────
initWebSocket(server);

// ─── Start ────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;

initDB()
  .then(() => {
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`✅ WhatsApp Clone backend running on port ${PORT}`);
      console.log(`🔗 https://${process.env.REPLIT_DEV_DOMAIN}`);
    });
  })
  .catch(err => {
    console.error('❌ Failed to init DB:', err);
    process.exit(1);
  });
