require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');

const app = express();
const server = http.createServer(app);

app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Health check first — always available even if Firebase fails
app.get('/health', (_, res) => res.json({ status: 'ok', time: new Date().toISOString() }));
app.get('/', (_, res) => res.json({ name: 'WhatsApp Clone API', version: '2.0.0' }));

// Initialize Firebase safely
let firebaseReady = false;
try {
  const { initFirebase } = require('./firebase');
  initFirebase();
  firebaseReady = true;
  console.log('✅ Firebase Admin initialized');
} catch (err) {
  console.error('⚠️  Firebase init failed (routes requiring auth will return 503):', err.message);
}

// Firebase health middleware — routes will still register but return 503 if firebase failed
function requireFirebase(req, res, next) {
  if (!firebaseReady) {
    return res.status(503).json({ error: 'Firebase not initialized. Set FIREBASE_SERVICE_ACCOUNT.' });
  }
  next();
}

// Mount routes (conditionally guard firebase-dependent ones)
if (firebaseReady) {
  const { initWebSocket } = require('./websocket');
  initWebSocket(server);
  console.log('✅ WebSocket server initialized at /ws');

  app.use('/api/auth',          require('./routes/auth'));
  app.use('/api/users',         require('./routes/users'));
  app.use('/api/upload',        require('./routes/upload'));
  app.use('/api/fcm',           require('./routes/fcm'));
  app.use('/api/conversations', require('./routes/conversations'));
  app.use('/api/contacts',      require('./routes/contacts'));
} else {
  // Return 503 for all /api routes if Firebase failed
  app.use('/api', requireFirebase);
}

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

// Error handler
app.use((err, req, res, _next) => {
  console.error('Unhandled error:', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`✅ WhatsApp Clone backend running on port ${PORT}`);
  console.log(`   Firebase: ${firebaseReady ? 'ready' : 'NOT ready (check FIREBASE_SERVICE_ACCOUNT)'}`);
  console.log(`   Health: http://localhost:${PORT}/health`);
});

// Handle uncaught errors gracefully — don't crash the process
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err.message);
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled rejection:', reason);
});
