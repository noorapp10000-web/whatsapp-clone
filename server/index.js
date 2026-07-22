require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');
const { initFirebase } = require('./firebase');
const { initWebSocket } = require('./websocket');

initFirebase();

const app = express();
const server = http.createServer(app);

app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

app.use('/api/auth',          require('./routes/auth'));
app.use('/api/users',         require('./routes/users'));
app.use('/api/upload',        require('./routes/upload'));
app.use('/api/fcm',           require('./routes/fcm'));
app.use('/api/conversations', require('./routes/conversations'));
app.use('/api/contacts',      require('./routes/contacts'));

app.get('/health', (_, res) => res.json({ status: 'ok', time: new Date().toISOString() }));
app.get('/',       (_, res) => res.json({ name: 'WhatsApp Clone API', version: '2.0.0' }));

initWebSocket(server);

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ WhatsApp Clone backend running on port ${PORT}`);
});
